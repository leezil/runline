import { HttpError } from "../../../http/http-error";

const mediaUrlLifetimeSeconds = 300;
const encoder = new TextEncoder();

async function signingKey(secret: string | undefined): Promise<CryptoKey> {
	if (!secret) {
		throw new HttpError(503, "MEDIA_UNAVAILABLE", "Feed media is not configured");
	}
	return crypto.subtle.importKey(
		"raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign", "verify"],
	);
}

function signedMessage(mediaId: string, userId: string, expires: string) {
	return encoder.encode(`${mediaId}\n${userId}\n${expires}`);
}

export async function mediaUrl(
	requestUrl: string,
	mediaId: string,
	userId: string,
	secret: string | undefined,
): Promise<string> {
	const expires = String(Math.floor(Date.now() / 1000) + mediaUrlLifetimeSeconds);
	const signature = await crypto.subtle.sign("HMAC", await signingKey(secret), signedMessage(mediaId, userId, expires));
	const url = new URL(`/api/v1/feed/media/${mediaId}`, requestUrl);
	url.searchParams.set("expires", expires);
	url.searchParams.set("signature", Array.from(new Uint8Array(signature), (byte) => byte.toString(16).padStart(2, "0")).join(""));
	return url.toString();
}

export async function verifyMediaUrl(
	requestUrl: string,
	mediaId: string,
	userId: string,
	secret: string | undefined,
): Promise<boolean> {
	const params = new URL(requestUrl).searchParams;
	const expires = params.get("expires") ?? "";
	const signature = params.get("signature") ?? "";
	const now = Math.floor(Date.now() / 1000);
	if (!/^\d{1,12}$/.test(expires) || Number(expires) <= now || !/^[0-9a-f]{64}$/.test(signature)) {
		return false;
	}
	const signatureBytes = Uint8Array.from(signature.match(/../g) ?? [], (byte) => Number.parseInt(byte, 16));
	return crypto.subtle.verify("HMAC", await signingKey(secret), signatureBytes, signedMessage(mediaId, userId, expires));
}
