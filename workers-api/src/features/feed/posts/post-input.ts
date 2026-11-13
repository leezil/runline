import type { Context } from "hono";
import { bodyLimit } from "hono/body-limit";
import { HttpError } from "../../../http/http-error";
import { parseUuid } from "../../../http/parse-uuid";
import type { AuthEnv } from "../../auth/require-auth";

export const postBodyLimit = bodyLimit({
	maxSize: 32 * 1024,
	onError: () => { throw new HttpError(413, "PAYLOAD_TOO_LARGE", "Request body is too large"); },
});

export async function readPostInput(c: Context<AuthEnv>) {
	const input = await c.req.json<Record<string, unknown> | null>().catch(() => null);
	if (!input || typeof input !== "object" || Array.isArray(input)) {
		throw new HttpError(400, "INVALID_REQUEST", "Expected a JSON object");
	}

	let body: string | undefined;
	if (input.body !== undefined) {
		if (typeof input.body !== "string" || !input.body.isWellFormed() || input.body.includes("\0")) {
			throw new HttpError(400, "INVALID_REQUEST", "body must be valid text");
		}
		body = input.body.trim();
		if ([...body].length > 2000) {
			throw new HttpError(400, "INVALID_REQUEST", "body must be at most 2000 characters");
		}
	}

	let mediaIds: string[] | undefined;
	if (input.mediaIds !== undefined) {
		if (!Array.isArray(input.mediaIds) || input.mediaIds.length > 4) {
			throw new HttpError(400, "INVALID_REQUEST", "mediaIds must be an array of up to 4 IDs");
		}
		mediaIds = input.mediaIds.map((id: unknown) => parseUuid(typeof id === "string" ? id : "", "mediaIds"));
		if (new Set(mediaIds).size !== mediaIds.length) {
			throw new HttpError(400, "INVALID_REQUEST", "mediaIds must not contain duplicates");
		}
	}
	return { body, mediaIds };
}

export function requirePostContent(body: string, mediaIds: string[]) {
	if (!body && mediaIds.length === 0) {
		throw new HttpError(400, "INVALID_REQUEST", "A post must contain text or a photo");
	}
}
