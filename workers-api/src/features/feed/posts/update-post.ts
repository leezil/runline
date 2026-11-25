import { createFactory } from "hono/factory";
import { withDatabase } from "../../../database/client";
import { inTransaction } from "../../../database/transaction";
import { HttpError } from "../../../http/http-error";
import { parseUuid } from "../../../http/parse-uuid";
import type { AuthEnv } from "../../auth/require-auth";
import { replacePostAttachments } from "./post-attachments";
import { postBodyLimit, readPostInput, requirePostContent } from "./post-input";
import { findPost } from "./post-query";
import { postResponse } from "./post-response";
import { requirePostOwner } from "./require-post-owner";

export const updatePost = createFactory<AuthEnv>().createHandlers(postBodyLimit, async (c) => {
	const id = parseUuid(c.req.param("postId") ?? "", "postId");
	const userId = c.get("userId");
	const { body, mediaIds } = await readPostInput(c);
	if (body === undefined && mediaIds === undefined) {
		throw new HttpError(400, "INVALID_REQUEST", "Supply body or mediaIds to update");
	}

	const post = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) => inTransaction(client, async () => {
		await requirePostOwner(client, id, userId);
		const current = await findPost(client, id);
		if (!current) throw new Error("Locked post is missing");
		const nextBody = body ?? current.body;
		requirePostContent(nextBody, mediaIds ?? current.media_ids);
		if (mediaIds !== undefined) await replacePostAttachments(client, id, userId, mediaIds);
		await client.query("UPDATE runline_posts SET body = $2, updated_at = statement_timestamp() WHERE id = $1", [id, nextBody]);
		const updated = await findPost(client, id);
		if (!updated) throw new Error("Updated post is missing");
		return postResponse(c, updated);
	}));
	return c.json({ ok: true, post });
});
