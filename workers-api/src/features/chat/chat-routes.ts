import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { requireAuth, type AuthEnv } from "../auth/require-auth";
import { ClubError, invalid } from "../clubs/errors";
import { object, uuid } from "../clubs/validation";
import { allowedChatOrigin, chatStub } from "./chat-binding";
import { getChatState, history, markRead } from "./chat-service";

const chatRoutes = new Hono<AuthEnv>();
chatRoutes.get("/clubs/:clubId/chat/socket", async (c) => {
	const clubId = uuid(c.req.param("clubId"));
	const url = new URL(c.req.url);
	if (url.search) invalid("WebSocket URLs must not contain query parameters");
	if (url.protocol !== "https:" && !["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)) invalid("WSS is required");
	if (!allowedChatOrigin(c.env, c.req.raw)) throw new ClubError(403, "CHAT_ORIGIN_FORBIDDEN", "Origin is not allowed");
	if (!c.env.CLUB_CHAT) throw new ClubError(503, "CHAT_UNAVAILABLE", "Chat is not configured");
	return chatStub(c.env, clubId).fetch(c.req.raw);
});
chatRoutes.get("/clubs/:clubId/chat", requireAuth, async (c) => c.json({ ok: true, state: await getChatState(c.env.HYPERDRIVE.connectionString, c.get("userId"), uuid(c.req.param("clubId"))) }));
chatRoutes.get("/clubs/:clubId/chat/messages", requireAuth, async (c) => c.json({ ok: true, ...await history(c.env.HYPERDRIVE.connectionString, c.get("userId"), uuid(c.req.param("clubId")), c.req.query()) }));
chatRoutes.post("/clubs/:clubId/chat/read", requireAuth, bodyLimit({ maxSize: 1024 }), async (c) => {
	const body = object(await c.req.json().catch(() => invalid("JSON body required")));
	if (Object.keys(body).length !== 1 || !("sequence" in body)) invalid("sequence is required");
	return c.json({ ok: true, state: await markRead(c.env.HYPERDRIVE.connectionString, c.get("userId"), uuid(c.req.param("clubId")), body.sequence) });
});
export default chatRoutes;
