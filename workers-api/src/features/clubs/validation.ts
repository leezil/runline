import { invalid } from "./errors";

type ObjectBody = Record<string, unknown>;
export const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function uuid(value: string): string {
	if (!uuidPattern.test(value)) invalid("ID must be a UUID");
	return value;
}

export function object(value: unknown): ObjectBody {
	if (!value || typeof value !== "object" || Array.isArray(value)) invalid("A JSON object is required");
	return value as ObjectBody;
}

export function text(value: unknown, name: string, max: number, min = 1): string {
	if (typeof value !== "string") invalid(`${name} must be a string`);
	const result = value.trim();
	if ([...result].length < min || [...result].length > max || result.includes("\u0000")) {
		invalid(`${name} must contain ${min}-${max} characters`);
	}
	return result;
}

function imageUrl(value: unknown): string | null {
	if (value === null) return null;
	invalid("Use the image upload endpoint; external image URLs are not accepted");
}

function integer(value: unknown, name: string, min: number, max: number): number {
	if (typeof value !== "number" || !Number.isInteger(value) || value < min || value > max) {
		invalid(`${name} must be an integer between ${min} and ${max}`);
	}
	return value;
}

function timestamp(value: unknown, name: string): string {
	if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value) || !Number.isFinite(Date.parse(value))) {
		invalid(`${name} must be an ISO 8601 timestamp with a timezone`);
	}
	return new Date(value).toISOString();
}

function checkFields(body: ObjectBody, allowed: string[], patch: boolean) {
	if (Object.keys(body).some((key) => !allowed.includes(key))) invalid("Unknown field in request");
	if (patch && !Object.keys(body).length) invalid("At least one field is required");
}

export function clubInput(value: unknown, patch = false) {
	const body = object(value);
	checkFields(body, ["name", "description", "region", "imageUrl"], patch);
	return {
		...(body.name !== undefined || !patch ? { name: text(body.name, "name", 50) } : {}),
		...(body.region !== undefined || !patch ? { region: text(body.region, "region", 100) } : {}),
		...(body.description !== undefined || !patch ? { description: text(body.description ?? "", "description", 2000, 0) } : {}),
		...(body.imageUrl !== undefined || !patch ? { image_url: imageUrl(body.imageUrl ?? null) } : {}),
	};
}

export function profileInput(value: unknown) {
	const body = object(value);
	checkFields(body, ["nickname", "avatarUrl"], true);
	return {
		...(body.nickname !== undefined ? { nickname: text(body.nickname, "nickname", 30) } : {}),
		...(body.avatarUrl !== undefined ? { avatar_url: imageUrl(body.avatarUrl) } : {}),
	};
}

export function noticeInput(value: unknown, patch = false) {
	const body = object(value);
	checkFields(body, ["title", "content", "pinned"], patch);
	if (body.pinned !== undefined && typeof body.pinned !== "boolean") invalid("pinned must be a boolean");
	return {
		...(body.title !== undefined || !patch ? { title: text(body.title, "title", 100) } : {}),
		...(body.content !== undefined || !patch ? { content: text(body.content, "content", 10000) } : {}),
		...(body.pinned !== undefined || !patch ? { pinned: (body.pinned ?? false) as boolean } : {}),
	};
}

export function runInput(value: unknown, patch = false) {
	const body = object(value);
	checkFields(body, ["title", "description", "location", "startsAt", "endsAt", "registrationClosesAt", "capacity"], patch);
	return {
		...(body.title !== undefined || !patch ? { title: text(body.title, "title", 100) } : {}),
		...(body.description !== undefined || !patch ? { description: text(body.description ?? "", "description", 5000, 0) } : {}),
		...(body.location !== undefined || !patch ? { location: text(body.location, "location", 300) } : {}),
		...(body.startsAt !== undefined || !patch ? { starts_at: timestamp(body.startsAt, "startsAt") } : {}),
		...(body.endsAt !== undefined || !patch ? { ends_at: timestamp(body.endsAt, "endsAt") } : {}),
		...(body.registrationClosesAt !== undefined || !patch ? { registration_closes_at: timestamp(body.registrationClosesAt, "registrationClosesAt") } : {}),
		...(body.capacity !== undefined || !patch ? { capacity: integer(body.capacity, "capacity", 1, 10000) } : {}),
	};
}

export type Cursor = { scope: string; date: string; id: string; pinned?: boolean };
export type Page = { limit: number; cursor?: Cursor };

export function readPage(query: Record<string, string>, scope: string, pinned = false): Page {
	const limit = query.limit === undefined ? 20 : Number(query.limit);
	if (!/^\d+$/.test(query.limit ?? "20") || !Number.isInteger(limit) || limit < 1 || limit > 100) invalid("limit must be between 1 and 100");
	let cursor: Cursor | undefined;
	if (query.cursor) {
		try {
			if (query.cursor.length > 4096) invalid("Invalid cursor");
			const decoded = object(JSON.parse(atob(query.cursor)));
			if (decoded.scope !== scope || (pinned && typeof decoded.pinned !== "boolean")) invalid("Invalid cursor");
			cursor = { scope, date: timestamp(decoded.date, "cursor date"), id: uuid(String(decoded.id)), ...(pinned ? { pinned: decoded.pinned as boolean } : {}) };
		} catch { invalid("Invalid cursor"); }
	}
	return { limit, cursor };
}

export function pageResult<T extends { id: string }>(rows: T[], page: Page, scope: string, dateKey = "created_at", pinned = false) {
	const hasMore = rows.length > page.limit;
	const items = rows.slice(0, page.limit);
	const last = items[items.length - 1] as T & Record<string, unknown>;
	return {
		items,
		nextCursor: hasMore ? btoa(JSON.stringify({
			scope, date: last[dateKey], id: last.id, ...(pinned ? { pinned: last.pinned } : {}),
		})) : null,
	};
}
