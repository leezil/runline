import type { Context } from "hono";
import { withDatabase } from "../../../database/client";
import { HttpError } from "../../../http/http-error";
import { parseUuid } from "../../../http/parse-uuid";
import type { AuthEnv } from "../../auth/require-auth";
import { verifyMediaUrl } from "./media-url";

export async function downloadMedia(c: Context<AuthEnv>): Promise<Response> {
	const id = parseUuid(c.req.param("mediaId") ?? "", "mediaId");
	if (!await verifyMediaUrl(c.req.url, id, c.get("userId"), c.env.FEED_MEDIA_SIGNING_SECRET)) {
		throw new HttpError(403, "INVALID_MEDIA_URL", "The image link is invalid or expired");
	}
	const media = await withDatabase(c.env.HYPERDRIVE.connectionString, async (db) => {
		const result = await db.query<{ object_key: string; content_type: string }>(
			`SELECT object_key, content_type FROM runline_post_media
			 WHERE id = $1 AND post_id IS NOT NULL AND uploaded_at IS NOT NULL AND discard_after IS NULL`,
			[id],
		);
		return result.rows[0];
	});
	if (!media) {
		throw new HttpError(404, "MEDIA_NOT_FOUND", "Image not found");
	}
	const object = await c.env.FEED_MEDIA.get(media.object_key);
	if (!object) {
		throw new HttpError(404, "MEDIA_NOT_FOUND", "Image not found");
	}
	return new Response(object.body, {
		headers: {
			"Cache-Control": "private, no-store",
			"Content-Length": String(object.size),
			"Content-Type": media.content_type,
			"X-Content-Type-Options": "nosniff",
		},
	});
}
