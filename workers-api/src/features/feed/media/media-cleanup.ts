import { withDatabase } from "../../../database/client";
import { inTransaction } from "../../../database/transaction";
import type { WorkerBindings } from "../../../types";

const cleanupBatchSize = 100;

export async function cleanUpMedia(env: WorkerBindings): Promise<void> {
	await withDatabase(env.HYPERDRIVE.connectionString, (db) =>
		inTransaction(db, async () => {
			const { rows } = await db.query<{ id: string; object_key: string }>(
				`SELECT id, object_key FROM runline_post_media
				 WHERE post_id IS NULL AND (discard_after <= now() OR attached_at IS NOT NULL OR created_at <= now() - interval '24 hours')
				 ORDER BY created_at, id
				 LIMIT $1 FOR UPDATE SKIP LOCKED`,
				[cleanupBatchSize],
			);
			if (rows.length === 0) return;
			await env.FEED_MEDIA.delete(rows.map(({ object_key }) => object_key));
			await db.query("DELETE FROM runline_post_media WHERE id = ANY($1::uuid[])", [rows.map(({ id }) => id)]);
		}),
	);
}
