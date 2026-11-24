import { Hono } from "hono";
import { withDatabase } from "../../database/client";
import { HttpError } from "../../http/http-error";
import { parseUuid } from "../../http/parse-uuid";
import type { AuthEnv } from "../auth/require-auth";
import { followUser } from "./follow-user";
import { unfollowUser } from "./unfollow-user";

const followRoutes = new Hono<AuthEnv>();

followRoutes.put("/users/:userId/follow", async (c) => {
	const followerId = c.get("userId");
	const followingId = parseUuid(c.req.param("userId"), "userId");
	if (followingId === followerId) {
		throw new HttpError(400, "INVALID_FOLLOW_TARGET", "You cannot follow yourself");
	}

	const targetExists = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) =>
		followUser(client, followerId, followingId),
	);
	if (!targetExists) throw new HttpError(404, "USER_NOT_FOUND", "User was not found");
	return c.json({ ok: true, isFollowing: true });
});

followRoutes.delete("/users/:userId/follow", async (c) => {
	const followingId = parseUuid(c.req.param("userId"), "userId");
	await withDatabase(c.env.HYPERDRIVE.connectionString, (client) =>
		unfollowUser(client, c.get("userId"), followingId),
	);
	return c.json({ ok: true, isFollowing: false });
});

export default followRoutes;
