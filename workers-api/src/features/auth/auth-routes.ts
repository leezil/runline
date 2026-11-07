import { Hono, type Context } from "hono";
import { bodyLimit } from "hono/body-limit";
import { AuthError } from "./errors";
import { verifyKakaoUser } from "./kakao";
import { requireAuth, type AuthEnv } from "./require-auth";
import { endSession, refreshSession, startSession } from "./session-service";
import { refreshTokenPattern } from "./tokens";

const authRoutes = new Hono<AuthEnv>();

async function readToken(c: Context<AuthEnv>, field: string, pattern: RegExp): Promise<string> {
	const body = await c.req.json<Record<string, unknown> | null>().catch(() => null);
	const token = body?.[field];
	if (typeof token !== "string" || !pattern.test(token)) {
		throw new AuthError(400, "INVALID_REQUEST", `${field} must be a valid token`);
	}
	return token;
}

authRoutes.use("*", async (c, next) => {
	c.header("Cache-Control", "no-store");
	await next();
});
authRoutes.use("*", bodyLimit({
	maxSize: 4096,
	onError: (c) => c.json({ ok: false, error: { code: "PAYLOAD_TOO_LARGE", message: "Request body is too large" } }, 413),
}));

authRoutes.post("/kakao", async (c) => {
	const token = await readToken(c, "accessToken", /^[A-Za-z0-9._~+/=-]{1,2048}$/);
	const appId = c.env.KAKAO_APP_ID;
	if (!appId || !/^[1-9][0-9]*$/.test(appId)) {
		throw new AuthError(503, "AUTH_UNAVAILABLE", "Kakao login is not configured");
	}
	const kakaoUserId = await verifyKakaoUser(token, appId);
	const session = await startSession(c.env.HYPERDRIVE.connectionString, kakaoUserId);
	return c.json({ ok: true, ...session });
});

authRoutes.post("/refresh", async (c) => {
	const token = await readToken(c, "refreshToken", refreshTokenPattern);
	const session = await refreshSession(c.env.HYPERDRIVE.connectionString, token);
	return c.json({ ok: true, ...session });
});

authRoutes.post("/logout", async (c) => {
	const token = await readToken(c, "refreshToken", refreshTokenPattern);
	await endSession(c.env.HYPERDRIVE.connectionString, token);
	return c.body(null, 204);
});

authRoutes.get("/me", requireAuth, (c) => c.json({ ok: true, user: { id: c.get("userId") } }));

export default authRoutes;
