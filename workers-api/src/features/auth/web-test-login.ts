import type { Context } from "hono";
import { HttpError } from "../../http/http-error";
import { AuthError } from "./errors";
import { verifyKakaoUser } from "./kakao";
import { startSession } from "./session-service";
import type { AuthEnv } from "./require-auth";

// WEB_TEST_LOGIN: remove/disable this endpoint after browser testing.
export async function webTestLogin(c: Context<AuthEnv>) {
  if (c.env.ENABLE_WEB_TEST_LOGIN !== "true") {
    throw new HttpError(404, "NOT_FOUND", "Route not found");
  }
  const { KAKAO_REST_API_KEY: key, KAKAO_WEB_REDIRECT_URI: redirectUri, KAKAO_APP_ID: appId } = c.env;
  if (!key || !redirectUri || !appId || !/^[1-9][0-9]*$/.test(appId)) {
    throw new AuthError(503, "AUTH_UNAVAILABLE", "Web test login is not configured");
  }
  let redirect: URL;
  try { redirect = new URL(redirectUri); } catch {
    throw new AuthError(503, "AUTH_UNAVAILABLE", "Web test login is not configured");
  }
  if (redirect.pathname !== "/auth/kakao/callback" || redirect.search || redirect.hash || redirect.username ||
      (redirect.protocol !== "https:" && !(redirect.protocol === "http:" && ["localhost", "127.0.0.1"].includes(redirect.hostname)))) {
    throw new AuthError(503, "AUTH_UNAVAILABLE", "Invalid web test redirect configuration");
  }
  if (c.req.header("Origin") !== redirect.origin || c.env.RUNLINE_WEB_ORIGIN !== redirect.origin) {
    throw new HttpError(403, "WEB_ORIGIN_DENIED", "Web origin is not allowed");
  }
  const input = await c.req.json<Record<string, unknown> | null>().catch(() => null);
  if (!input || input.redirectUri !== redirectUri || typeof input.code !== "string" ||
      !/^[A-Za-z0-9._~+/=-]{1,2048}$/.test(input.code)) {
    throw new AuthError(400, "INVALID_REQUEST", "Invalid authorization code or redirect URI");
  }
  const body = new URLSearchParams({
    grant_type: "authorization_code", client_id: key,
    redirect_uri: redirectUri, code: input.code,
  });
  if (c.env.KAKAO_CLIENT_SECRET) body.set("client_secret", c.env.KAKAO_CLIENT_SECRET);
  let response: Response;
  let data: Record<string, unknown>;
  try {
    response = await fetch("https://kauth.kakao.com/oauth/token", {
      method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded;charset=utf-8" },
      body, redirect: "manual", signal: AbortSignal.timeout(5000),
    });
    data = await response.json() as Record<string, unknown>;
  } catch {
    throw new AuthError(503, "KAKAO_UNAVAILABLE", "Kakao login is temporarily unavailable");
  }
  if (!response.ok || typeof data?.access_token !== "string") {
    throw new AuthError(response.status >= 500 ? 503 : 401, "KAKAO_LOGIN_FAILED", "Kakao login failed");
  }
  // Reuse Android's app-ID/user verification and Runline session issuance.
  const userId = await verifyKakaoUser(data.access_token, appId);
  const session = await startSession(c.env.HYPERDRIVE.connectionString, userId);
  return c.json({ ok: true, ...session });
}
