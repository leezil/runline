import { env, runInDurableObject, evictDurableObject } from "cloudflare:test";
import { afterEach, expect, it } from "vitest";
import { app as worker } from "../src/index";
import type { ChatIdentity, ChatMessage, ChatState } from "../src/features/chat/chat-service";

const token = `rla_${"a".repeat(64)}`;
const sockets: WebSocket[] = [];
type Stub = ReturnType<typeof env.CLUB_CHAT.get>;
type Backend = {
	authenticate(hash: string, ready: (identity: ChatIdentity, state: ChatState) => void): Promise<void>;
	persist(identity: ChatIdentity, input: unknown): Promise<{ message: ChatMessage; duplicate: boolean }>;
	authorized(identities: ChatIdentity[], dispatch: (valid: Set<string>) => void): Promise<void>;
};

async function backend(stub: Stub, allowed = true, boundary = "0") {
	await runInDurableObject(stub, async (instance) => {
		const target = instance as unknown as Backend;
		target.authenticate = async (hash, ready) => ready({ userId: boundary === "0" ? "user" : "new-user", membershipId: boundary === "0" ? "member" : "new-member", accessHash: hash, expiresAt: Date.now() + 60000, visibleAfterSequence: boundary },
			{ membership_id: boundary === "0" ? "member" : "new-member", user_id: "user", visible_after_sequence: boundary, last_read_sequence: boundary, last_sequence: boundary, unread_count: 0 });
		target.authorized = async (identities, dispatch) => dispatch(new Set(allowed ? identities.map((value) => `${value.accessHash}:${value.membershipId}`) : []));
		target.persist = async (_identity, input) => ({ duplicate: false, message: {
			id: "message", club_id: "club", sequence: "1", sender_membership_id: "member", sender_user_id: "user",
			client_message_id: (input as { clientMessageId: string }).clientMessageId,
			content: (input as { content: string }).content, created_at: new Date(), nickname: "러너", avatar_url: null,
		} });
	});
}

async function open(clubId: string) {
	const response = await worker.request(`https://example.com/api/v1/clubs/${clubId}/chat/socket`, { headers: { Upgrade: "websocket" } }, env);
	expect(response.status).toBe(101);
	const ws = response.webSocket!;
	ws.accept(); sockets.push(ws);
	const queue: unknown[] = [];
	const waiters: ((value: unknown) => void)[] = [];
	ws.addEventListener("message", (event) => {
		const data = JSON.parse(event.data as string);
		const next = waiters.shift(); if (next) next(data); else queue.push(data);
	});
	const closed = new Promise<CloseEvent>((resolve) => ws.addEventListener("close", resolve, { once: true }));
	return { ws, closed, next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise<unknown>((resolve) => waiters.push(resolve)) };
}

afterEach(() => { for (const ws of sockets.splice(0)) { try { ws.close(1000); } catch {} } });

it("rejects browser origins and token-bearing query strings before opening a socket", async () => {
	const path = `https://example.com/api/v1/clubs/${crypto.randomUUID()}/chat/socket`;
	expect((await worker.request(path, { headers: { Upgrade: "websocket", Origin: "https://attacker.example" } }, env)).status).toBe(403);
	expect((await worker.request(`${path}?token=secret`, { headers: { Upgrade: "websocket" } }, env)).status).toBe(400);
});

it("allows only authentication frames until authentication completes", async () => {
	const channel = await open(crypto.randomUUID());
	channel.ws.send(JSON.stringify({ type: "send", content: "not authenticated" }));
	expect((await channel.closed).code).toBe(4001);
});

it("uses a real hibernating WebSocket, acknowledges persisted messages and closes revoked recipients", async () => {
	const clubId = crypto.randomUUID();
	const stub = env.CLUB_CHAT.get(env.CLUB_CHAT.idFromName(clubId));
	await backend(stub);
	const first = await open(clubId);
	first.ws.send(JSON.stringify({ type: "auth", accessToken: token }));
	expect(await first.next()).toMatchObject({ type: "ready", state: { membership_id: "member" } });
	const second = await open(clubId);
	second.ws.send(JSON.stringify({ type: "auth", accessToken: token }));
	expect(await second.next()).toMatchObject({ type: "ready" });
	first.ws.send(JSON.stringify({ type: "send", clientMessageId: crypto.randomUUID(), content: "hello" }));
	expect(await first.next()).toMatchObject({ type: "ack", message: { content: "hello" } });
	expect(await second.next()).toMatchObject({ type: "message", message: { content: "hello" } });
	await backend(stub, false);
	await stub.revalidate();
	expect((await first.closed).code).toBe(4003);
	expect((await second.closed).code).toBe(4003);
});

it("restores serialized authentication after hibernation and still validates access", async () => {
	const clubId = crypto.randomUUID();
	const stub = env.CLUB_CHAT.get(env.CLUB_CHAT.idFromName(clubId));
	await backend(stub);
	const channel = await open(clubId);
	channel.ws.send(JSON.stringify({ type: "auth", accessToken: token }));
	expect(await channel.next()).toMatchObject({ type: "ready" });
	await evictDurableObject(stub);
	await backend(stub);
	channel.ws.send(JSON.stringify({ type: "ping" }));
	expect(await channel.next()).toMatchObject({ type: "pong" });
	await backend(stub, false); await stub.revalidate();
	expect((await channel.closed).code).toBe(4003);
});

it("applies the join boundary to live delivery and canonicalizes uppercase club IDs", async () => {
	const clubId = crypto.randomUUID();
	const stub = env.CLUB_CHAT.get(env.CLUB_CHAT.idFromName(clubId));
	await backend(stub);
	const first = await open(clubId.toUpperCase());
	first.ws.send(JSON.stringify({ type: "auth", accessToken: token })); await first.next();
	await backend(stub, true, "1");
	const second = await open(clubId);
	second.ws.send(JSON.stringify({ type: "auth", accessToken: token })); await second.next();
	first.ws.send(JSON.stringify({ type: "send", clientMessageId: crypto.randomUUID(), content: "pre-boundary" }));
	expect(await first.next()).toMatchObject({ type: "ack" });
	second.ws.send(JSON.stringify({ type: "ping" }));
	expect(await second.next()).toMatchObject({ type: "pong" });
});

it("rejects oversized frames and does not acknowledge a failed database write", async () => {
	const clubId = crypto.randomUUID();
	const stub = env.CLUB_CHAT.get(env.CLUB_CHAT.idFromName(clubId));
	await backend(stub);
	const first = await open(clubId);
	first.ws.send("x".repeat(16385));
	expect((await first.closed).code).toBe(1009);
	const second = await open(clubId);
	second.ws.send(JSON.stringify({ type: "auth", accessToken: token })); await second.next();
	await runInDurableObject(stub, async (instance) => {
		(instance as unknown as Backend).persist = async () => { throw new Error("Simulated SQL failure"); };
	});
	second.ws.send(JSON.stringify({ type: "send", clientMessageId: crypto.randomUUID(), content: "never acknowledged" }));
	expect((await second.closed).code).toBe(1011);
});
