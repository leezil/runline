export class ClubError extends Error {
	constructor(
		readonly status: 400 | 403 | 404 | 409 | 413 | 429 | 503,
		readonly code: string,
		message: string,
	) {
		super(message);
	}
}

export function invalid(message: string): never {
	throw new ClubError(400, "INVALID_REQUEST", message);
}

export function missing(resource: string): never {
	throw new ClubError(404, "NOT_FOUND", `${resource} not found`);
}
