export const accessTokenPattern = /^rla_[a-f0-9]{64}$/;
export const refreshTokenPattern = /^rlr_[a-f0-9]{64}$/;
export const accessLifetimeSeconds = 15 * 60;
export const refreshLifetimeSeconds = 90 * 24 * 60 * 60;

function toHex(bytes: Uint8Array): string {
	return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function generateToken(prefix: string): string {
	return prefix + toHex(crypto.getRandomValues(new Uint8Array(32)));
}

export async function hashToken(token: string): Promise<string> {
	const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
	return toHex(new Uint8Array(digest));
}

export async function issueTokens() {
	const accessToken = generateToken("rla_");
	const refreshToken = generateToken("rlr_");
	const [accessHash, refreshHash] = await Promise.all([hashToken(accessToken), hashToken(refreshToken)]);
	return { accessToken, refreshToken, hashes: { accessHash, refreshHash } };
}
