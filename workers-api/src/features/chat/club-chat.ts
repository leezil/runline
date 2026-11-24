import { DurableObject } from "cloudflare:workers";
import type { WorkerBindings } from "../../types";
import { AuthError } from "../auth/errors";
import { accessTokenPattern, hashToken } from "../auth/tokens";
import { ClubError } from "../clubs/errors";
import { allowedChatOrigin } from "./chat-binding";
import { authenticateChat, dispatchAuthorized, saveMessage, type ChatIdentity, type ChatState } from "./chat-service";

type SocketState = { deadline: number; ip: string; identity?: ChatIdentity; closed?: boolean; windowStart?: number; frames?: number };

export class ClubChat extends DurableObject<WorkerBindings> {
	private clubId?: string;
	private tail: Promise<unknown> = Promise.resolve();

	constructor(ctx: DurableObjectState, env: WorkerBindings) {
		super(ctx, env);
		ctx.blockConcurrencyWhile(async () => { this.clubId = await ctx.storage.get<string>("clubId"); });
	}

	private exclusive<T>(run: () => Promise<T>): Promise<T> {
		const result = this.tail.then(run);
		this.tail = result.catch(() => undefined);
		return result;
	}

	private state(ws: WebSocket): SocketState { return ws.deserializeAttachment() as SocketState; }
	private live() { return this.ctx.getWebSockets().filter((ws) => !this.state(ws)?.closed); }
	private close(ws: WebSocket, code: number, reason: string) {
		const state = this.state(ws);
		ws.serializeAttachment({ ...state, closed: true });
		try { ws.close(code, reason); } catch { /* already disconnected */ }
	}
	private send(ws: WebSocket, payload: unknown) {
		if (this.state(ws).closed) return;
		try { ws.send(JSON.stringify(payload)); }
		catch { this.close(ws, 1011, "Connection unavailable"); }
	}

	private async schedule() {
		const sockets = this.live();
		if (!sockets.length) { await this.ctx.storage.deleteAlarm(); return; }
		const next = Math.min(Date.now() + 30000, ...sockets.map((ws) => this.state(ws).identity?.expiresAt ?? this.state(ws).deadline));
		await this.ctx.storage.setAlarm(Math.max(Date.now() + 1, next));
	}

	async fetch(request: Request): Promise<Response> {
		return this.exclusive(async () => {
			const match = /^\/api\/v1\/clubs\/([0-9a-f-]{36})\/chat\/socket$/i.exec(new URL(request.url).pathname);
			if (!match || !this.env.CLUB_CHAT.idFromName(match[1].toLowerCase()).equals(this.ctx.id) || !allowedChatOrigin(this.env, request)) return new Response("Forbidden", { status: 403 });
			if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") return new Response("WebSocket upgrade required", { status: 426 });
			const ip = request.headers.get("CF-Connecting-IP") ?? "native-local";
			const pending = this.live().filter((ws) => !this.state(ws).identity);
			if (pending.length >= 20 || pending.filter((ws) => this.state(ws).ip === ip).length >= 3) return new Response("Too many pending connections", { status: 429 });
			if (!this.clubId) { this.clubId = match[1].toLowerCase(); await this.ctx.storage.put("clubId", this.clubId); }
			const pair = new WebSocketPair();
			this.ctx.acceptWebSocket(pair[1]);
			pair[1].serializeAttachment({ ip, deadline: Date.now() + 5000 } satisfies SocketState);
			await this.schedule();
			return new Response(null, { status: 101, webSocket: pair[0] });
		});
	}

	async webSocketMessage(ws: WebSocket, data: string | ArrayBuffer) {
		return this.exclusive(async () => {
			const state = this.state(ws);
			if (!state || state.closed) return;
			if (!state.windowStart || Date.now() - state.windowStart >= 10000) { state.windowStart = Date.now(); state.frames = 0; }
			state.frames = (state.frames ?? 0) + 1;
			ws.serializeAttachment(state);
			if (state.frames > 40) { this.close(ws, 4008, "Too many frames"); return; }
			if (typeof data !== "string" || new TextEncoder().encode(data).length > 16384) { this.close(ws, 1009, "Invalid frame size"); return; }
			let body: Record<string, unknown>;
			try {
				const value = JSON.parse(data);
				if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error();
				body = value;
			} catch { this.close(ws, 1008, "Invalid JSON"); return; }
			try {
				if (!state.identity) {
					if (Date.now() >= state.deadline || body.type !== "auth" || Object.keys(body).some((key) => !["type", "accessToken"].includes(key))
						|| typeof body.accessToken !== "string" || !accessTokenPattern.test(body.accessToken)) {
						this.close(ws, 4001, "Authentication required"); return;
					}
					await this.authenticate(await hashToken(body.accessToken), (identity, chat) => {
						const count = this.live().filter((socket) => this.state(socket).identity?.userId === identity.userId).length;
						if (count >= 3) throw new ClubError(429, "CHAT_CONNECTION_LIMIT", "Too many connections");
						ws.serializeAttachment({ ...state, identity });
						this.send(ws, { type: "ready", state: chat, expiresAt: identity.expiresAt });
					});
				} else {
					if (body.type === "ping" && Object.keys(body).length === 1) {
						await this.deliver();
						this.send(ws, { type: "pong" });
					} else {
						const result = await this.persist(state.identity, body);
						// persist resolves only after COMMIT. Authorize all recipients again
						// before dispatch, including a sender whose membership just changed.
						await this.deliver(ws, { type: "ack", message: result.message },
							result.duplicate ? undefined : { type: "message", message: result.message });
					}
				}
			} catch (error) {
				if (error instanceof AuthError || error instanceof ClubError && [403, 404].includes(error.status)) {
					this.close(ws, error instanceof AuthError ? 4001 : 4003, "Access revoked");
				} else if (error instanceof ClubError) {
					this.send(ws, { type: "error", code: error.code, clientMessageId: typeof body.clientMessageId === "string" ? body.clientMessageId.slice(0, 36) : undefined });
					if (!state.identity) this.close(ws, 4008, "Connection limit");
				} else {
					// No tokens or message contents in logs.
					console.warn("Chat operation unavailable");
					this.close(ws, 1011, "Temporarily unavailable");
				}
			} finally { await this.schedule(); }
		});
	}

	// Small service seams keep the real hibernating socket protocol independently
	// testable; SQL behavior is tested against PostgreSQL separately.
	protected authenticate(hash: string, ready: (identity: ChatIdentity, chat: ChatState) => void) {
		return authenticateChat(this.env.HYPERDRIVE.connectionString, this.clubId!, hash, ready);
	}
	protected persist(identity: ChatIdentity, value: unknown) {
		return saveMessage(this.env.HYPERDRIVE.connectionString, this.clubId!, identity, value);
	}
	protected authorized(identities: ChatIdentity[], dispatch: (valid: Set<string>, sessions?: Set<string>) => void) {
		return dispatchAuthorized(this.env.HYPERDRIVE.connectionString, this.clubId!, identities, dispatch);
	}

	private async deliver(sender?: WebSocket, acknowledgement?: unknown, broadcast?: unknown) {
		const sockets = this.live().filter((ws) => this.state(ws).identity);
		if (!sockets.length) return;
		await this.authorized(sockets.map((ws) => this.state(ws).identity!), (valid, sessions) => {
			for (const ws of sockets) {
				const identity = this.state(ws).identity!;
				if (!valid.has(`${identity.accessHash}:${identity.membershipId}`)) {
					this.close(ws, Date.now() >= identity.expiresAt || sessions && !sessions.has(identity.accessHash) ? 4001 : 4003, "Access revoked");
					continue;
				}
				if (ws === sender && acknowledgement) this.send(ws, acknowledgement);
				else if (broadcast && BigInt((broadcast as { message: { sequence: string } }).message.sequence) > BigInt(identity.visibleAfterSequence)) this.send(ws, broadcast);
			}
		});
	}

	async revalidate() {
		return this.exclusive(async () => {
			try { if (this.clubId) await this.deliver(); }
			catch { for (const ws of this.live()) this.close(ws, 1011, "Temporarily unavailable"); }
			await this.schedule();
		});
	}

	async alarm() {
		return this.exclusive(async () => {
			for (const ws of this.live()) {
				const state = this.state(ws);
				if (Date.now() >= (state.identity?.expiresAt ?? state.deadline)) this.close(ws, 4001, "Session expired");
			}
			try { if (this.clubId) await this.deliver(); }
			catch { for (const ws of this.live()) this.close(ws, 1011, "Temporarily unavailable"); }
			await this.schedule();
		});
	}

	webSocketClose(ws: WebSocket, code: number) {
		this.close(ws, code >= 1000 && code < 5000 && ![1004, 1005, 1006, 1015].includes(code) ? code : 1000, "Closed");
	}
	webSocketError(ws: WebSocket) { this.close(ws, 1011, "Connection error"); }
}
