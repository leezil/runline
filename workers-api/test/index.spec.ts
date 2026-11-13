import { env, SELF } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { hashToken } from "../src/features/auth/tokens";
import worker from "../src/index";

const api = "https://example.com/api/v1";

const { query } = vi.hoisted(() => ({ query: vi.fn() }));
vi.mock("pg", () => ({
	Client: class {
		connect = vi.fn().mockResolvedValue(undefined);
		end = vi.fn().mockResolvedValue(undefined);
		query = query;
	},
}));

function authPost(path: string, body: unknown) {
	return worker.request(`${api}/auth/${path}`, {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(body),
	}, { ...env, KAKAO_APP_ID: "42" });
}

afterEach(() => {
	vi.unstubAllGlobals();
	query.mockReset();
});

it("serves the public health check", async () => {
	const response = await SELF.fetch(`${api}/health`);
	expect(response.status).toBe(200);
	expect(await response.json()).toEqual({ ok: true, service: "runline-api" });
});

describe("Kakao login", () => {
	it("requires a Kakao token even if the request provides an account ID", async () => {
		const response = await authPost("kakao", { id: 123, email: "runner@example.com" });
		expect(response.status).toBe(400);
		expect(response.headers.get("Cache-Control")).toBe("no-store");
	});

	it("rejects an access token issued for a different Kakao app", async () => {
		const fetchKakao = vi.fn(async (url: string, options: RequestInit) => {
			// Validate the options using the Workers Request constructor before returning the fixture.
			const request = new Request(url, options);
			expect(request.redirect).toBe("manual");
			return Response.json({ app_id: 41, id: 123, expires_in: 300 });
		});
		vi.stubGlobal("fetch", fetchKakao);
		const response = await authPost("kakao", { accessToken: "kakao-token" });
		expect(response.status).toBe(401);
		expect(fetchKakao).toHaveBeenCalledTimes(1);
	});

	it("rejects distinct 64-bit member numbers even if they round to the same JS number", async () => {
		const fetchKakao = vi.fn()
			.mockResolvedValueOnce(new Response('{"app_id":42,"id":9007199254740992,"expires_in":300}'))
			.mockResolvedValueOnce(new Response('{"id":9007199254740993}'));
		vi.stubGlobal("fetch", fetchKakao);
		const response = await authPost("kakao", { accessToken: "kakao-token" });
		expect(response.status).toBe(401);
		expect(fetchKakao).toHaveBeenCalledTimes(2);
	});

	it("rotates token hashes and extends the session from the time of refresh", async () => {
		const fetchKakao = vi.fn()
			.mockResolvedValueOnce(new Response('{"app_id":42,"id":9007199254740993,"expires_in":300}'))
			.mockResolvedValueOnce(new Response('{"id":9007199254740993}'));
		vi.stubGlobal("fetch", fetchKakao);
		const session = {
			user_id: "runline-user",
			access_expires_at: new Date("2026-11-07T00:15:00Z"),
			refresh_expires_at: new Date("2027-02-05T00:00:00Z"),
		};
		const rotatedSession = {
			...session,
			access_expires_at: new Date("2027-02-04T00:15:00Z"),
			refresh_expires_at: new Date("2027-05-05T00:00:00Z"),
		};
		query.mockResolvedValueOnce({ rows: [session] })
			.mockResolvedValueOnce({ rows: [rotatedSession] })
			.mockResolvedValueOnce({ rows: [] })
			.mockResolvedValueOnce({ rows: [] });

		const loginResponse = await authPost("kakao", { accessToken: "kakao-token", id: 999 });
		expect(loginResponse.status).toBe(200);
		const login = await loginResponse.json<{ accessToken: string; refreshToken: string }>();
		expect(login).toMatchObject({
			user: { id: session.user_id },
			tokenType: "Bearer",
			refreshTokenExpiresAt: session.refresh_expires_at.toISOString(),
		});
		expect(query.mock.calls[0][1]).toEqual([
			"9007199254740993", await hashToken(login.accessToken), await hashToken(login.refreshToken), 900, 7776000,
		]);

		const refreshResponse = await authPost("refresh", { refreshToken: login.refreshToken });
		expect(refreshResponse.status).toBe(200);
		const refreshed = await refreshResponse.json<{ accessToken: string; refreshToken: string }>();
		expect(refreshed).toMatchObject({
			accessTokenExpiresAt: rotatedSession.access_expires_at.toISOString(),
			refreshTokenExpiresAt: rotatedSession.refresh_expires_at.toISOString(),
		});
		expect(refreshed.accessToken).not.toBe(login.accessToken);
		expect(refreshed.refreshToken).not.toBe(login.refreshToken);
		expect(query.mock.calls[1][0]).toContain("refresh_expires_at = now() + make_interval(secs => $5)");
		expect(query.mock.calls[1][0]).toContain("AND refresh_expires_at > now()");
		expect(query.mock.calls[1][1]).toEqual([
			await hashToken(login.refreshToken), await hashToken(refreshed.accessToken), await hashToken(refreshed.refreshToken),
			900, 7776000,
		]);

		expect((await authPost("refresh", { refreshToken: login.refreshToken })).status).toBe(401);
		expect((await authPost("logout", { refreshToken: refreshed.refreshToken })).status).toBe(204);
		expect(query.mock.calls[3][1]).toEqual([await hashToken(refreshed.refreshToken)]);
	});
});

it.each([
	["GET", "/auth/me"],
	["POST", "/feed/posts"],
	["POST", "/crews/demo/join"],
])("requires Runline authentication for %s %s", async (method, path) => {
	const response = await worker.request(`${api}${path}`, { method }, env);
	expect(response.status).toBe(401);
	expect(await response.json()).toMatchObject({ ok: false, error: { code: "AUTH_REQUIRED" } });
});
