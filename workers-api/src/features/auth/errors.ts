export class AuthError extends Error {
	constructor(
		readonly status: 400 | 401 | 503,
		readonly code: string,
		message: string,
	) {
		super(message);
	}
}
