import { env } from "cloudflare:test";
import { afterEach, expect, it, vi } from "vitest";
import { mediaUrl, verifyMediaUrl } from "../src/features/feed/media/media-url";
import { cleanUpMedia } from "../src/features/feed/media/media-cleanup";
import { app } from "../src/index";

const api = "https://example.com/api/v1";
const userId = "7c1d6f94-18ab-4f15-b6e5-831295631410";
const otherUserId = "f75ff6b0-35ea-4a03-9dbc-915a13126f95";
const secret = "test-secret-for-feed-media-signing";
const authorization = { Authorization: `Bearer rla_${"a".repeat(64)}` };
const bindings = { ...env, FEED_MEDIA_SIGNING_SECRET: secret };
const png = Uint8Array.from(
	atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2uw0AAAAASUVORK5CYII="),
	(char) => char.charCodeAt(0),
);

const { query } = vi.hoisted(() => ({ query: vi.fn() }));
vi.mock("pg", () => ({
	Client: class {
		connect = vi.fn().mockResolvedValue(undefined);
		end = vi.fn().mockResolvedValue(undefined);
		query = query;
	},
}));

afterEach(() => {
	query.mockReset();
	vi.useRealTimers();
});

function upload(file: File) {
	const body = new FormData();
	body.set("file", file);
	return app.request(`${api}/feed/media`, { method: "POST", headers: authorization, body }, bindings);
}

it("rejects a file that only claims to be an image", async () => {
	query.mockResolvedValueOnce({ rows: [{ user_id: userId }] });
	const response = await upload(new File(["<svg></svg>"], "image.png", { type: "image/png" }));
	expect(response.status).toBe(415);
	expect(query).toHaveBeenCalledTimes(1);
});

it("stores the uploaded image in R2 and serves it only with a session and a signed URL", async () => {
	query.mockResolvedValue({ rows: [{ user_id: userId }], rowCount: 1 });
	const response = await upload(new File([png], "image.png", { type: "image/png" }));
	expect(response.status).toBe(201);
	const { media } = await response.json<{ media: { id: string } }>();
	const objectKey = `feed/${media.id}`;
	try {
		expect(await env.FEED_MEDIA.head(objectKey)).toMatchObject({ size: png.length });
		const url = await mediaUrl(api, media.id, userId, secret);
		expect((await app.request(url, {}, bindings)).status).toBe(401);

		query.mockResolvedValueOnce({ rows: [{ user_id: userId }] }).mockResolvedValueOnce({ rows: [] });
		expect((await app.request(url, { headers: authorization }, bindings)).status).toBe(404);

		query.mockResolvedValueOnce({ rows: [{ user_id: userId }] })
			.mockResolvedValueOnce({ rows: [{ object_key: objectKey, content_type: "image/png" }] });
		const image = await app.request(url, { headers: authorization }, bindings);
		expect(image.status).toBe(200);
		expect(image.headers.get("Content-Type")).toBe("image/png");
		expect(new Uint8Array(await image.arrayBuffer())).toEqual(png);
	} finally {
		await env.FEED_MEDIA.delete(objectKey);
	}
});

it("binds the signed URL to its viewer and rejects tampered or expired links", async () => {
	vi.useFakeTimers({ toFake: ["Date"] });
	vi.setSystemTime(new Date("2026-11-12T00:00:00Z"));
	const id = crypto.randomUUID();
	const url = await mediaUrl(api, id, userId, secret);
	expect(await verifyMediaUrl(url, id, userId, secret)).toBe(true);
	expect(await verifyMediaUrl(url, id, otherUserId, secret)).toBe(false);
	expect(await verifyMediaUrl(url, crypto.randomUUID(), userId, secret)).toBe(false);

	const changedExpiry = new URL(url);
	changedExpiry.searchParams.set("expires", "9999999999");
	expect(await verifyMediaUrl(changedExpiry.toString(), id, userId, secret)).toBe(false);
	vi.setSystemTime(new Date("2026-11-12T00:05:00Z"));
	expect(await verifyMediaUrl(url, id, userId, secret)).toBe(false);
});

it("cleans up discarded R2 objects and deletes their database reservations", async () => {
	const id = crypto.randomUUID();
	const objectKey = `feed/${id}`;
	await env.FEED_MEDIA.put(objectKey, png);
	query.mockResolvedValue({ rows: [] });
	query.mockImplementation((sql: string) => Promise.resolve({
		rows: sql.includes("FOR UPDATE SKIP LOCKED") ? [{ id, object_key: objectKey }] : [],
	}));
	try {
		await cleanUpMedia(bindings);
		expect(await env.FEED_MEDIA.head(objectKey)).toBeNull();
		expect(query).toHaveBeenCalledWith("DELETE FROM runline_post_media WHERE id = ANY($1::uuid[])", [[id]]);
		expect(query).toHaveBeenLastCalledWith("COMMIT");
	} finally {
		await env.FEED_MEDIA.delete(objectKey);
	}
});
