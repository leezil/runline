import { createFactory } from "hono/factory";
import { withDatabase } from "../../../database/client";
import { inTransaction } from "../../../database/transaction";
import type { AuthEnv } from "../../auth/require-auth";
import { replacePostAttachments } from "./post-attachments";
import { postBodyLimit, readPostInput, requirePostContent } from "./post-input";
import { findPost } from "./post-query";
import { postResponse } from "./post-response";

export const createPost = createFactory<AuthEnv>().createHandlers(postBodyLimit, async (c) => {
	const { body = "", mediaIds = [] } = await readPostInput(c);
	requirePostContent(body, mediaIds);
	const userId = c.get("userId");
	const post = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) => inTransaction(client, async () => {
		const { rows: [created] } = await client.query<{ id: string }>(
			"INSERT INTO runline_posts (author_id, body) VALUES ($1, $2) RETURNING id", [userId, body],
		);
		if (mediaIds.length > 0) await replacePostAttachments(client, created.id, userId, mediaIds);
		const row = await findPost(client, created.id);
		if (!row) throw new Error("Created post is missing");
		return postResponse(c, row);
	}));
	return c.json({ ok: true, post }, 201);
});
