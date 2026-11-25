import { Hono } from "hono";
import type { AuthEnv } from "../../auth/require-auth";
import { createPost } from "./create-post";
import { deletePost } from "./delete-post";
import { readPost } from "./read-post";
import { updatePost } from "./update-post";

const postRoutes = new Hono<AuthEnv>();
postRoutes.post("/posts", ...createPost);
postRoutes.get("/posts/:postId", readPost);
postRoutes.patch("/posts/:postId", ...updatePost);
postRoutes.delete("/posts/:postId", deletePost);

export default postRoutes;
