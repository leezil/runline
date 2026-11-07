import { withDatabase } from "../../database/client";
import { AuthError } from "./errors";
import { createSession, revokeSession, rotateSession } from "./session-repository";
import { hashToken, issueTokens } from "./tokens";

function sessionResponse(
	session: Awaited<ReturnType<typeof createSession>>,
	tokens: Awaited<ReturnType<typeof issueTokens>>,
) {
	return {
		user: { id: session.user_id },
		tokenType: "Bearer",
		accessToken: tokens.accessToken,
		accessTokenExpiresAt: session.access_expires_at.toISOString(),
		refreshToken: tokens.refreshToken,
		refreshTokenExpiresAt: session.refresh_expires_at.toISOString(),
	};
}

export async function startSession(connectionString: string, kakaoUserId: string) {
	const tokens = await issueTokens();
	const session = await withDatabase(connectionString, (client) => createSession(client, kakaoUserId, tokens.hashes));
	return sessionResponse(session, tokens);
}

export async function refreshSession(connectionString: string, refreshToken: string) {
	const [refreshHash, tokens] = await Promise.all([hashToken(refreshToken), issueTokens()]);
	const session = await withDatabase(connectionString, (client) => rotateSession(client, refreshHash, tokens.hashes));
	if (!session) {
		throw new AuthError(401, "INVALID_REFRESH_TOKEN", "Runline refresh token is invalid or expired");
	}
	return sessionResponse(session, tokens);
}

export async function endSession(connectionString: string, refreshToken: string): Promise<void> {
	const refreshHash = await hashToken(refreshToken);
	await withDatabase(connectionString, (client) => revokeSession(client, refreshHash));
}
