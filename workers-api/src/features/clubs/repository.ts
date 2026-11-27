import type { Client, QueryResultRow } from "pg";
import { withDatabase, withTransaction } from "../../database/client";
import { ClubError, missing } from "./errors";
import type { Page } from "./validation";

export type Membership = {
	id: string; club_id: string; user_id: string; role: "owner" | "member"; joined_at: Date;
};
export type Club = {
	id: string; name: string; description: string; region: string; image_url: string | null;
	status: "active" | "closed"; created_at: Date; updated_at: Date; member_count: number;
};
export type Access = { client: Client; membership: Membership; club: Club };

export const clubSelect = `SELECT c.*,
	(SELECT count(*)::int FROM club_memberships m WHERE m.club_id = c.id AND m.status = 'active') AS member_count
	FROM clubs c`;

export async function transaction<T>(connection: string, run: (client: Client) => Promise<T>): Promise<T> {
	try {
		return await withDatabase(connection, (client) => withTransaction(client, () => run(client)));
	} catch (error) {
		const failure = error as { code?: string; constraint?: string };
		if (failure.code === "23505" && failure.constraint === "one_active_club_per_user") {
			throw new ClubError(409, "ALREADY_IN_CLUB", "You already belong to a club");
		}
		throw error;
	}
}

// Every operation locks the club before inspecting membership. Exclusive writes serialize
// joins, removals, ownership changes, run capacity checks and closure for that club.
export function inClub<T>(connection: string, userId: string, clubId: string, write: boolean, run: (access: Access) => Promise<T>) {
	return transaction(connection, async (client) => {
		const locked = await client.query(`SELECT id FROM clubs WHERE id = $1 AND status = 'active' FOR ${write ? "UPDATE" : "SHARE"}`, [clubId]);
		if (!locked.rows[0]) missing("Club");
		// Read aggregate counts in a new statement after acquiring the lock, so an
		// operation that waited for a concurrent join observes its committed membership.
		const { rows } = await client.query<Club>(`${clubSelect} WHERE c.id = $1`, [clubId]);
		const club = rows[0];
		const members = await client.query<Membership>(
			"SELECT * FROM club_memberships WHERE club_id = $1 AND user_id = $2 AND status = 'active'", [clubId, userId],
		);
		const membership = members.rows[0];
		if (!membership) throw new ClubError(403, "CLUB_MEMBERSHIP_REQUIRED", "Current club membership is required");
		return run({ client, club, membership });
	});
}

export function requireOwner(membership: Membership) {
	if (membership.role !== "owner") throw new ClubError(403, "CLUB_OWNER_REQUIRED", "Only the club owner can perform this action");
}

export async function requireUnjoined(client: Client, userId: string) {
	await client.query("SELECT id FROM runline_users WHERE id = $1 FOR UPDATE", [userId]);
	const { rows } = await client.query("SELECT id FROM club_memberships WHERE user_id = $1 AND status = 'active'", [userId]);
	if (rows.length) throw new ClubError(409, "ALREADY_IN_CLUB", "You already belong to a club");
}

export async function updateRow<T extends QueryResultRow>(
	client: Client,
	table: "clubs" | "club_notices" | "club_runs" | "runline_users",
	id: string,
	fields: Record<string, unknown>,
) {
	const entries = Object.entries(fields);
	if (!entries.length) throw new ClubError(400, "INVALID_REQUEST", "At least one field is required");
	// Column names originate exclusively in the typed input parsers, never from request keys.
	const assignments = entries.map(([key], i) => `${key} = $${i + 2}`);
	if (table !== "runline_users") assignments.push("updated_at = clock_timestamp()");
	const { rows } = await client.query<T>(`UPDATE ${table} SET ${assignments.join(", ")} WHERE id = $1 RETURNING *`, [id, ...entries.map(([, value]) => value)]);
	return rows[0];
}

export function seek(page: Page, params: unknown[], dateColumn: string, idColumn: string, pinColumn?: string): string {
	if (!page.cursor) return "";
	const offset = params.length;
	if (pinColumn) {
		params.push(page.cursor.pinned, page.cursor.date, page.cursor.id);
		return ` AND (${pinColumn}, ${dateColumn}, ${idColumn}) < ($${offset + 1}::boolean, $${offset + 2}::timestamptz, $${offset + 3}::uuid)`;
	}
	params.push(page.cursor.date, page.cursor.id);
	return ` AND (${dateColumn}, ${idColumn}) < ($${offset + 1}::timestamptz, $${offset + 2}::uuid)`;
}

export async function addEvent(
	client: Client, clubId: string,
	type: "notice_created" | "run_created" | "run_updated" | "run_cancelled",
	targetId: string, title: string,
) {
	await client.query(
		`INSERT INTO club_feed_events (club_id, type, notice_id, run_id, title)
		VALUES ($1, $2, $3, $4, $5)`,
		[clubId, type, type === "notice_created" ? targetId : null, type === "notice_created" ? null : targetId, title],
	);
}
