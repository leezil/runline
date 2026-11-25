import { createMiddleware } from "hono/factory";
import { withDatabase } from "../../database/client";
import type { WorkerBindings } from "../../types";
import { AuthError } from "./errors";
import { findSessionUser } from "./session-repository";
import { accessTokenPattern, hashToken } from "./tokens";

export type AuthEnv = {
	Bindings: WorkerBindings;
	Variables: { userId: string };
};

export const requireAuth = createMiddleware<AuthEnv>(async (c, next) => {
	c.header("Cache-Control", "no-store");
	const authorization = c.req.header("Authorization");
	const token = /^Bearer ([^\s]+)$/i.exec(authorization ?? "")?.[1];
	if (!token || !accessTokenPattern.test(token)) {
		throw new AuthError(401, "AUTH_REQUIRED", "A valid Runline access token is required");
	}

	const accessHash = await hashToken(token);
	const userId = await withDatabase(c.env.HYPERDRIVE.connectionString, (client) => findSessionUser(client, accessHash));
	if (!userId) {
		throw new AuthError(401, "AUTH_REQUIRED", "A valid Runline access token is required");
	}
	c.set("userId", userId);
	await next();
});
