import type { Handler } from "hono";
import { withDatabase } from "../../../database/client";
import { HttpError } from "../../../http/http-error";
import { parseUuid } from "../../../http/parse-uuid";
import type { AuthEnv } from "../../auth/require-auth";
import { findPost } from "./post-query";
import { postResponse } from "./post-response";

export const readPost: Handler<AuthEnv, "/posts/:postId"> = async (c) => {
	const id = parseUuid(c.req.param("postId"), "postId");
	const row = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) => findPost(client, id));
	if (!row) throw new HttpError(404, "POST_NOT_FOUND", "Post not found");
	return c.json({ ok: true, post: await postResponse(c, row) });
};
