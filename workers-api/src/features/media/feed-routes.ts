import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { requireAuth, type AuthEnv } from "../auth/require-auth";
import { ClubError, invalid, missing } from "../clubs/errors";
import { transaction, seek } from "../clubs/repository";
import { object, pageResult, readPage, text, uuid } from "../clubs/validation";
import { imageResponse } from "./image-service";

const feedRoutes = new Hono<AuthEnv>();
feedRoutes.use("*", requireAuth);
feedRoutes.use("*", bodyLimit({ maxSize: 100 * 1024 }));
feedRoutes.post("/posts", async (c) => {
	const body = object(await c.req.json().catch(() => invalid("A JSON body is required")));
	if (Object.keys(body).some((key) => !["title", "content"].includes(key))) invalid("Unknown field");
	const title = text(body.title, "title", 100);
	const content = text(body.content ?? "", "content", 10000, 0);
	const post = await transaction(c.env.HYPERDRIVE.connectionString, async (client) => {
		const { rows } = await client.query("INSERT INTO feed_posts (user_id, title, content) VALUES ($1,$2,$3) RETURNING *", [c.get("userId"), title, content]);
		return { ...rows[0], images: [] };
	});
	return c.json({ ok: true, post }, 201);
});
feedRoutes.get("/posts", async (c) => {
	const page = readPage(c.req.query(), "feed-posts");
	const result = await transaction(c.env.HYPERDRIVE.connectionString, async (client) => {
		const params: unknown[] = [];
		const where = seek(page, params, "p.created_at", "p.id");
		params.push(page.limit + 1);
		const { rows } = await client.query<{ id: string }>(`SELECT p.*, u.nickname, u.avatar_url
			FROM feed_posts p JOIN runline_users u ON u.id = p.user_id WHERE p.deleted_at IS NULL ${where}
			ORDER BY p.created_at DESC, p.id DESC LIMIT $${params.length}`, params);
		const images = await client.query<{ id: string; post_id: string; width: number; height: number; size: number; thumbnail_size: number }>(
			"SELECT * FROM media_images WHERE post_id = ANY($1::uuid[]) AND deleted_at IS NULL ORDER BY created_at, id", [rows.map((row) => row.id)]);
		return pageResult(rows.map((post) => ({ ...post, images: images.rows.filter((image) => image.post_id === post.id).map(imageResponse) })), page, "feed-posts");
	});
	return c.json({ ok: true, ...result });
});
feedRoutes.delete("/posts/:postId", async (c) => {
	const postId = uuid(c.req.param("postId"));
	await transaction(c.env.HYPERDRIVE.connectionString, async (client) => {
		const { rows } = await client.query("SELECT user_id FROM feed_posts WHERE id = $1 AND deleted_at IS NULL FOR UPDATE", [postId]);
		if (!rows[0]) missing("Post");
		if (rows[0].user_id !== c.get("userId")) throw new ClubError(403, "POST_AUTHOR_REQUIRED", "Only the author can delete this post");
		await client.query("UPDATE feed_posts SET deleted_at = clock_timestamp() WHERE id = $1", [postId]);
		await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE post_id = $1 AND deleted_at IS NULL", [postId]);
	});
	return c.body(null, 204);
});
export default feedRoutes;
