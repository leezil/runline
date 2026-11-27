import { Hono } from 'hono';
import { bodyLimit } from 'hono/body-limit';
import { withDatabase } from '../database/client';
import { inTransaction } from '../database/transaction';
import type { AuthEnv } from './auth/require-auth';
import { HttpError } from '../http/http-error';

const runs = new Hono<AuthEnv>();
const invalid = () => new HttpError(400, 'INVALID_RUN', 'Invalid finished run');
const summary = `r.client_run_id AS id, r.started_at AS "startedAt", r.finished_at AS "updatedAt",
 r.distance_meters::float8 AS "distanceMeters", r.active_microseconds::float8 AS "activeMicroseconds",
 1 AS schema, 1 AS revision, 'finished' AS status`;
const validId = (v: unknown) => typeof v === 'string' && /^[a-f0-9]{32}$/.test(v);
const date = (v: unknown) => (typeof v === 'string' ? Date.parse(v) : NaN);
const bounded = (v: unknown, min: number, max: number) => typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max;

runs.use('*', async (c, next) => {
	c.header('Cache-Control', 'private, no-store');
	await next();
});
runs.put('/:id', bodyLimit({ maxSize: 8 * 1024 * 1024 }), async (c) => {
	const b = await c.req.json().catch(() => null);
	if (
		!b ||
		!validId(b.id) ||
		b.id !== c.req.param('id') ||
		b.schema !== 1 ||
		b.status !== 'finished' ||
		!(date(b.updatedAt) >= date(b.startedAt)) ||
		!Number.isSafeInteger(b.activeMicroseconds) ||
		b.activeMicroseconds < 0 ||
		!bounded(b.distanceMeters, 0, Number.MAX_SAFE_INTEGER) ||
		!Array.isArray(b.points) ||
		!b.points.every(
			(p: Record<string, unknown>) =>
				p &&
				bounded(p.latitude, -90, 90) &&
				bounded(p.longitude, -180, 180) &&
				bounded(p.accuracy, 0, Number.MAX_SAFE_INTEGER) &&
				Number.isFinite(date(p.timestamp)),
		) ||
		!Array.isArray(b.segmentStarts) ||
		!b.segmentStarts.every((n: number) => Number.isInteger(n) && n >= 0 && n <= b.points.length)
	)
		throw invalid();
	await withDatabase(c.env.HYPERDRIVE.connectionString, (client) =>
		inTransaction(client, async () => {
			const { rows } = await client.query(
				`INSERT INTO runline_runs
     (user_id,client_run_id,started_at,finished_at,active_microseconds,distance_meters)
     VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT(user_id,client_run_id) DO NOTHING RETURNING id`,
				[c.get('userId'), b.id, b.startedAt, b.updatedAt, b.activeMicroseconds, b.distanceMeters],
			);
			if (rows.length)
				await client.query(
					`INSERT INTO runline_run_details(run_id,points,segment_starts,goal,route,navigation)
     VALUES ($1,$2,$3,$4,$5,$6)`,
					[rows[0].id, ...[b.points, b.segmentStarts, b.goal, b.route, b.navigation].map((v) => JSON.stringify(v ?? null))],
				);
		}),
	);
	return c.body(null, 204);
});
runs.get('/', async (c) => {
	const after = c.req.query('after');
	if (after && !validId(after)) throw invalid();
	const { rows } = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) =>
		client.query(`SELECT ${summary} FROM runline_runs r WHERE user_id=$1 AND client_run_id > $2 ORDER BY client_run_id LIMIT 101`, [
			c.get('userId'),
			after ?? '',
		]),
	);
	return c.json({ records: rows.slice(0, 100), next: rows.length > 100 ? rows[99].id : null });
});
runs.get('/:id', async (c) => {
	const { rows } = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) =>
		client.query(
			`SELECT ${summary}, d.points,d.segment_starts AS "segmentStarts",d.goal,d.route,d.navigation
    FROM runline_runs r JOIN runline_run_details d ON d.run_id=r.id WHERE user_id=$1 AND client_run_id=$2`,
			[c.get('userId'), c.req.param('id')],
		),
	);
	if (!rows.length) throw new HttpError(404, 'RUN_NOT_FOUND', 'Run not found');
	return c.json(rows[0]);
});
export default runs;
