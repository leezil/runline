import type { WorkerBindings } from "../../types";

export function chatStub(env: WorkerBindings, clubId: string) {
	return env.CLUB_CHAT.get(env.CLUB_CHAT.idFromName(clubId.toLowerCase()));
}

export async function invalidateChat(env: WorkerBindings, clubId: string | undefined) {
	if (!clubId || !env.CLUB_CHAT) return;
	try { await chatStub(env, clubId).revalidate(); }
	catch {
		// Dispatch still rechecks membership/session in SQL. During a transient RPC
		// failure no revoked socket can receive protected traffic; its alarm retries.
		console.warn("Chat connection invalidation deferred");
	}
}

export function allowedChatOrigin(env: WorkerBindings, request: Request): boolean {
	const origin = request.headers.get("Origin");
	if (!origin) return true; // Native clients have no browser Origin; token auth is still mandatory.
	return (env.CHAT_ALLOWED_ORIGINS ?? [env.RUNLINE_WEB_ORIGIN, env.ADMIN_WEB_ORIGIN].filter(Boolean).join(",")).split(",").map((value) => value.trim()).filter(Boolean).includes(origin);
}
