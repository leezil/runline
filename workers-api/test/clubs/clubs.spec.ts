import { readFile, readdir } from "node:fs/promises";
import { URL as NodeURL } from "node:url";
import { PGlite } from "@electric-sql/pglite";
import sharp from "sharp";
import type { Client } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { issueTokens } from "../../src/features/auth/tokens";
import type { WorkerBindings } from "../../src/types";
import { app as worker } from "../../src/index";
import { stripWebpMetadata } from "../../src/features/media/image-pipeline";
import { cleanupImages } from "../../src/features/media/image-service";

const harness = vi.hoisted(() => ({ run: undefined as undefined | ((run: (client: Client) => Promise<unknown>) => Promise<unknown>) }));
vi.mock("../../src/database/client", async (importOriginal) => ({
	...await importOriginal<typeof import("../../src/database/client")>(),
	withDatabase: (_connection: string, run: (client: Client) => Promise<unknown>) => harness.run!(run),
}));

const env = { HYPERDRIVE: { connectionString: "test" }, ADMIN_WEB_ORIGIN: "http://localhost:3000" } as WorkerBindings;
const base = "https://example.com/api/v1";
type User = { id: string; token: string };
let db: PGlite;
let owner: User;
let member: User;
let other: User;
let newcomer: User;
let failNextEvent = false;
const objects = new Map<string, Uint8Array>();

const readBytes = async (stream: ReadableStream<Uint8Array>) => new Uint8Array(await new Response(stream).arrayBuffer());
env.IMAGES = {
	async info(stream: ReadableStream<Uint8Array>) {
		const bytes = await readBytes(stream);
		const meta = await sharp(bytes).metadata();
		return { format: `image/${meta.format}`, fileSize: bytes.length,
			width: meta.autoOrient?.width ?? meta.width, height: meta.autoOrient?.height ?? meta.height };
	},
	input(stream: ReadableStream<Uint8Array>) {
		let options: ImageTransform = {};
		return {
			transform(value: ImageTransform) { options = value; return this; },
			async output(output: ImageOutputOptions) {
				const bytes = await readBytes(stream);
				const data = await sharp(bytes).rotate().resize({ width: options.width, height: options.height, fit: "inside", withoutEnlargement: true }).webp({ quality: output.quality }).toBuffer();
				return { response: () => new Response(data, { headers: { "Content-Type": "image/webp" } }) };
			},
		};
	},
} as unknown as ImagesBinding;
env.MEDIA_BUCKET = {
	async put(key: string, value: Uint8Array) { objects.set(key, new Uint8Array(value)); },
	async get(key: string) {
		const value = objects.get(key);
		return value ? { body: new Blob([new Uint8Array(value)]).stream(), size: value.length } : null;
	},
	async delete(keys: string | string[]) { for (const key of Array.isArray(keys) ? keys : [keys]) objects.delete(key); },
} as unknown as R2Bucket;

async function uploadImage(user: User, path: string, bytes: Uint8Array, type = "image/png") {
	const form = new FormData();
	form.append("file", new File([new Uint8Array(bytes)], "photo.png", { type }));
	return worker.request(`${base}${path}`, { method: "POST", headers: { Authorization: `Bearer ${user.token}` }, body: form }, env);
}

async function account(number: number, nickname: string): Promise<User> {
	const { rows } = await db.query<{ id: string }>("INSERT INTO runline_users (kakao_user_id, nickname) VALUES ($1, $2) RETURNING id", [number, nickname]);
	await db.query("INSERT INTO runline_user_profiles (user_id, nickname) VALUES ($1, $2)", [rows[0].id, nickname]);
	const tokens = await issueTokens();
	await db.query(`INSERT INTO runline_sessions (user_id, access_token_hash, refresh_token_hash, access_expires_at, refresh_expires_at)
		VALUES ($1, $2, $3, now() + interval '1 hour', now() + interval '1 day')`, [rows[0].id, tokens.hashes.accessHash, tokens.hashes.refreshHash]);
	return { id: rows[0].id, token: tokens.accessToken };
}

function request(user: User | null, path: string, method = "GET", body?: unknown) {
	return worker.request(`${base}${path}`, {
		method,
		headers: { ...(user ? { Authorization: `Bearer ${user.token}` } : {}), ...(body === undefined ? {} : { "Content-Type": "application/json" }) },
		...(body === undefined ? {} : { body: JSON.stringify(body) }),
	}, env);
}

async function call(user: User, path: string, method = "GET", body?: unknown, expectedStatus = 200) {
	const response = await request(user, path, method, body);
	const result = await response.json();
	expect(response.status, JSON.stringify(result)).toBe(expectedStatus);
	return result as Record<string, any>;
}

async function create(user = owner, name = "한강 러너스", region = "서울") {
	return call(user, "/clubs", "POST", { name, region, description: "함께 달려요" }, 201);
}

async function joinedClub() {
	const { club } = await create();
	const joined = await call(member, `/clubs/${club.id}/join`, "POST", undefined, 201);
	return { club, membership: joined.membership };
}

function runBody(overrides: Record<string, unknown> = {}) {
	return {
		title: "주말 5km", location: "한강공원", description: "천천히 함께 달려요", capacity: 3,
		startsAt: new Date(Date.now() + 86400000).toISOString(),
		endsAt: new Date(Date.now() + 90000000).toISOString(),
		registrationClosesAt: new Date(Date.now() + 82800000).toISOString(),
		...overrides,
	};
}

beforeAll(async () => {
	db = await PGlite.create();
	for (const name of (await readdir(new NodeURL("../../migrations/", import.meta.url))).filter((name) => name.endsWith(".sql")).sort()) {
		await db.exec(await readFile(new NodeURL(`../../migrations/${name}`, import.meta.url), "utf8"));
	}
	let queue = Promise.resolve();
	harness.run = async (run) => {
		// PGlite exposes a single connection. Queue whole connections/transactions;
		// real multi-connection lock contention is covered by the optional PostgreSQL suite.
		const previous = queue;
		let release!: () => void;
		queue = new Promise<void>((resolve) => { release = resolve; });
		await previous;
		try {
			return await run({ query: async (sql: string, values?: unknown[]) => {
				if (failNextEvent && sql.includes("INSERT INTO club_feed_events")) {
					failNextEvent = false;
					throw new Error("Simulated event storage failure");
				}
				return db.query(sql, values);
			} } as Client);
		} finally { release(); }
	};
});

beforeEach(async () => {
	failNextEvent = false;
	objects.clear();
	await db.exec("TRUNCATE runline_users, clubs CASCADE");
	owner = await account(1, "클럽장");
	member = await account(2, "멤버");
	other = await account(3, "다른클럽장");
	newcomer = await account(4, "새러너");
});

describe("shared image pipeline", () => {
	it("removes WebP EXIF/XMP while leaving a valid transparent image", async () => {
		const source = await sharp({ create: { width: 12, height: 8, channels: 4, background: "#00000000" } })
			.webp().withMetadata({ orientation: 1 }).toBuffer();
		expect((await sharp(source).metadata()).exif).toBeDefined();
		const stripped = stripWebpMetadata(source);
		const meta = await sharp(stripped).metadata();
		expect(meta.exif).toBeUndefined();
		expect(meta.xmp).toBeUndefined();
		expect(meta.hasAlpha).toBe(true);
		expect(await sharp(stripped).raw().toBuffer()).toHaveLength(12 * 8 * 4);
	});

	it("keeps the previous avatar on storage failure and cleans deleted image objects", async () => {
		const source = await sharp({ create: { width: 12, height: 8, channels: 3, background: "green" } }).png().toBuffer();
		const first = await uploadImage(owner, "/me/avatar", source);
		const { image } = await first.json() as any;
		const originalPut = env.MEDIA_BUCKET.put;
		let calls = 0;
		env.MEDIA_BUCKET.put = (async (...args: unknown[]) => {
			if (++calls === 2) throw new Error("Simulated thumbnail storage failure");
			return (originalPut as (...values: unknown[]) => unknown)(...args);
		}) as R2Bucket["put"];
		try { expect((await uploadImage(owner, "/me/avatar", source)).status).toBe(500); }
		finally { env.MEDIA_BUCKET.put = originalPut; }
		expect(objects.size).toBe(2);
		expect((await call(owner, "/me/profile")).profile.avatar_url).toBe(image.url);
		expect((await request(owner, image.url.replace("/api/v1", ""), "DELETE")).status).toBe(204);
		expect(await cleanupImages(env)).toBe(1);
		expect(objects.size).toBe(0);
	});

	it("optimizes avatar/cover images, creates thumbnails, and rejects external URL bypasses", async () => {
		const source = await sharp({ create: { width: 1800, height: 1200, channels: 3, background: "#30ab90" } }).jpeg().toBuffer();
		const response = await uploadImage(owner, "/me/avatar", source, "image/jpeg");
		expect(response.status).toBe(201);
		const { image } = await response.json() as any;
		expect(image.width).toBe(512);
		expect(image.height).toBe(341);
		expect(objects.size).toBe(2);
		const download = await request(member, image.url.replace("/api/v1", ""));
		expect(download.status).toBe(200);
		const meta = await sharp(await download.bytes()).metadata();
		expect(meta.format).toBe("webp");
		expect(meta.exif).toBeUndefined();
		expect(meta.xmp).toBeUndefined();
		expect((await call(owner, "/me/profile")).profile.avatar_url).toBe(image.url);
		expect((await request(owner, "/me/profile", "PATCH", { avatarUrl: "https://example.com/raw.jpg" })).status).toBe(400);
		const { club } = await create();
		expect((await uploadImage(owner, `/clubs/${club.id}/image`, source, "image/jpeg")).status).toBe(201);
		expect((await uploadImage(newcomer, `/clubs/${club.id}/image`, source, "image/jpeg")).status).toBe(403);
	});

	it("preserves transparency and EXIF orientation while discarding metadata and avoiding enlargement", async () => {
		const transparent = await sharp({ create: { width: 40, height: 20, channels: 4, background: "#00000000" } }).png().toBuffer();
		const response = await uploadImage(owner, "/me/avatar", transparent);
		const { image } = await response.json() as any;
		expect(image).toMatchObject({ width: 40, height: 20 });
		const data = await (await request(owner, image.url.replace("/api/v1", ""))).bytes();
		expect((await sharp(data).metadata()).hasAlpha).toBe(true);
		const rotated = await sharp({ create: { width: 60, height: 30, channels: 3, background: "red" } })
			.jpeg().withMetadata({ orientation: 6 }).toBuffer();
		const rotatedResponse = await uploadImage(owner, "/me/avatar", rotated, "image/jpeg");
		const rotatedImage = (await rotatedResponse.json() as any).image;
		expect(rotatedImage).toMatchObject({ width: 30, height: 60 });
		expect((await request(owner, image.url.replace("/api/v1", ""))).status).toBe(404);
	});

	it("rejects forged/corrupt images and excessively large dimensions without storing objects", async () => {
		expect((await uploadImage(owner, "/me/avatar", new TextEncoder().encode("not an image"))).status).toBe(400);
		const png = await sharp({ create: { width: 10, height: 10, channels: 3, background: "blue" } }).png().toBuffer();
		expect((await uploadImage(owner, "/me/avatar", png, "image/jpeg")).status).toBe(400);
		expect((await uploadImage(owner, "/me/avatar", png.subarray(0, 15))).status).toBe(400);
		const huge = await sharp({ create: { width: 12001, height: 1, channels: 3, background: "blue" } }).png().toBuffer();
		expect((await uploadImage(owner, "/me/avatar", huge)).status).toBe(400);
		expect(objects.size).toBe(0);
	});

	it("stores notice images in R2, exposes metadata only, and retains club privacy for both variants", async () => {
		const { club, membership } = await joinedClub();
		const notice = (await call(owner, `/clubs/${club.id}/notices`, "POST", { title: "사진 공지", content: "사진" }, 201)).notice;
		const source = await sharp({ create: { width: 1800, height: 900, channels: 4, background: "#11ab33" } }).png().toBuffer();
		const path = `/clubs/${club.id}/notices/${notice.id}/attachments`;
		const response = await uploadImage(owner, path, source);
		expect(response.status).toBe(201);
		const { image, attachment } = await response.json() as any;
		expect(image).toMatchObject({ width: 1600, height: 800 });
		const bytes = (await db.query("SELECT data FROM club_attachments WHERE id = $1", [attachment.id])).rows[0] as any;
		expect(bytes.data).toBeNull();
		expect((await request(member, image.url.replace("/api/v1", ""))).status).toBe(200);
		const thumbnail = await request(member, image.thumbnail_url.replace("/api/v1", ""));
		expect((await sharp(await thumbnail.bytes()).metadata()).width).toBe(400);
		expect((await request(newcomer, image.thumbnail_url.replace("/api/v1", ""))).status).toBe(403);
		expect((await request(member, `${path}/${attachment.id}`)).status).toBe(200);
		await request(owner, `/clubs/${club.id}/members/${membership.id}`, "DELETE");
		expect((await request(member, image.url.replace("/api/v1", ""))).status).toBe(403);
		await request(owner, `/clubs/${club.id}/notices/${notice.id}`, "DELETE");
		expect((await request(owner, image.url.replace("/api/v1", ""))).status).toBe(404);
	});

	it("keeps the main feed contract and profile alongside club features", async () => {
		await joinedClub();
		const { post } = await call(owner, "/feed/posts", "POST", { body: "5km 완료" }, 201);
		expect(post).toMatchObject({ body: "5km 완료", author: { id: owner.id, nickname: "클럽장" }, media: [] });
		expect((await call(member, "/feed/recommended")).posts[0].id).toBe(post.id);
		expect((await call(member, `/feed/posts/${post.id}`)).post.id).toBe(post.id);
		expect((await request(owner, "/feed/posts", "POST", { title: "old payload", content: "legacy" })).status).toBe(400);
		expect((await request(member, `/feed/posts/${post.id}`, "DELETE")).status).toBe(403);
		expect((await request(owner, `/feed/posts/${post.id}`, "DELETE")).status).toBe(204);
		expect((await request(owner, `/feed/posts/${post.id}`)).status).toBe(404);
	});
});
afterAll(async () => { await db?.close(); });

it("shares main profile updates with feed authors, club members and notices", async () => {
	const { club } = await joinedClub();
	const source = await sharp({ create: { width: 12, height: 8, channels: 3, background: "green" } }).png().toBuffer();
	const uploaded = await uploadImage(owner, "/me/avatar", source);
	expect(uploaded.status).toBe(201);
	const { image } = await uploaded.json() as any;
	await call(owner, "/me/profile", "PATCH", { nickname: "통합 프로필" });
	expect((await call(owner, "/me")).profile).toMatchObject({ nickname: "통합 프로필", avatarUrl: image.url });
	expect((await call(member, `/clubs/${club.id}/members?query=통합`)).items[0]).toMatchObject({ nickname: "통합 프로필", avatar_url: image.url });
	const { notice } = await call(owner, `/clubs/${club.id}/notices`, "POST", { title: "공지", content: "모임 안내" }, 201);
	expect((await call(member, `/clubs/${club.id}/notices/${notice.id}`)).notice.author_nickname).toBe("통합 프로필");
	const { post } = await call(owner, "/feed/posts", "POST", { body: "러닝 완료" }, 201);
	expect(post.author).toMatchObject({ nickname: "통합 프로필", avatarUrl: image.url });
	await call(member, `/users/${owner.id}/follow`, "PUT");
	expect((await call(member, `/users/${member.id}/following`)).users[0]).toMatchObject({ nickname: "통합 프로필", avatarUrl: image.url });
});

describe("follower and following lists", () => {
	it("returns the selected user's correct relationships and the viewer's follow state", async () => {
		await call(owner, `/users/${member.id}/follow`, "PUT");
		await call(owner, `/users/${other.id}/follow`, "PUT");
		await call(member, `/users/${owner.id}/follow`, "PUT");
		await call(newcomer, `/users/${owner.id}/follow`, "PUT");
		await call(other, `/users/${newcomer.id}/follow`, "PUT");
		const following = await call(owner, `/users/${owner.id}/following`);
		expect(following.users).toEqual([member.id, other.id].sort().map((id) => ({
			id, nickname: id === member.id ? "멤버" : "다른클럽장", avatarUrl: null, isFollowing: true,
		})));
		expect(following.nextCursor).toBeNull();
		const followers = await call(other, `/users/${owner.id}/followers`);
		expect(followers.users).toEqual([member.id, newcomer.id].sort().map((id) => ({
			id, nickname: id === member.id ? "멤버" : "새러너", avatarUrl: null, isFollowing: id === newcomer.id,
		})));
	});

	it("paginates without duplicates and removes an unfollowed user from both lists and counts", async () => {
		for (const target of [member, other, newcomer]) await call(owner, `/users/${target.id}/follow`, "PUT");
		const sortedIds = [member.id, other.id, newcomer.id].sort();
		const first = await call(owner, `/users/${owner.id}/following?limit=1`);
		expect(first.users.map((user: { id: string }) => user.id)).toEqual(sortedIds.slice(0, 1));
		expect(first.nextCursor).toBe(sortedIds[0]);
		await call(owner, `/users/${sortedIds[0]}/follow`, "DELETE");
		const next = await call(owner, `/users/${owner.id}/following?limit=2&cursor=${first.nextCursor}`);
		expect(next.users.map((user: { id: string }) => user.id)).toEqual(sortedIds.slice(1));
		expect(next.nextCursor).toBeNull();
		expect((await call(owner, "/me")).profile.followingCount).toBe(2);
		expect((await call(owner, `/users/${sortedIds[0]}/followers`)).users).toEqual([]);
		expect((await call(owner, `/users/${sortedIds[0]}`)).profile.followerCount).toBe(0);
	});

	it("uses fallback names and returns empty lists for users with no relationships", async () => {
		expect(await call(owner, `/users/${owner.id}/followers`)).toMatchObject({ users: [], nextCursor: null });
		expect(await call(owner, `/users/${owner.id}/following`)).toMatchObject({ users: [], nextCursor: null });
		await db.query("DELETE FROM runline_user_profiles WHERE user_id = $1", [member.id]);
		await call(owner, `/users/${member.id}/follow`, "PUT");
		expect((await call(owner, `/users/${owner.id}/following`)).users[0].nickname).toBe(`러너 ${member.id.slice(0, 8)}`);
	});

	it("authenticates both lists and rejects invalid targets, cursors and page sizes", async () => {
		for (const kind of ["followers", "following"]) {
			expect((await request(null, `/users/${owner.id}/${kind}`)).status).toBe(401);
			expect((await request(owner, `/users/invalid/${kind}`)).status).toBe(400);
			expect((await request(owner, `/users/00000000-0000-0000-0000-000000000000/${kind}`)).status).toBe(404);
			for (const query of ["cursor=invalid", "cursor=", "limit=0", "limit=101", "limit=-1", "limit=1.5"]) {
				expect((await request(owner, `/users/${owner.id}/${kind}?${query}`)).status).toBe(400);
			}
		}
	});
});

it("imports legacy club profiles without replacing main profiles", async () => {
	await db.query("UPDATE runline_users SET nickname = '예전 닉네임' WHERE id = $1", [owner.id]);
	await db.query("DELETE FROM runline_user_profiles WHERE user_id = $1", [member.id]);
	await db.query("UPDATE runline_users SET nickname = '클럽 프로필' WHERE id = $1", [member.id]);
	await db.exec(await readFile(new NodeURL("../../migrations/009_club_profiles.sql", import.meta.url), "utf8"));
	expect((await call(owner, "/me/profile")).profile.nickname).toBe("클럽장");
	expect((await call(member, "/me")).profile.nickname).toBe("클럽 프로필");
});

describe("discovery, membership and management", () => {
	it("authenticates every club area before accessing data", async () => {
		for (const [path, method] of [["/me/club", "GET"], ["/me/profile", "PATCH"], ["/clubs", "GET"], ["/clubs", "POST"], ["/clubs/recommended", "GET"], ["/clubs/demo/feed", "GET"], ["/clubs/demo/notices", "POST"], ["/clubs/demo/runs", "POST"]]) {
			expect((await request(null, path, method)).status).toBe(401);
		}
	});

	it("returns no club initially, filters discovery, and creates the owner membership atomically", async () => {
		expect(await call(owner, "/me/club")).toMatchObject({ club: null, membership: null });
		const created = await create();
		expect(created.membership.role).toBe("owner");
		expect(created.club.member_count).toBe(1);
		const mine = await call(owner, "/me/club");
		expect(mine.club.id).toBe(created.club.id);
		expect(mine.membership.id).toBe(created.membership.id);
		expect((await call(newcomer, "/clubs?query=한강&region=서울")).items).toHaveLength(1);
		expect((await call(newcomer, "/clubs?query=부산")).items).toHaveLength(0);
		expect((await call(newcomer, "/clubs/recommended?region=부산")).items).toHaveLength(0);
		expect((await call(newcomer, `/clubs/${created.club.id}`)).club.id).toBe(created.club.id);
		for (const path of ["/clubs", "/clubs/recommended", `/clubs/${created.club.id}`]) {
			expect((await request(owner, path)).status).toBe(409);
		}
	});

	it("prevents additional joining/creation and enforces the unique active membership in SQL", async () => {
		const { club } = await create();
		const second = await create(other, "부산 러너스", "부산");
		await call(member, `/clubs/${club.id}/join`, "POST", undefined, 201);
		expect((await request(member, `/clubs/${second.club.id}/join`, "POST")).status).toBe(409);
		expect((await request(member, "/clubs", "POST", { name: "추가 클럽", region: "서울" })).status).toBe(409);
		await expect(db.query("INSERT INTO club_memberships (club_id, user_id, role) VALUES ($1, $2, 'member')", [second.club.id, member.id])).rejects.toMatchObject({ code: "23505" });
		expect((await db.query("SELECT * FROM clubs")).rows).toHaveLength(2);
	});

	it("searches members, updates profiles and club information only with the right permissions", async () => {
		const { club } = await joinedClub();
		await call(member, "/me/profile", "PATCH", { nickname: "새닉네임" });
		expect((await call(owner, `/clubs/${club.id}/members?query=새닉`)).items[0]).toMatchObject({ nickname: "새닉네임", avatar_url: null, user_id: member.id });
		expect((await request(member, `/clubs/${club.id}`, "PATCH", { name: "변경" })).status).toBe(403);
		expect((await call(owner, `/clubs/${club.id}`, "PATCH", { name: "새 클럽명" })).club.name).toBe("새 클럽명");
		expect((await request(newcomer, `/clubs/${club.id}/members`)).status).toBe(403);
	});

	it("transfers ownership, blocks owner departure, preserves history and allows rejoining", async () => {
		const { club, membership } = await joinedClub();
		expect((await request(owner, `/clubs/${club.id}/leave`, "POST")).status).toBe(409);
		expect((await request(member, `/clubs/${club.id}/ownership`, "POST", { membershipId: membership.id })).status).toBe(403);
		expect((await request(owner, `/clubs/${club.id}/ownership`, "POST", { membershipId: membership.id })).status).toBe(204);
		expect((await call(member, `/clubs/${club.id}/home`)).membership.role).toBe("owner");
		const oldMembership = (await call(owner, "/me/club")).membership.id;
		expect((await request(owner, `/clubs/${club.id}/leave`, "POST")).status).toBe(204);
		expect((await request(owner, `/clubs/${club.id}/home`)).status).toBe(403);
		const rejoined = await call(owner, `/clubs/${club.id}/join`, "POST", undefined, 201);
		expect(rejoined.membership.id).not.toBe(oldMembership);
		expect((await db.query("SELECT status FROM club_memberships WHERE id = $1", [oldMembership])).rows[0]).toMatchObject({ status: "left" });
	});

	it("closes a club, terminates membership and removes it from discovery", async () => {
		const { club } = await joinedClub();
		expect((await request(member, `/clubs/${club.id}`, "DELETE")).status).toBe(403);
		expect((await request(owner, `/clubs/${club.id}`, "DELETE")).status).toBe(204);
		expect((await call(member, "/me/club")).club).toBeNull();
		expect((await request(member, `/clubs/${club.id}/join`, "POST")).status).toBe(404);
		expect((await call(newcomer, "/clubs/recommended")).items).toHaveLength(0);
		expect((await request(member, `/clubs/${club.id}/feed`)).status).toBe(404);
		await create(member, "새로운 시작");
	});
});

describe("notices and private attachments", () => {
	it("restricts notice writes to the owner, paginates pinned notices, and hides deleted notices from the feed", async () => {
		const { club } = await joinedClub();
		const path = `/clubs/${club.id}/notices`;
		expect((await request(member, path, "POST", { title: "공지", content: "내용" })).status).toBe(403);
		const first = await call(owner, path, "POST", { title: "고정", content: "내용", pinned: true }, 201);
		await call(owner, path, "POST", { title: "일반", content: "내용" }, 201);
		const page1 = await call(member, `${path}?limit=1`);
		expect(page1.items[0].id).toBe(first.notice.id);
		const page2 = await call(member, `${path}?limit=1&cursor=${encodeURIComponent(page1.nextCursor)}`);
		expect(page2.items[0].title).toBe("일반");
		expect(page2.nextCursor).toBeNull();
		expect((await request(member, `${path}/${first.notice.id}`, "PATCH", { title: "수정" })).status).toBe(403);
		await call(owner, `${path}/${first.notice.id}`, "PATCH", { title: "수정", pinned: false });
		expect((await call(member, `${path}/${first.notice.id}`)).notice.title).toBe("수정");
		expect((await request(owner, `${path}/${first.notice.id}`, "DELETE")).status).toBe(204);
		expect((await request(member, `${path}/${first.notice.id}`)).status).toBe(404);
		expect((await call(member, `/clubs/${club.id}/feed`)).items).toHaveLength(1);
	});

	it("keeps attachments private, enforces ownership and attachment count, and cleans up on deletion", async () => {
		const { club } = await joinedClub();
		const { notice } = await call(owner, `/clubs/${club.id}/notices`, "POST", { title: "분실물", content: "확인해주세요" }, 201);
		const path = `/clubs/${club.id}/notices/${notice.id}/attachments`;
		const upload = async (who: User, content = "분실물 사진 안내") => {
			const form = new FormData();
			form.append("file", new File([content], "안내.txt", { type: "text/plain" }));
			return worker.request(`${base}${path}`, { method: "POST", headers: { Authorization: `Bearer ${who.token}` }, body: form }, env);
		};
		expect((await upload(member)).status).toBe(403);
		const response = await upload(owner);
		expect(response.status).toBe(201);
		const { attachment } = await response.json() as any;
		const downloaded = await request(member, `${path}/${attachment.id}`);
		expect(downloaded.status).toBe(200);
		expect(await downloaded.text()).toBe("분실물 사진 안내");
		expect(downloaded.headers.get("Cache-Control")).toBe("no-store");
		expect(downloaded.headers.get("Content-Disposition")).toContain("attachment;");
		expect((await request(newcomer, `${path}/${attachment.id}`)).status).toBe(403);
		for (let i = 0; i < 4; i++) expect((await upload(owner)).status).toBe(201);
		expect((await upload(owner)).status).toBe(409);
		expect((await call(member, `/clubs/${club.id}/notices/${notice.id}`)).notice.attachments).toHaveLength(5);
		expect((await request(owner, `${path}/${attachment.id}`, "DELETE")).status).toBe(204);
		expect((await request(member, `${path}/${attachment.id}`)).status).toBe(404);
		expect((await request(owner, `/clubs/${club.id}/notices/${notice.id}`, "DELETE")).status).toBe(204);
		expect((await db.query("SELECT * FROM club_attachments")).rows).toHaveLength(0);
	});

	it("rolls back the notice if its feed event cannot be stored", async () => {
		const { club } = await create();
		failNextEvent = true;
		expect((await request(owner, `/clubs/${club.id}/notices`, "POST", { title: "실패", content: "저장 안 됨" })).status).toBe(500);
		expect((await db.query("SELECT * FROM club_notices")).rows).toHaveLength(0);
		expect((await db.query("SELECT * FROM club_feed_events")).rows).toHaveLength(0);
	});
});

describe("runs and the integrated feed", () => {
	it("lets every member create runs, includes the creator, limits capacity, and supports cancellation/rejoining", async () => {
		const { club } = await joinedClub();
		await call(newcomer, `/clubs/${club.id}/join`, "POST", undefined, 201);
		const path = `/clubs/${club.id}/runs`;
		const { run } = await call(member, path, "POST", runBody({ capacity: 2 }), 201);
		expect(run).toMatchObject({ participant_count: 1, is_participating: true, state: "recruiting" });
		expect((await request(owner, `${path}/${run.id}`, "PATCH", { title: "수정" })).status).toBe(403);
		await call(owner, `${path}/${run.id}/participants`, "POST", undefined, 201);
		expect((await request(newcomer, `${path}/${run.id}/participants`, "POST")).status).toBe(409);
		expect((await request(owner, `${path}/${run.id}/participants`, "POST")).status).toBe(409);
		expect((await request(member, `${path}/${run.id}`, "PATCH", { capacity: 1 })).status).toBe(409);
		expect((await request(owner, `${path}/${run.id}/participants/me`, "DELETE")).status).toBe(204);
		await call(newcomer, `${path}/${run.id}/participants`, "POST", undefined, 201);
		expect((await call(member, `${path}/${run.id}/participants`)).items).toHaveLength(2);
		expect((await request(member, `${path}/${run.id}/participants/me`, "DELETE")).status).toBe(409);
	});

	it("filters recruiting/upcoming/past runs and exposes creation, modification and cancellation in one feed", async () => {
		const { club } = await joinedClub();
		const path = `/clubs/${club.id}/runs`;
		const { run } = await call(member, path, "POST", runBody(), 201);
		await call(owner, `/clubs/${club.id}/notices`, "POST", { title: "회식 안내", content: "이번 주 회식" }, 201);
		await call(member, `${path}/${run.id}`, "PATCH", { title: "변경된 러닝", location: "여의도" });
		expect((await call(owner, `${path}?filter=recruiting`)).items).toHaveLength(1);
		expect((await call(owner, `${path}?filter=past`)).items).toHaveLength(0);
		expect((await request(member, `${path}/${run.id}/cancel`, "POST")).status).toBe(204);
		expect((await request(member, `${path}/${run.id}/cancel`, "POST")).status).toBe(204);
		expect((await call(owner, `${path}?filter=upcoming`)).items).toHaveLength(0);
		expect((await call(owner, `${path}?filter=cancelled`)).items[0].state).toBe("cancelled");
		const first = await call(owner, `/clubs/${club.id}/feed?limit=2`);
		const second = await call(owner, `/clubs/${club.id}/feed?limit=2&cursor=${encodeURIComponent(first.nextCursor)}`);
		const events = [...first.items, ...second.items];
		expect(new Set(events.map((event) => event.id)).size).toBe(4);
		expect(events.map((event) => event.type).sort()).toEqual(["notice_created", "run_cancelled", "run_created", "run_updated"]);
		expect(events.find((event) => event.type === "run_created").title).toBe("주말 5km");
		expect(events.find((event) => event.type === "run_updated").current_run_title).toBe("변경된 러닝");
		expect(second.nextCursor).toBeNull();
		await db.query("UPDATE club_runs SET starts_at = now() - interval '2 hours', ends_at = now() - interval '1 hour', registration_closes_at = now() - interval '3 hours', cancelled_at = NULL WHERE id = $1", [run.id]);
		expect((await call(owner, `${path}?filter=past`)).items[0].state).toBe("ended");
		expect((await request(member, `${path}/${run.id}`, "PATCH", { title: "과거 수정" })).status).toBe(409);
	});

	it("cancels future runs hosted by a removed member and clears upcoming attendance", async () => {
		const { club, membership } = await joinedClub();
		const path = `/clubs/${club.id}/runs`;
		const hosted = (await call(member, path, "POST", runBody(), 201)).run;
		const attending = (await call(owner, path, "POST", runBody(), 201)).run;
		await call(member, `${path}/${attending.id}/participants`, "POST", undefined, 201);
		expect((await request(owner, `/clubs/${club.id}/members/${membership.id}`, "DELETE")).status).toBe(204);
		expect((await request(member, `/clubs/${club.id}/feed`)).status).toBe(403);
		expect((await call(owner, `${path}/${hosted.id}`)).run.state).toBe("cancelled");
		expect((await call(owner, `${path}/${attending.id}`)).run.participant_count).toBe(1);
		expect((await call(owner, `/clubs/${club.id}/feed`)).items.some((event: any) => event.type === "run_cancelled" && event.target_id === hosted.id)).toBe(true);
	});

	it("does not expose another club's content even if IDs are known", async () => {
		const { club } = await joinedClub();
		const second = await create(other);
		const notice = (await call(other, `/clubs/${second.club.id}/notices`, "POST", { title: "비공개", content: "다른 클럽" }, 201)).notice;
		const run = (await call(other, `/clubs/${second.club.id}/runs`, "POST", runBody(), 201)).run;
		for (const suffix of ["home", "feed", "members", "notices", "runs", `runs/${run.id}/participants`]) {
			expect((await request(member, `/clubs/${second.club.id}/${suffix}`)).status).toBe(403);
		}
		expect((await request(member, `/clubs/${club.id}/notices/${notice.id}`)).status).toBe(404);
		expect((await request(member, `/clubs/${club.id}/runs/${run.id}`)).status).toBe(404);
		expect((await request(owner, `/clubs/${club.id}/notices/${notice.id}`, "DELETE")).status).toBe(404);
	});

	it("rejects malformed data, invalid schedules and incompatible cursors", async () => {
		const { club } = await create();
		for (const body of [{ title: "짧음" }, runBody({ capacity: 0 }), runBody({ endsAt: "bad" }), runBody({ registrationClosesAt: new Date(Date.now() + 172800000).toISOString() })]) {
			expect((await request(owner, `/clubs/${club.id}/runs`, "POST", body)).status).toBe(400);
		}
		expect((await request(owner, `/clubs/${club.id}/feed?cursor=garbage`)).status).toBe(400);
		expect((await request(owner, `/clubs/${club.id}/feed?limit=0`)).status).toBe(400);
		expect((await request(owner, `/clubs/${club.id}/runs?filter=constructor`)).status).toBe(400);
		expect((await request(owner, "/clubs/not-a-uuid/home")).status).toBe(400);
		expect((await request(owner, `/clubs/${club.id}`, "PATCH", { ownerId: member.id })).status).toBe(400);
		expect((await request(owner, "/me/profile", "PATCH", { avatarUrl: "javascript:alert(1)" })).status).toBe(400);
	});
});
