import { Hono, type Context } from "hono";
import { bodyLimit } from "hono/body-limit";
import { requireAuth, type AuthEnv } from "../auth/require-auth";
import * as clubs from "./club-service";
import * as notices from "./notice-service";
import * as runs from "./run-service";
import { listFeed } from "./feed-service";
import { invalid } from "./errors";
import { uploadImage, getImage } from "../media/image-service";
import { imageSignature } from "../media/image-pipeline";
import { invalidateChat } from "../chat/chat-binding";
import { clubInput, noticeInput, object, profileInput, readPage, runInput, text, uuid } from "./validation";

const clubRoutes = new Hono<AuthEnv>();
export const meRoutes = new Hono<AuthEnv>();

const connection = (c: Context<AuthEnv>) => c.env.HYPERDRIVE.connectionString;
const user = (c: Context<AuthEnv>) => c.get("userId");
const id = (c: Context<AuthEnv>, name = "clubId") => uuid(c.req.param(name) ?? "");
const filterText = (value: string | undefined, name: string, max: number) => text(value ?? "", name, max, 0);

async function json(c: Context<AuthEnv>) {
	return c.req.json<unknown>().catch(() => invalid("A valid JSON body is required"));
}

for (const routes of [clubRoutes, meRoutes]) {
	const paths = routes === clubRoutes ? ["*"] : ["/club", "/profile"];
	for (const path of paths) {
		routes.use(path, requireAuth);
		routes.use(path, async (c, next) => {
			const upload = c.req.method === "POST" && /\/notices\/[^/]+\/attachments$/.test(c.req.path);
			return bodyLimit({
				maxSize: upload ? 5 * 1024 * 1024 + 8192 : 100 * 1024,
				onError: (ctx) => ctx.json({ ok: false, error: { code: "PAYLOAD_TOO_LARGE", message: "Request body is too large" } }, 413),
			})(c, next);
		});
	}
}

meRoutes.get("/club", async (c) => c.json({ ok: true, ...await clubs.myClub(connection(c), user(c)) }));
meRoutes.get("/profile", async (c) => c.json({ ok: true, profile: await clubs.profile(connection(c), user(c)) }));
meRoutes.patch("/profile", async (c) => c.json({ ok: true, profile: await clubs.profile(connection(c), user(c), profileInput(await json(c))) }));

clubRoutes.get("/", async (c) => {
	const query = filterText(c.req.query("query"), "query", 50);
	const region = filterText(c.req.query("region"), "region", 100);
	const scope = clubs.discoveryScope(query, region, false);
	return c.json({ ok: true, ...await clubs.discover(connection(c), user(c), readPage(c.req.query(), scope), query, region, false) });
});

clubRoutes.get("/recommended", async (c) => {
	const region = filterText(c.req.query("region"), "region", 100);
	const scope = clubs.discoveryScope("", region, true);
	return c.json({ ok: true, ...await clubs.discover(connection(c), user(c), readPage(c.req.query(), scope), "", region, true) });
});

clubRoutes.post("/", async (c) => c.json({ ok: true, ...await clubs.createClub(connection(c), user(c), clubInput(await json(c))) }, 201));
clubRoutes.get("/:clubId", async (c) => c.json({ ok: true, club: await clubs.publicClub(connection(c), user(c), id(c)) }));
clubRoutes.post("/:clubId/join", async (c) => c.json({ ok: true, ...await clubs.joinClub(connection(c), user(c), id(c)) }, 201));
clubRoutes.get("/:clubId/home", async (c) => c.json({ ok: true, ...await clubs.clubHome(connection(c), user(c), id(c)) }));
clubRoutes.patch("/:clubId", async (c) => c.json({ ok: true, club: await clubs.editClub(connection(c), user(c), id(c), clubInput(await json(c), true)) }));
clubRoutes.delete("/:clubId", async (c) => {
	await clubs.closeClub(connection(c), user(c), id(c));
	await invalidateChat(c.env, id(c));
	return c.body(null, 204);
});
clubRoutes.post("/:clubId/leave", async (c) => {
	await clubs.leaveClub(connection(c), user(c), id(c));
	await invalidateChat(c.env, id(c));
	return c.body(null, 204);
});
clubRoutes.post("/:clubId/ownership", async (c) => {
	const body = object(await json(c));
	if (Object.keys(body).length !== 1) invalid("membershipId is required");
	await clubs.transferOwnership(connection(c), user(c), id(c), uuid(String(body.membershipId)));
	return c.body(null, 204);
});

clubRoutes.get("/:clubId/members", async (c) => {
	const clubId = id(c);
	const query = filterText(c.req.query("query"), "query", 30);
	return c.json({ ok: true, ...await clubs.listMembers(connection(c), user(c), clubId, readPage(c.req.query(), `members:${clubId}:${encodeURIComponent(query)}`), query) });
});
clubRoutes.delete("/:clubId/members/:membershipId", async (c) => {
	await clubs.kickMember(connection(c), user(c), id(c), id(c, "membershipId"));
	await invalidateChat(c.env, id(c));
	return c.body(null, 204);
});

clubRoutes.get("/:clubId/notices", async (c) => {
	const clubId = id(c);
	return c.json({ ok: true, ...await notices.listNotices(connection(c), user(c), clubId, readPage(c.req.query(), `notices:${clubId}`, true)) });
});
clubRoutes.post("/:clubId/notices", async (c) => c.json({ ok: true, notice: await notices.createNotice(connection(c), user(c), id(c), noticeInput(await json(c))) }, 201));
clubRoutes.get("/:clubId/notices/:noticeId", async (c) => c.json({ ok: true, notice: await notices.getNotice(connection(c), user(c), id(c), id(c, "noticeId")) }));
clubRoutes.patch("/:clubId/notices/:noticeId", async (c) => c.json({ ok: true, notice: await notices.editNotice(connection(c), user(c), id(c), id(c, "noticeId"), noticeInput(await json(c), true)) }));
clubRoutes.delete("/:clubId/notices/:noticeId", async (c) => {
	await notices.deleteNotice(connection(c), user(c), id(c), id(c, "noticeId"));
	return c.body(null, 204);
});
clubRoutes.post("/:clubId/notices/:noticeId/attachments", async (c) => {
	const clubId = id(c);
	const noticeId = id(c, "noticeId");
	const form = await c.req.formData().catch(() => invalid("multipart/form-data with a file field is required"));
	const files = form.getAll("file");
	if (files.length !== 1 || !(files[0] instanceof File)) invalid("Exactly one file field is required");
	const header = new Uint8Array(await files[0].slice(0, 12).arrayBuffer());
	if (files[0].type.startsWith("image/") || imageSignature(header)) {
		return c.json({ ok: true, ...await uploadImage(c.env, user(c), { purpose: "club_notice", clubId, noticeId }, files[0]) }, 201);
	}
	const file = await notices.attachmentInput(files[0]);
	return c.json({ ok: true, attachment: await notices.uploadAttachment(connection(c), user(c), clubId, noticeId, file) }, 201);
});
clubRoutes.get("/:clubId/notices/:noticeId/attachments/:attachmentId", async (c) => {
	const file = await notices.downloadAttachment(connection(c), user(c), id(c), id(c, "noticeId"), id(c, "attachmentId"));
	if (file.image_id) return getImage(c.env, user(c), file.image_id, c.req.query("variant") ?? "full");
	return new Response(new Uint8Array(file.data), {
		headers: {
			"Content-Type": file.content_type,
			"Content-Disposition": `attachment; filename="attachment"; filename*=UTF-8''${encodeURIComponent(file.filename).replace(/['()*]/g, (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`)}`,
			"Content-Length": String(file.data.byteLength),
			"Cache-Control": "no-store",
			"X-Content-Type-Options": "nosniff",
		},
	});
});
clubRoutes.delete("/:clubId/notices/:noticeId/attachments/:attachmentId", async (c) => {
	await notices.deleteAttachment(connection(c), user(c), id(c), id(c, "noticeId"), id(c, "attachmentId"));
	return c.body(null, 204);
});

clubRoutes.get("/:clubId/runs", async (c) => {
	const clubId = id(c);
	const filter = c.req.query("filter") ?? "all";
	return c.json({ ok: true, ...await runs.listRuns(connection(c), user(c), clubId, readPage(c.req.query(), `runs:${clubId}:${filter}`), filter) });
});
clubRoutes.post("/:clubId/runs", async (c) => c.json({ ok: true, run: await runs.createRun(connection(c), user(c), id(c), runInput(await json(c))) }, 201));
clubRoutes.get("/:clubId/runs/:runId", async (c) => c.json({ ok: true, run: await runs.getRun(connection(c), user(c), id(c), id(c, "runId")) }));
clubRoutes.patch("/:clubId/runs/:runId", async (c) => c.json({ ok: true, run: await runs.editRun(connection(c), user(c), id(c), id(c, "runId"), runInput(await json(c), true)) }));
clubRoutes.post("/:clubId/runs/:runId/cancel", async (c) => {
	await runs.cancelRun(connection(c), user(c), id(c), id(c, "runId"));
	return c.body(null, 204);
});
clubRoutes.post("/:clubId/runs/:runId/participants", async (c) => c.json({ ok: true, run: await runs.joinRun(connection(c), user(c), id(c), id(c, "runId")) }, 201));
clubRoutes.delete("/:clubId/runs/:runId/participants/me", async (c) => {
	await runs.leaveRun(connection(c), user(c), id(c), id(c, "runId"));
	return c.body(null, 204);
});
clubRoutes.get("/:clubId/runs/:runId/participants", async (c) => {
	const clubId = id(c);
	const runId = id(c, "runId");
	return c.json({ ok: true, ...await runs.listParticipants(connection(c), user(c), clubId, runId, readPage(c.req.query(), `participants:${clubId}:${runId}`)) });
});

clubRoutes.get("/:clubId/feed", async (c) => {
	const clubId = id(c);
	return c.json({ ok: true, ...await listFeed(connection(c), user(c), clubId, readPage(c.req.query(), `feed:${clubId}`)) });
});

export default clubRoutes;
