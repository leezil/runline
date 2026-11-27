import { env, SELF } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import { hashToken } from "../src/features/auth/tokens";
import { app as worker } from "../src/index";

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
	["GET", "/me/club"],
	["PATCH", "/me/profile"],
	["GET", "/clubs"],
	["GET", "/clubs/recommended"],
	["POST", "/clubs"],
	["POST", "/clubs/demo/join"],
	["GET", "/clubs/demo/home"],
	["GET", "/clubs/demo/feed"],
	["GET", "/clubs/demo/members"],
	["POST", "/clubs/demo/notices"],
	["POST", "/clubs/demo/notices/demo/attachments"],
	["GET", "/clubs/demo/runs"],
	["POST", "/clubs/demo/runs/demo/participants"],
	["GET", "/clubs/demo/chat/state"],
	["POST", "/me/avatar"],
	["GET", "/me"],
	["GET", "/me/posts"],
	["GET", "/users/demo"],
	["GET", "/users/demo/followers"],
	["GET", "/users/demo/following"],
	["PUT", "/users/demo/follow"],
	["DELETE", "/users/demo/follow"],
	["GET", "/feed/recommended"],
	["GET", "/feed/following"],
	["POST", "/feed/posts"],
	["GET", "/feed/posts/demo"],
	["PATCH", "/feed/posts/demo"],
	["DELETE", "/feed/posts/demo"],
	["POST", "/feed/media"],
	["GET", "/feed/media/demo"],
	["POST", "/crews/demo/join"],
])("requires Runline authentication for %s %s", async (method, path) => {
	const response = await worker.request(`${api}${path}`, { method }, env);
	expect(response.status).toBe(401);
	expect(await response.json()).toMatchObject({ ok: false, error: { code: "AUTH_REQUIRED" } });
});

describe("feed posts", () => {
	const author = "aaaaaaaa-1111-1111-1111-111111111111";
	const other = "bbbbbbbb-1111-1111-1111-111111111111";
	const postId = "cccccccc-1111-1111-1111-111111111111";
	const photoId = "dddddddd-1111-1111-1111-111111111111";
	const post = {
		id: postId,
		body: "오늘의 러닝",
		created_at: "2026-11-12T08:12:34.123456Z",
		updated_at: "2026-11-12T08:12:34.123456Z",
		author_id: author,
		nickname: "러너 aaaaaaaa",
		avatar_url: null,
		media_ids: [],
	};

	function feedRequest(path: string, method = "GET", body?: unknown) {
		return worker.request(`${api}${path}`, {
			method,
			headers: { Authorization: `Bearer rla_${"a".repeat(64)}`, "Content-Type": "application/json" },
			body: JSON.stringify(body),
		}, env);
	}

	it("creates posts for the authenticated author", async () => {
		query.mockResolvedValueOnce({ rows: [{ user_id: author }] })
			.mockResolvedValueOnce({ rows: [] })
			.mockResolvedValueOnce({ rows: [{ id: postId }] })
			.mockResolvedValueOnce({ rows: [post] })
			.mockResolvedValueOnce({ rows: [] });
		const response = await feedRequest("/feed/posts", "POST", { body: " 오늘의 러닝 ", authorId: other });
		expect(response.status).toBe(201);
		expect(await response.json()).toMatchObject({ post: { id: postId, body: post.body, author: { id: author } } });
		expect(query.mock.calls[2][1]).toEqual([author, post.body]);
	});

	it("rolls back a post when a photo cannot be attached", async () => {
		query.mockResolvedValueOnce({ rows: [{ user_id: author }] })
			.mockResolvedValueOnce({ rows: [] })
			.mockResolvedValueOnce({ rows: [{ id: postId }] })
			.mockResolvedValueOnce({ rows: [] })
			.mockResolvedValueOnce({ rows: [] });
		const response = await feedRequest("/feed/posts", "POST", { body: post.body, mediaIds: [photoId] });
		expect(response.status).toBe(400);
		expect(await response.json()).toMatchObject({ error: { code: "INVALID_MEDIA" } });
		expect(query.mock.calls[3][1]).toEqual([[photoId], author, postId]);
		expect(query.mock.lastCall?.[0]).toBe("ROLLBACK");
	});

	it("rejects deletion by a different author", async () => {
		query.mockResolvedValueOnce({ rows: [{ user_id: other }] })
			.mockResolvedValueOnce({ rows: [] })
			.mockResolvedValueOnce({ rows: [{ author_id: author }] })
			.mockResolvedValueOnce({ rows: [] });
		const response = await feedRequest(`/feed/posts/${postId}`, "DELETE");
		expect(response.status).toBe(403);
		expect(query.mock.lastCall?.[0]).toBe("ROLLBACK");
	});

	it("uses both the timestamp and ID for pagination", async () => {
		query.mockResolvedValueOnce({ rows: [{ user_id: author }] })
			.mockResolvedValueOnce({ rows: [post, { ...post, id: photoId }] })
			.mockResolvedValueOnce({ rows: [{ user_id: author }] })
			.mockResolvedValueOnce({ rows: [{ ...post, id: photoId }] });
		const first = await feedRequest("/me/posts?limit=1");
		expect(first.status).toBe(200);
		const { nextCursor } = await first.json<{ nextCursor: string }>();
		const second = await feedRequest(`/me/posts?limit=1&cursor=${nextCursor}`);
		expect(second.status).toBe(200);
		expect(await second.json()).toMatchObject({ posts: [{ id: photoId }], nextCursor: null });
		expect(query.mock.lastCall?.[1]).toEqual([author, post.created_at, postId, 2]);
	});
});


describe("web test login", () => {
  const origin = "http://localhost:5000";
  const redirectUri = `${origin}/auth/kakao/callback`;
  const settings = { ...env, ENABLE_WEB_TEST_LOGIN: "true", KAKAO_REST_API_KEY: "test-key",
    KAKAO_APP_ID: "42", KAKAO_WEB_REDIRECT_URI: redirectUri, RUNLINE_WEB_ORIGIN: origin };
  const login = (bindings = settings, body: unknown = { code: "code", redirectUri }, requestOrigin = origin) =>
    worker.request(`${api}/auth/kakao/web`, { method: "POST", headers: {
      "Content-Type": "application/json", Origin: requestOrigin,
    }, body: JSON.stringify(body) }, bindings);

  it("is disabled by default and never calls Kakao or the database", async () => {
    const fetchKakao = vi.fn(); vi.stubGlobal("fetch", fetchKakao);
    expect((await login({ ...settings, ENABLE_WEB_TEST_LOGIN: "false" })).status).toBe(404);
    expect(fetchKakao).not.toHaveBeenCalled(); expect(query).not.toHaveBeenCalled();
  });
  it("rejects an unexpected origin or redirect URI", async () => {
    expect((await login(settings, undefined, "https://other.example")).status).toBe(403);
    expect((await login(settings, { code: "code", redirectUri: "https://other.example" })).status).toBe(400);
    expect(query).not.toHaveBeenCalled();
  });
  it("exchanges the code server-side and issues an existing Runline session", async () => {
    const fetchKakao = vi.fn()
      .mockResolvedValueOnce(Response.json({ access_token: "kakao-token" }))
      .mockResolvedValueOnce(Response.json({ app_id: 42, id: 123, expires_in: 300 }))
      .mockResolvedValueOnce(Response.json({ id: 123 }));
    vi.stubGlobal("fetch", fetchKakao);
    query.mockResolvedValueOnce({ rows: [{ user_id: "user", access_expires_at: new Date("2027-01-01"), refresh_expires_at: new Date("2027-04-01") }] });
    const response = await login();
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ tokenType: "Bearer", user: { id: "user" } });
    expect(fetchKakao.mock.calls[0][0]).toBe("https://kauth.kakao.com/oauth/token");
    expect(fetchKakao.mock.calls[0][1].body.get("redirect_uri")).toBe(redirectUri);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });
  it("does not issue a session for a rejected authorization code", async () => {
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(Response.json({ error: "invalid_grant" }, { status: 400 })));
    expect((await login()).status).toBe(401);
    expect(query).not.toHaveBeenCalled();
  });
});

describe("private running history", () => {
  const id = "b".repeat(32);
  const owner = "d9707d42-9083-4bb2-a899-f193aed0d001";
  const headers = {Authorization: `Bearer rla_${"a".repeat(64)}`, "Content-Type":"application/json"};
  const record = {id, schema:1,status:"finished",startedAt:"2026-01-01T00:00:00Z",
    updatedAt:"2026-01-01T00:01:00Z",activeMicroseconds:60000000,distanceMeters:100,
    points:[],segmentStarts:[]};
  it("requires login for both summaries and GPS details", async () => {
    for (const path of ["", "/" + id]) {
      expect((await worker.request(api + "/me/runs" + path, {}, env)).status).toBe(401);
    }
  });
  it("saves summary and details together using the session owner", async () => {
    query.mockResolvedValueOnce({rows:[{user_id:owner}]}).mockResolvedValueOnce({})
      .mockResolvedValueOnce({rows:[{id:owner}]}).mockResolvedValueOnce({}).mockResolvedValueOnce({});
    const saved = await worker.request(api+"/me/runs/"+id,{method:"PUT",headers,body:JSON.stringify({...record,userId:"other"})},env);
    expect(saved.status).toBe(204);
    expect(query.mock.calls[2][1][0]).toBe(owner);
    expect(query.mock.calls.at(-1)?.[0]).toBe("COMMIT");
  });
  it("scopes the detail lookup to the session owner", async () => {
    query.mockResolvedValueOnce({rows:[{user_id:owner}]}).mockResolvedValueOnce({rows:[]});
    expect((await worker.request(api+"/me/runs/"+id,{headers},env)).status).toBe(404);
    expect(query.mock.calls[1][1]).toEqual([owner,id]);
  });
});
