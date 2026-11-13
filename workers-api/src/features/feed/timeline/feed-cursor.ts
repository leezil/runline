import { HttpError } from "../../../http/http-error";
import { parseUuid } from "../../../http/parse-uuid";

export function encodeFeedCursor(createdAt: string, id: string): string {
	return btoa(`${createdAt}|${id}`).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

export function decodeFeedCursor(cursor: string | undefined) {
	if (cursor === undefined) return { createdAt: null, id: null };
	if (!/^[A-Za-z0-9_-]{86}$/.test(cursor)) {
		throw new HttpError(400, "INVALID_CURSOR", "Invalid feed cursor");
	}

	try {
		const [createdAt, id] = atob(cursor.replace(/-/g, "+").replace(/_/g, "/")).split("|");
		if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z$/.test(createdAt) || createdAt.startsWith("0000")) {
			throw new Error("Invalid timestamp format");
		}
		const milliseconds = `${createdAt.slice(0, 23)}Z`;
		if (new Date(milliseconds).toISOString() !== milliseconds) throw new Error("Invalid timestamp");
		return { createdAt, id: parseUuid(id, "cursor ID") };
	} catch {
		throw new HttpError(400, "INVALID_CURSOR", "Invalid feed cursor");
	}
}
