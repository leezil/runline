import type { Handler } from "hono";
import type { AuthEnv } from "../../auth/require-auth";
import { listPosts } from "./list-posts";

export const followingFeed: Handler<AuthEnv> = (c) => listPosts(c, `
	EXISTS (SELECT 1 FROM runline_user_follows WHERE follower_id = $1 AND following_id = p.author_id)`);
