import type { Client } from "pg";
import { HttpError } from "../../../http/http-error";

export async function replacePostAttachments(client: Client, postId: string, ownerId: string, mediaIds: string[]) {
	const eligible = await client.query(`
		SELECT id FROM runline_post_media
		WHERE id = ANY($1::uuid[]) AND owner_id = $2 AND uploaded_at IS NOT NULL
			AND discard_after IS NULL
			AND (post_id = $3 OR (post_id IS NULL AND attached_at IS NULL AND created_at > now() - interval '24 hours'))
		ORDER BY id FOR UPDATE`, [mediaIds, ownerId, postId]);
	if (eligible.rows.length !== mediaIds.length) {
		throw new HttpError(400, "INVALID_MEDIA", "One or more photos are unavailable");
	}

	await client.query(`
		UPDATE runline_post_media SET post_id = NULL, position = NULL, discard_after = now()
		WHERE post_id = $1 AND NOT (id = ANY($2::uuid[]))`, [postId, mediaIds]);
	await client.query(`
		UPDATE runline_post_media AS media
		SET post_id = $1, position = requested.position - 1, attached_at = COALESCE(media.attached_at, now())
		FROM unnest($2::uuid[]) WITH ORDINALITY AS requested(id, position)
		WHERE media.id = requested.id`, [postId, mediaIds]);
}
