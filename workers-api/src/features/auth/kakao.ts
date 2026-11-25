import { AuthError } from "./errors";

function parseKakaoJson(key: string, value: unknown, context?: { source: string }) {
	if (key === "id" && typeof value === "number") {
		// Kakao member numbers are 64-bit integers.
		return context?.source ?? (Number.isSafeInteger(value) ? String(value) : null);
	}
	return value;
}

async function fetchKakao(path: string, accessToken: string) {
	try {
		const response = await fetch(`https://kapi.kakao.com${path}`, {
			headers: { Authorization: `Bearer ${accessToken}` },
			redirect: "manual",
			signal: AbortSignal.timeout(5_000),
		});
		const data: unknown = JSON.parse(await response.text(), parseKakaoJson);
		if (typeof data !== "object" || data === null) throw new Error();
		return { status: response.status, ok: response.ok, data: data as Record<string, unknown> };
	} catch {
		throw new AuthError(503, "KAKAO_UNAVAILABLE", "Kakao login is temporarily unavailable");
	}
}

async function readKakao(path: string, accessToken: string) {
	const { status, ok, data } = await fetchKakao(path, accessToken);
	if (status === 401 || (status === 400 && data.code === -2)) {
		throw new AuthError(401, "INVALID_KAKAO_TOKEN", "Kakao access token is invalid");
	}
	if (!ok) {
		throw new AuthError(503, "KAKAO_UNAVAILABLE", "Kakao login is temporarily unavailable");
	}
	return data;
}

export async function verifyKakaoUser(accessToken: string, appId: string): Promise<string> {
	const token = await readKakao("/v1/user/access_token_info", accessToken);
	if (typeof token.app_id !== "number" || String(token.app_id) !== appId ||
		typeof token.expires_in !== "number" || token.expires_in <= 0) {
		throw new AuthError(401, "INVALID_KAKAO_TOKEN", "Kakao access token is invalid");
	}

	const user = await readKakao("/v2/user/me?property_keys=%5B%5D", accessToken);
	const id = user.id;
	if (typeof id !== "string" || !/^[1-9][0-9]{0,18}$/.test(id) || BigInt(id) > 9223372036854775807n || token.id !== id) {
		throw new AuthError(401, "INVALID_KAKAO_TOKEN", "Kakao user could not be verified");
	}
	return id;
}
