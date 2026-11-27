import { inClub, seek } from "./repository";
import { pageResult, type Page } from "./validation";

export function listFeed(connection: string, userId: string, clubId: string, page: Page) {
	return inClub(connection, userId, clubId, false, async ({ client }) => {
		const params: unknown[] = [clubId];
		const where = seek(page, params, "e.created_at", "e.id");
		params.push(page.limit + 1);
		const { rows } = await client.query<{ id: string }>(
			`SELECT e.id, e.type, e.title, e.created_at,
			CASE WHEN e.notice_id IS NOT NULL THEN 'notice' ELSE 'run' END AS target_type,
			COALESCE(e.notice_id, e.run_id) AS target_id,
			n.title AS current_notice_title, n.pinned AS notice_pinned,
			r.title AS current_run_title, r.starts_at AS run_starts_at, r.cancelled_at AS run_cancelled_at,
			(SELECT '/api/v1/media/images/' || i.id::text || '?variant=thumbnail'
			 FROM media_images i WHERE i.notice_id = n.id AND i.deleted_at IS NULL ORDER BY i.created_at, i.id LIMIT 1) AS thumbnail_url
			FROM club_feed_events e
			LEFT JOIN club_notices n ON n.id = e.notice_id AND n.club_id = e.club_id
			LEFT JOIN club_runs r ON r.id = e.run_id AND r.club_id = e.club_id
			WHERE e.club_id = $1 AND ((e.notice_id IS NOT NULL AND n.deleted_at IS NULL AND n.id IS NOT NULL)
				OR (e.run_id IS NOT NULL AND r.id IS NOT NULL)) ${where}
			ORDER BY e.created_at DESC, e.id DESC LIMIT $${params.length}`, params,
		);
		return pageResult(rows, page, `feed:${clubId}`);
	});
}
