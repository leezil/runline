import type { Handler } from "hono";
import type { AuthEnv } from "../../auth/require-auth";
import { listPosts } from "./list-posts";

export const myPosts: Handler<AuthEnv> = (c) => listPosts(c, "p.author_id = $1");
