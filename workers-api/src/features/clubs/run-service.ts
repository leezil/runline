import type { Client } from "pg";
import { ClubError, invalid, missing } from "./errors";
import { addEvent, inClub, seek, updateRow } from "./repository";
import { pageResult, type Page, type runInput } from "./validation";

type Run = {
	id: string; club_id: string; creator_membership_id: string; title: string; description: string;
	location: string; starts_at: Date; ends_at: Date; registration_closes_at: Date; capacity: number;
	cancelled_at: Date | null; participant_count: number; is_participating: boolean; state: string;
};

const runSelect = `SELECT r.*, u.nickname AS creator_nickname, u.avatar_url AS creator_avatar_url,
	(SELECT count(*)::int FROM club_run_participants p WHERE p.run_id = r.id AND p.status = 'joined') AS participant_count,
	EXISTS (SELECT 1 FROM club_run_participants p WHERE p.run_id = r.id AND p.membership_id = $2 AND p.status = 'joined') AS is_participating,
	CASE WHEN r.cancelled_at IS NOT NULL THEN 'cancelled'
		WHEN r.ends_at <= clock_timestamp() THEN 'ended'
		WHEN r.starts_at <= clock_timestamp() THEN 'in_progress'
		WHEN r.registration_closes_at <= clock_timestamp() OR
			(SELECT count(*) FROM club_run_participants p WHERE p.run_id = r.id AND p.status = 'joined') >= r.capacity THEN 'closed'
		ELSE 'recruiting' END AS state
	FROM club_runs r JOIN club_memberships m ON m.id = r.creator_membership_id
	JOIN runline_users u ON u.id = m.user_id`;

async function findRun(client: Client, clubId: string, membershipId: string, runId: string): Promise<Run> {
	const { rows } = await client.query<Run>(`${runSelect} WHERE r.club_id = $1 AND r.id = $3`, [clubId, membershipId, runId]);
	return rows[0] ?? missing("Run");
}

function requireCreator(run: Run, memberId: string) {
	if (run.creator_membership_id !== memberId) throw new ClubError(403, "RUN_CREATOR_REQUIRED", "Only the run creator can manage this run");
}

async function validateSchedule(client: Client, values: ReturnType<typeof runInput>, future: boolean) {
	const { rows } = await client.query<{ valid: boolean }>(
		`SELECT $2::timestamptz > $1::timestamptz AND $3::timestamptz <= $1::timestamptz
		AND (NOT $4::boolean OR ($1::timestamptz > clock_timestamp() AND $3::timestamptz > clock_timestamp())) AS valid`,
		[values.starts_at, values.ends_at, values.registration_closes_at, future],
	);
	if (!rows[0].valid) invalid("End must follow start; registration must close in the future and no later than start");
}

export function listRuns(connection: string, userId: string, clubId: string, page: Page, filter: string) {
	return inClub(connection, userId, clubId, false, async ({ client, membership }) => {
		const params: unknown[] = [clubId, membership.id];
		const where = seek(page, params, "r.starts_at", "r.id");
		params.push(page.limit + 1);
		const filters: Record<string, string> = {
			all: "true",
			recruiting: `r.cancelled_at IS NULL AND r.starts_at > clock_timestamp() AND r.registration_closes_at > clock_timestamp()
				AND (SELECT count(*) FROM club_run_participants p WHERE p.run_id = r.id AND p.status = 'joined') < r.capacity`,
			upcoming: "r.cancelled_at IS NULL AND r.starts_at > clock_timestamp()",
			past: "r.cancelled_at IS NULL AND r.ends_at <= clock_timestamp()",
			in_progress: "r.cancelled_at IS NULL AND r.starts_at <= clock_timestamp() AND r.ends_at > clock_timestamp()",
			cancelled: "r.cancelled_at IS NOT NULL",
		};
		const condition = Object.hasOwn(filters, filter) ? filters[filter] : undefined;
		if (!condition) invalid("Unknown run filter");
		const { rows } = await client.query<Run>(`${runSelect} WHERE r.club_id = $1 AND (${condition}) ${where}
			ORDER BY r.starts_at DESC, r.id DESC LIMIT $${params.length}`, params);
		return pageResult(rows, page, `runs:${clubId}:${filter}`, "starts_at");
	});
}

export function getRun(connection: string, userId: string, clubId: string, runId: string) {
	return inClub(connection, userId, clubId, false, ({ client, membership }) => findRun(client, clubId, membership.id, runId));
}

export function createRun(connection: string, userId: string, clubId: string, fields: ReturnType<typeof runInput>) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		await validateSchedule(client, fields, true);
		const { rows } = await client.query<Run>(
			`INSERT INTO club_runs (club_id, creator_membership_id, title, description, location, starts_at, ends_at, registration_closes_at, capacity)
			VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *`,
			[clubId, membership.id, fields.title, fields.description, fields.location, fields.starts_at, fields.ends_at, fields.registration_closes_at, fields.capacity],
		);
		// The creator participates automatically and counts towards capacity.
		await client.query("INSERT INTO club_run_participants (run_id, membership_id, club_id) VALUES ($1, $2, $3)", [rows[0].id, membership.id, clubId]);
		await addEvent(client, clubId, "run_created", rows[0].id, rows[0].title);
		return findRun(client, clubId, membership.id, rows[0].id);
	});
}

export function editRun(connection: string, userId: string, clubId: string, runId: string, fields: ReturnType<typeof runInput>) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		const run = await findRun(client, clubId, membership.id, runId);
		requireCreator(run, membership.id);
		if (run.state !== "recruiting" && run.state !== "closed") {
			throw new ClubError(409, "RUN_NOT_EDITABLE", "Only upcoming, non-cancelled runs can be edited");
		}
		const merged = {
			...run, starts_at: new Date(run.starts_at).toISOString(), ends_at: new Date(run.ends_at).toISOString(),
			registration_closes_at: new Date(run.registration_closes_at).toISOString(), ...fields,
		};
		// Keep editing available after registration closes, without allowing registration to reopen in the past.
		await validateSchedule(client, merged, fields.registration_closes_at !== undefined || fields.starts_at !== undefined);
		if (merged.capacity < run.participant_count) throw new ClubError(409, "CAPACITY_BELOW_ATTENDANCE", "Capacity cannot be lower than current attendance");
		await updateRow(client, "club_runs", runId, fields);
		await addEvent(client, clubId, "run_updated", runId, merged.title);
		return findRun(client, clubId, membership.id, runId);
	});
}

export function cancelRun(connection: string, userId: string, clubId: string, runId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		const run = await findRun(client, clubId, membership.id, runId);
		requireCreator(run, membership.id);
		if (run.cancelled_at) return;
		if (run.state !== "recruiting" && run.state !== "closed") throw new ClubError(409, "RUN_NOT_CANCELLABLE", "Only upcoming runs can be cancelled");
		await client.query("UPDATE club_runs SET cancelled_at = clock_timestamp(), updated_at = clock_timestamp() WHERE id = $1", [runId]);
		await client.query("UPDATE club_run_participants SET status = 'cancelled', cancelled_at = clock_timestamp() WHERE run_id = $1 AND status = 'joined'", [runId]);
		await addEvent(client, clubId, "run_cancelled", runId, run.title);
	});
}

export function joinRun(connection: string, userId: string, clubId: string, runId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		const run = await findRun(client, clubId, membership.id, runId);
		if (run.is_participating) throw new ClubError(409, "ALREADY_PARTICIPATING", "You already participate in this run");
		if (run.state !== "recruiting") throw new ClubError(409, "RUN_NOT_RECRUITING", "This run is not accepting participants");
		await client.query(`INSERT INTO club_run_participants (run_id, membership_id, club_id) VALUES ($1, $2, $3)
			ON CONFLICT (run_id, membership_id) DO UPDATE SET status = 'joined', joined_at = clock_timestamp(), cancelled_at = NULL`, [runId, membership.id, clubId]);
		return findRun(client, clubId, membership.id, runId);
	});
}

export function leaveRun(connection: string, userId: string, clubId: string, runId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		const run = await findRun(client, clubId, membership.id, runId);
		if (run.state !== "recruiting" && run.state !== "closed") throw new ClubError(409, "RUN_NOT_EDITABLE", "Attendance can only change before the run starts");
		if (run.creator_membership_id === membership.id) throw new ClubError(409, "CREATOR_MUST_CANCEL_RUN", "The creator must cancel the run instead of leaving");
		await client.query("UPDATE club_run_participants SET status = 'cancelled', cancelled_at = clock_timestamp() WHERE run_id = $1 AND membership_id = $2 AND status = 'joined'", [runId, membership.id]);
	});
}

export function listParticipants(connection: string, userId: string, clubId: string, runId: string, page: Page) {
	return inClub(connection, userId, clubId, false, async ({ client, membership }) => {
		await findRun(client, clubId, membership.id, runId);
		const params: unknown[] = [clubId, runId];
		const where = seek(page, params, "p.joined_at", "m.id");
		params.push(page.limit + 1);
		const { rows } = await client.query<{ id: string }>(
			`SELECT m.id, m.user_id, u.nickname, u.avatar_url, p.joined_at
			FROM club_run_participants p JOIN club_memberships m ON m.id = p.membership_id
			JOIN runline_users u ON u.id = m.user_id
			WHERE p.club_id = $1 AND p.run_id = $2 AND p.status = 'joined' ${where}
			ORDER BY p.joined_at DESC, m.id DESC LIMIT $${params.length}`, params,
		);
		return pageResult(rows, page, `participants:${clubId}:${runId}`, "joined_at");
	});
}
