import type { Client } from "pg";
import { AuthError } from "../auth/errors";
import { ClubError, invalid } from "../clubs/errors";
import { inClub, transaction, type Membership } from "../clubs/repository";
import { object, uuid } from "../clubs/validation";

export type ChatIdentity = { userId: string; membershipId: string; accessHash: string; expiresAt: number; visibleAfterSequence: string };
export type ChatMessage = {
	id: string; club_id: string; sequence: string; sender_membership_id: string; sender_user_id: string;
	client_message_id: string; content: string; created_at: Date; nickname: string; avatar_url: string | null;
};
export type ChatState = {
	membership_id: string; user_id: string; visible_after_sequence: string; last_read_sequence: string;
	last_sequence: string; unread_count: number;
};

export function sequence(value: unknown): string {
	if (typeof value !== "string" || !/^(0|[1-9][0-9]{0,18})$/.test(value) || BigInt(value) > 9223372036854775807n) invalid("Invalid message sequence");
	return value;
}

export function messageInput(value: unknown) {
	const body = object(value);
	if (Object.keys(body).some((key) => !["type", "clientMessageId", "content"].includes(key))) invalid("Unknown message field");
	if (body.type !== "send" || typeof body.content !== "string") invalid("Invalid message");
	const content = body.content.trim();
	if (!content || [...content].length > 2000 || new TextEncoder().encode(content).length > 8000 || content.includes("\u0000")) invalid("Messages must contain 1-2000 characters (up to 8000 bytes)");
	return { clientMessageId: uuid(String(body.clientMessageId)), content };
}

async function checkSession(client: Client, userId: string, accessHash: string) {
	const { rows } = await client.query<{ access_expires_at: Date }>(`SELECT access_expires_at FROM runline_sessions
		WHERE access_token_hash = $1 AND user_id = $2 AND access_expires_at > clock_timestamp()
		AND refresh_expires_at > clock_timestamp() FOR SHARE`, [accessHash, userId]);
	if (!rows[0]) throw new AuthError(401, "AUTH_REQUIRED", "Session expired or revoked");
	return new Date(rows[0].access_expires_at).getTime();
}

export async function chatState(client: Client, membership: Membership): Promise<ChatState> {
	const { rows } = await client.query<ChatState>(`SELECT m.id AS membership_id, m.user_id,
		m.chat_visible_after_sequence::text AS visible_after_sequence,
		s.last_read_sequence::text, c.chat_last_sequence::text AS last_sequence,
		(SELECT count(*)::int FROM club_chat_messages msg WHERE msg.club_id = c.id
		 AND msg.sequence > GREATEST(s.last_read_sequence, m.chat_visible_after_sequence)
		 AND msg.sender_membership_id <> m.id) AS unread_count
		FROM club_memberships m JOIN clubs c ON c.id = m.club_id JOIN club_chat_state s ON s.membership_id = m.id
		WHERE m.id = $1`, [membership.id]);
	return rows[0];
}

export function getChatState(connection: string, userId: string, clubId: string) {
	return inClub(connection, userId, clubId, false, ({ client, membership }) => chatState(client, membership));
}

const selectMessage = `SELECT msg.*, m.user_id AS sender_user_id, u.nickname, u.avatar_url
	FROM club_chat_messages msg JOIN club_memberships m ON m.id = msg.sender_membership_id
	JOIN runline_users u ON u.id = m.user_id`;

export function history(connection: string, userId: string, clubId: string, query: Record<string, string>) {
	if (query.before !== undefined && query.after !== undefined) invalid("Use before or after, not both");
	const before = query.before === undefined ? undefined : sequence(query.before);
	const after = query.after === undefined ? undefined : sequence(query.after);
	const limit = Number(query.limit ?? "50");
	if (!/^\d+$/.test(query.limit ?? "50") || !Number.isInteger(limit) || limit < 1 || limit > 100) invalid("limit must be between 1 and 100");
	return inClub(connection, userId, clubId, false, async ({ client, membership }) => {
		const state = await chatState(client, membership);
		const params: unknown[] = [clubId, state.visible_after_sequence];
		let filter = "";
		if (before !== undefined) { params.push(before); filter = "AND msg.sequence < $3::bigint"; }
		if (after !== undefined) { params.push(after); filter = "AND msg.sequence > $3::bigint"; }
		params.push(limit + 1);
		const { rows } = await client.query<ChatMessage>(`${selectMessage}
			WHERE msg.club_id = $1 AND msg.sequence > $2::bigint ${filter}
			ORDER BY msg.sequence ${after !== undefined ? "ASC" : "DESC"} LIMIT $${params.length}`, params);
		const items = rows.slice(0, limit);
		return { items, hasMore: rows.length > limit,
			nextSequence: rows.length > limit ? items[items.length - 1].sequence : null, state };
	});
}

export function markRead(connection: string, userId: string, clubId: string, value: unknown) {
	const readSequence = sequence(value);
	return inClub(connection, userId, clubId, false, async ({ client, membership }) => {
		const state = await chatState(client, membership);
		if (BigInt(readSequence) < BigInt(state.visible_after_sequence) || BigInt(readSequence) > BigInt(state.last_sequence)) invalid("Read sequence is outside the visible range");
		await client.query("UPDATE club_chat_state SET last_read_sequence = GREATEST(last_read_sequence, $2::bigint) WHERE membership_id = $1", [membership.id, readSequence]);
		return chatState(client, membership);
	});
}

export function authenticateChat(connection: string, clubId: string, accessHash: string, ready: (identity: ChatIdentity, state: ChatState) => void) {
	return transaction(connection, async (client) => {
		const club = await client.query("SELECT id FROM clubs WHERE id = $1 AND status = 'active' FOR SHARE", [clubId]);
		if (!club.rows[0]) throw new ClubError(403, "CLUB_MEMBERSHIP_REQUIRED", "Club is unavailable");
		const session = await client.query<{ user_id: string; access_expires_at: Date }>(`SELECT user_id, access_expires_at FROM runline_sessions
			WHERE access_token_hash = $1 AND access_expires_at > clock_timestamp() AND refresh_expires_at > clock_timestamp() FOR SHARE`, [accessHash]);
		if (!session.rows[0]) throw new AuthError(401, "AUTH_REQUIRED", "Session expired or revoked");
		const { rows } = await client.query<Membership>("SELECT * FROM club_memberships WHERE club_id = $1 AND user_id = $2 AND status = 'active'", [clubId, session.rows[0].user_id]);
		if (!rows[0]) throw new ClubError(403, "CLUB_MEMBERSHIP_REQUIRED", "Current membership is required");
		const state = await chatState(client, rows[0]);
		const identity = { userId: session.rows[0].user_id, membershipId: rows[0].id, accessHash, expiresAt: new Date(session.rows[0].access_expires_at).getTime(), visibleAfterSequence: state.visible_after_sequence };
		ready(identity, state);
	});
}

export async function saveMessage(connection: string, clubId: string, identity: ChatIdentity, value: unknown) {
	const input = messageInput(value);
	return inClub(connection, identity.userId, clubId, true, async ({ client, membership }) => {
		if (membership.id !== identity.membershipId) throw new ClubError(403, "CLUB_MEMBERSHIP_REQUIRED", "Membership changed; reconnect");
		await checkSession(client, identity.userId, identity.accessHash);
		const existing = await client.query<ChatMessage>(`${selectMessage} WHERE msg.sender_membership_id = $1 AND msg.client_message_id = $2`, [membership.id, input.clientMessageId]);
		if (existing.rows[0]) {
			if (existing.rows[0].content !== input.content) throw new ClubError(409, "MESSAGE_ID_CONFLICT", "A message ID cannot be reused for different content");
			return { message: existing.rows[0], duplicate: true };
		}
		const rate = await client.query<{ send_count: number }>(`UPDATE club_chat_state SET
			send_count = CASE WHEN send_window_started_at <= clock_timestamp() - interval '10 seconds' THEN 1 ELSE send_count + 1 END,
			send_window_started_at = CASE WHEN send_window_started_at <= clock_timestamp() - interval '10 seconds' THEN clock_timestamp() ELSE send_window_started_at END
			WHERE membership_id = $1 RETURNING send_count`, [membership.id]);
		if (rate.rows[0].send_count > 20) throw new ClubError(429, "CHAT_RATE_LIMIT", "Please wait before sending more messages");
		const counter = await client.query<{ sequence: string }>("UPDATE clubs SET chat_last_sequence = chat_last_sequence + 1 WHERE id = $1 RETURNING chat_last_sequence::text AS sequence", [clubId]);
		const inserted = await client.query<{ id: string }>(`INSERT INTO club_chat_messages (club_id, sequence, sender_membership_id, client_message_id, content)
			VALUES ($1, $2::bigint, $3, $4, $5) RETURNING id`, [clubId, counter.rows[0].sequence, membership.id, input.clientMessageId, input.content]);
		const { rows } = await client.query<ChatMessage>(`${selectMessage} WHERE msg.id = $1`, [inserted.rows[0].id]);
		return { message: rows[0], duplicate: false };
	});
}

// Hold club AND session read locks through dispatch. Leave/kick/closure and
// logout/rotation cannot commit between authorization and ws.send().
export function dispatchAuthorized(connection: string, clubId: string, identities: ChatIdentity[], dispatch: (valid: Set<string>, sessions?: Set<string>) => void | Promise<void>) {
	return transaction(connection, async (client) => {
		const club = await client.query("SELECT id FROM clubs WHERE id = $1 AND status = 'active' FOR SHARE", [clubId]);
		if (!club.rows[0]) { await dispatch(new Set()); return; }
		const sessions = await client.query<{ access_token_hash: string; user_id: string }>(`SELECT access_token_hash, user_id FROM runline_sessions
			WHERE access_token_hash = ANY($1::text[]) AND access_expires_at > clock_timestamp()
			AND refresh_expires_at > clock_timestamp() FOR SHARE`, [identities.map((identity) => identity.accessHash)]);
		const members = await client.query<{ id: string; user_id: string }>("SELECT id, user_id FROM club_memberships WHERE club_id = $1 AND status = 'active' AND id = ANY($2::uuid[])", [clubId, identities.map((identity) => identity.membershipId)]);
		const sessionKeys = new Set(sessions.rows.map((row) => `${row.access_token_hash}:${row.user_id}`));
		const memberKeys = new Set(members.rows.map((row) => `${row.id}:${row.user_id}`));
		const valid = identities.filter((identity) => sessionKeys.has(`${identity.accessHash}:${identity.userId}`) && memberKeys.has(`${identity.membershipId}:${identity.userId}`));
		await dispatch(new Set(valid.map((identity) => `${identity.accessHash}:${identity.membershipId}`)), new Set(sessions.rows.map((row) => row.access_token_hash)));
	});
}
