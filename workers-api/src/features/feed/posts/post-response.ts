import type { Context } from "hono";
import type { AuthEnv } from "../../auth/require-auth";
import { mediaUrl } from "../media/media-url";
import type { PostRow } from "./post-query";

export async function postResponse(c: Context<AuthEnv>, row: PostRow) {
	const media = await Promise.all(row.media_ids.map(async (id) => ({
		id,
		url: await mediaUrl(c.req.url, id, c.get("userId"), c.env.FEED_MEDIA_SIGNING_SECRET),
	})));
	return {
		id: row.id,
		body: row.body,
		createdAt: row.created_at,
		updatedAt: row.updated_at,
		author: { id: row.author_id, nickname: row.nickname, avatarUrl: row.avatar_url },
		media,
	};
}
