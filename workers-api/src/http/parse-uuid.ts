import { HttpError } from "./http-error";

export function parseUuid(value: string, field: string): string {
	if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
		throw new HttpError(400, "INVALID_REQUEST", `${field} must be a UUID`);
	}
	return value.toLowerCase();
}
