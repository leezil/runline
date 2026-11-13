import { Hono } from "hono";
import { withDatabase } from "../../database/client";
import { HttpError } from "../../http/http-error";
import { parseUuid } from "../../http/parse-uuid";
import type { AuthEnv } from "../auth/require-auth";
import { findProfile } from "./profile-repository";

const profileRoutes = new Hono<AuthEnv>();

async function readProfile(connectionString: string, userId: string, viewerId: string) {
	const profile = await withDatabase(connectionString, (client) => findProfile(client, userId, viewerId));
	if (!profile) throw new HttpError(404, "USER_NOT_FOUND", "User was not found");
	return profile;
}

profileRoutes.get("/me", async (c) => {
	const viewerId = c.get("userId");
	const profile = await readProfile(c.env.HYPERDRIVE.connectionString, viewerId, viewerId);
	return c.json({ ok: true, profile });
});

profileRoutes.get("/users/:userId", async (c) => {
	const userId = parseUuid(c.req.param("userId"), "userId");
	const profile = await readProfile(c.env.HYPERDRIVE.connectionString, userId, c.get("userId"));
	return c.json({ ok: true, profile });
});

export default profileRoutes;
