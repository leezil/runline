import type { Handler } from "hono";
import { withDatabase } from "../../../database/client";
import { inTransaction } from "../../../database/transaction";
import { parseUuid } from "../../../http/parse-uuid";
import type { AuthEnv } from "../../auth/require-auth";
import { requirePostOwner } from "./require-post-owner";

export const deletePost: Handler<AuthEnv, "/posts/:postId"> = async (c) => {
	const id = parseUuid(c.req.param("postId"), "postId");
	await withDatabase(c.env.HYPERDRIVE.connectionString, (client) => inTransaction(client, async () => {
		await requirePostOwner(client, id, c.get("userId"));
		await client.query("DELETE FROM runline_posts WHERE id = $1", [id]);
	}));
	return c.body(null, 204);
};
