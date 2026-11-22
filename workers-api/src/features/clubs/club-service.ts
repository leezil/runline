import { ClubError, missing } from "./errors";
import { addEvent, clubSelect, inClub, requireOwner, requireUnjoined, seek, transaction, updateRow, type Club } from "./repository";
import { pageResult, type Page, type clubInput, type profileInput } from "./validation";
import type { Client } from "pg";

export async function myClub(connection: string, userId: string) {
	return transaction(connection, async (client) => {
		const { rows } = await client.query<Club & { membership_id: string; membership_role: string; membership_joined_at: Date }>(
			`SELECT c.*, mine.id AS membership_id, mine.role AS membership_role, mine.joined_at AS membership_joined_at,
			(SELECT count(*)::int FROM club_memberships m WHERE m.club_id = c.id AND m.status = 'active') AS member_count
			FROM clubs c JOIN club_memberships mine ON mine.club_id = c.id
			WHERE mine.user_id = $1 AND mine.status = 'active' AND c.status = 'active' FOR SHARE OF c`, [userId],
		);
		if (!rows[0]) return { club: null, membership: null };
		const { membership_id, membership_role, membership_joined_at, ...club } = rows[0];
		return { club, membership: { id: membership_id, role: membership_role, joined_at: membership_joined_at } };
	});
}

export async function profile(connection: string, userId: string, fields?: ReturnType<typeof profileInput>) {
	return transaction(connection, async (client) => {
		if (fields && "avatar_url" in fields) {
			await client.query("SELECT id FROM runline_users WHERE id = $1 FOR UPDATE", [userId]);
			await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE uploader_user_id = $1 AND purpose = 'avatar' AND deleted_at IS NULL", [userId]);
		}
		if (fields) await updateRow(client, "runline_users", userId, fields);
		const { rows } = await client.query("SELECT id, nickname, avatar_url FROM runline_users WHERE id = $1", [userId]);
		return rows[0];
	});
}

export function discover(connection: string, userId: string, page: Page, query: string, region: string, recommended: boolean) {
	return transaction(connection, async (client) => {
		await requireUnjoined(client, userId);
		const params: unknown[] = [query, region];
		const where = seek(page, params, "c.created_at", "c.id");
		params.push(page.limit + 1);
		const { rows } = await client.query<Club>(`${clubSelect}
			WHERE c.status = 'active' AND ($1 = '' OR strpos(lower(c.name), lower($1)) > 0)
			AND ($2 = '' OR c.region = $2) ${where}
			ORDER BY c.created_at DESC, c.id DESC LIMIT $${params.length}`, params);
		return pageResult(rows, page, discoveryScope(query, region, recommended));
	});
}

export function discoveryScope(query: string, region: string, recommended: boolean) {
	// Scope is ASCII because cursors are encoded using btoa; filters can contain Korean.
	return `clubs:${recommended ? "recommended" : "search"}:${encodeURIComponent(query)}:${encodeURIComponent(region)}`;
}

export function publicClub(connection: string, userId: string, clubId: string) {
	return transaction(connection, async (client) => {
		await requireUnjoined(client, userId);
		const { rows } = await client.query<Club>(`${clubSelect} WHERE c.id = $1 AND c.status = 'active'`, [clubId]);
		return rows[0] ?? missing("Club");
	});
}

export function createClub(connection: string, userId: string, fields: ReturnType<typeof clubInput>) {
	return transaction(connection, async (client) => {
		await requireUnjoined(client, userId);
		const { rows } = await client.query<Club>(
			"INSERT INTO clubs (name, description, region, image_url) VALUES ($1, $2, $3, $4) RETURNING *",
			[fields.name, fields.description, fields.region, fields.image_url],
		);
		const { rows: memberships } = await client.query(
			"INSERT INTO club_memberships (club_id, user_id, role) VALUES ($1, $2, 'owner') RETURNING id, role, joined_at", [rows[0].id, userId],
		);
		return { club: { ...rows[0], member_count: 1 }, membership: memberships[0] };
	});
}

export function joinClub(connection: string, userId: string, clubId: string) {
	return transaction(connection, async (client) => {
		const locked = await client.query("SELECT id FROM clubs WHERE id = $1 AND status = 'active' FOR UPDATE", [clubId]);
		if (!locked.rows[0]) missing("Club");
		await requireUnjoined(client, userId);
		const { rows: memberships } = await client.query(
			"INSERT INTO club_memberships (club_id, user_id, role) VALUES ($1, $2, 'member') RETURNING id, role, joined_at", [clubId, userId],
		);
		const { rows } = await client.query<Club>(`${clubSelect} WHERE c.id = $1`, [clubId]);
		return { club: rows[0], membership: memberships[0] };
	});
}

export function clubHome(connection: string, userId: string, clubId: string) {
	return inClub(connection, userId, clubId, false, async ({ club, membership }) => ({ club, membership }));
}

export function editClub(connection: string, userId: string, clubId: string, fields: ReturnType<typeof clubInput>) {
	return inClub(connection, userId, clubId, true, async ({ client, membership, club }) => {
		requireOwner(membership);
		if ("image_url" in fields) await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE club_id = $1 AND purpose = 'club_cover' AND deleted_at IS NULL", [clubId]);
		return { ...await updateRow<Club>(client, "clubs", clubId, fields), member_count: club.member_count };
	});
}

export function listMembers(connection: string, userId: string, clubId: string, page: Page, query: string) {
	return inClub(connection, userId, clubId, false, async ({ client }) => {
		const params: unknown[] = [clubId, query];
		const where = seek(page, params, "m.joined_at", "m.id");
		params.push(page.limit + 1);
		const { rows } = await client.query<{ id: string }>(
			`SELECT m.id, m.user_id, m.role, m.joined_at, u.nickname, u.avatar_url
			FROM club_memberships m JOIN runline_users u ON u.id = m.user_id
			WHERE m.club_id = $1 AND m.status = 'active' AND ($2 = '' OR strpos(lower(u.nickname), lower($2)) > 0)
			${where} ORDER BY m.joined_at DESC, m.id DESC LIMIT $${params.length}`, params,
		);
		return pageResult(rows, page, `members:${clubId}:${encodeURIComponent(query)}`, "joined_at");
	});
}

// Leaving/kicking cancels future runs hosted by the member, removes their pending
// attendance, and records cancellations in the feed in the same transaction.
async function endMembership(client: Client, clubId: string, memberId: string, status: "left" | "kicked") {
	const { rows } = await client.query<{ id: string; title: string }>(
		`UPDATE club_runs SET cancelled_at = clock_timestamp(), updated_at = clock_timestamp()
		WHERE club_id = $1 AND creator_membership_id = $2 AND starts_at > clock_timestamp() AND cancelled_at IS NULL
		RETURNING id, title`, [clubId, memberId],
	);
	for (const run of rows) await addEvent(client, clubId, "run_cancelled", run.id, run.title);
	await client.query(`UPDATE club_run_participants p SET status = 'cancelled', cancelled_at = clock_timestamp()
		FROM club_runs r WHERE r.id = p.run_id AND r.club_id = $1 AND p.status = 'joined'
		AND (r.cancelled_at IS NOT NULL OR (p.membership_id = $2 AND r.starts_at > clock_timestamp()))`, [clubId, memberId]);
	await client.query("UPDATE club_memberships SET status = $2, ended_at = clock_timestamp() WHERE id = $1", [memberId, status]);
}

export function leaveClub(connection: string, userId: string, clubId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		if (membership.role === "owner") throw new ClubError(409, "OWNER_MUST_TRANSFER_OR_CLOSE", "Transfer ownership or close the club before leaving");
		await endMembership(client, clubId, membership.id, "left");
	});
}

export function kickMember(connection: string, userId: string, clubId: string, memberId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		const { rows } = await client.query("SELECT id, role FROM club_memberships WHERE id = $1 AND club_id = $2 AND status = 'active'", [memberId, clubId]);
		if (!rows[0]) missing("Member");
		if (rows[0].role === "owner") throw new ClubError(409, "CANNOT_REMOVE_OWNER", "The club owner cannot be removed");
		await endMembership(client, clubId, memberId, "kicked");
	});
}

export function transferOwnership(connection: string, userId: string, clubId: string, memberId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		const { rows } = await client.query("SELECT id FROM club_memberships WHERE id = $1 AND club_id = $2 AND status = 'active' AND role = 'member'", [memberId, clubId]);
		if (!rows[0]) missing("Eligible member");
		await client.query("UPDATE club_memberships SET role = 'member' WHERE id = $1", [membership.id]);
		await client.query("UPDATE club_memberships SET role = 'owner' WHERE id = $1", [memberId]);
	});
}

export function closeClub(connection: string, userId: string, clubId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		await client.query("UPDATE clubs SET status = 'closed', updated_at = clock_timestamp() WHERE id = $1", [clubId]);
		await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE club_id = $1 AND deleted_at IS NULL", [clubId]);
		await client.query("UPDATE club_runs SET cancelled_at = clock_timestamp(), updated_at = clock_timestamp() WHERE club_id = $1 AND ends_at > clock_timestamp() AND cancelled_at IS NULL", [clubId]);
		await client.query(`UPDATE club_run_participants p SET status = 'cancelled', cancelled_at = clock_timestamp()
			FROM club_runs r WHERE p.run_id = r.id AND r.club_id = $1 AND r.cancelled_at IS NOT NULL AND p.status = 'joined'`, [clubId]);
		await client.query("UPDATE club_memberships SET status = 'closed', ended_at = clock_timestamp() WHERE club_id = $1 AND status = 'active'", [clubId]);
	});
}
