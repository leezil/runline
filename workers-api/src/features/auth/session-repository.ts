import type { Client } from "pg";
import { accessLifetimeSeconds, refreshLifetimeSeconds } from "./tokens";

type TokenHashes = { accessHash: string; refreshHash: string };
type SessionRow = {
	user_id: string;
	access_expires_at: Date;
	refresh_expires_at: Date;
};

export async function createSession(client: Client, kakaoUserId: string, hashes: TokenHashes) {
	const { rows } = await client.query<SessionRow>(
		`WITH account AS (
			INSERT INTO runline_users (kakao_user_id) VALUES ($1)
			ON CONFLICT (kakao_user_id) DO UPDATE SET kakao_user_id = EXCLUDED.kakao_user_id
			RETURNING id
		)
		INSERT INTO runline_sessions (
			user_id, access_token_hash, refresh_token_hash, access_expires_at, refresh_expires_at
		)
		SELECT id, $2, $3, now() + make_interval(secs => $4), now() + make_interval(secs => $5)
		FROM account
		RETURNING user_id, access_expires_at, refresh_expires_at`,
		[kakaoUserId, hashes.accessHash, hashes.refreshHash, accessLifetimeSeconds, refreshLifetimeSeconds],
	);
	return rows[0];
}

export async function rotateSession(client: Client, currentRefreshHash: string, hashes: TokenHashes) {
	const { rows } = await client.query<SessionRow>(
		`UPDATE runline_sessions
		SET access_token_hash = $2, refresh_token_hash = $3,
			access_expires_at = now() + make_interval(secs => $4),
			refresh_expires_at = now() + make_interval(secs => $5)
		WHERE refresh_token_hash = $1 AND refresh_expires_at > now()
		RETURNING user_id, access_expires_at, refresh_expires_at`,
		[currentRefreshHash, hashes.accessHash, hashes.refreshHash, accessLifetimeSeconds, refreshLifetimeSeconds],
	);
	return rows[0];
}

export async function revokeSession(client: Client, refreshHash: string): Promise<void> {
	await client.query("DELETE FROM runline_sessions WHERE refresh_token_hash = $1", [refreshHash]);
}

export async function findSessionUser(client: Client, accessHash: string): Promise<string | undefined> {
	const { rows } = await client.query<{ user_id: string }>(
		`SELECT user_id FROM runline_sessions
		WHERE access_token_hash = $1 AND access_expires_at > now() AND refresh_expires_at > now()`,
		[accessHash],
	);
	return rows[0]?.user_id;
}
