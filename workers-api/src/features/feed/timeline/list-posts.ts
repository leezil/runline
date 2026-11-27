import type { Context } from "hono";
import { withDatabase } from "../../../database/client";
import { HttpError } from "../../../http/http-error";
import type { AuthEnv } from "../../auth/require-auth";
import { postSelect, type PostRow } from "../posts/post-query";
import { postResponse } from "../posts/post-response";
import { decodeFeedCursor, encodeFeedCursor } from "./feed-cursor";

export async function listPosts(c: Context<AuthEnv>, authorFilter: string) {
	const rawLimit = c.req.query("limit") ?? "20";
	const limit = Number(rawLimit);
	if (!/^\d{1,2}$/.test(rawLimit) || limit < 1 || limit > 50) {
		throw new HttpError(400, "INVALID_REQUEST", "limit must be between 1 and 50");
	}
	const cursor = decodeFeedCursor(c.req.query("cursor"));
	const { rows } = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) => client.query<PostRow>(`
		${postSelect}
		WHERE (${authorFilter})
			AND ($2::timestamptz IS NULL OR (p.created_at, p.id) < ($2::timestamptz, $3::uuid))
		ORDER BY p.created_at DESC, p.id DESC LIMIT $4`, [c.get("userId"), cursor.createdAt, cursor.id, limit + 1]));
	const last = rows[limit - 1];
	const nextCursor = rows.length > limit ? encodeFeedCursor(last.created_at, last.id) : null;
	const posts = await Promise.all(rows.slice(0, limit).map((row) => postResponse(c, row)));
	return c.json({ ok: true, posts, nextCursor });
}
