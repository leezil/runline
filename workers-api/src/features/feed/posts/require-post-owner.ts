import type { Client } from "pg";
import { HttpError } from "../../../http/http-error";

export async function requirePostOwner(client: Client, postId: string, userId: string) {
	const result = await client.query<{ author_id: string }>(
		"SELECT author_id FROM runline_posts WHERE id = $1 FOR UPDATE", [postId],
	);
	const post = result.rows[0];
	if (!post) {
		throw new HttpError(404, "POST_NOT_FOUND", "Post not found");
	}
	if (post.author_id !== userId) {
		throw new HttpError(403, "POST_FORBIDDEN", "Only the author can change this post");
	}
}
