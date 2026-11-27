import { Hono } from "hono";
import { cors } from "hono/cors";
import { cleanupImages } from "./features/media/image-service";
import { ClubError } from "./features/clubs/errors";
import { AuthError } from "./features/auth/errors";
import { cleanUpMedia } from "./features/feed/media/media-cleanup";
import { HttpError } from "./http/http-error";
import type { WorkerBindings } from "./types";
import v1Routes from "./routes/v1";

export const app = new Hono<{ Bindings: WorkerBindings }>();

app.use("/api/*", async (c, next) => {
	const corsMiddleware = cors({
		origin: [c.env.ADMIN_WEB_ORIGIN, c.env.RUNLINE_WEB_ORIGIN].filter((origin): origin is string => !!origin),
		allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
		allowHeaders: ["Content-Type", "Authorization"],
	});

	return corsMiddleware(c, next);
});

app.route("/api/v1", v1Routes);

app.notFound((c) =>
	c.json(
		{ ok: false, error: { code: "NOT_FOUND", message: "Route not found" } },
		404,
	),
);

app.onError((error, c) => {
	if (error instanceof AuthError || error instanceof HttpError || error instanceof ClubError) {
		return c.json({ ok: false, error: { code: error.code, message: error.message } }, error.status);
	}

	console.error(
		"Unhandled API error",
		error instanceof Error ? error.name : "UnknownError",
	);
	return c.json(
		{
			ok: false,
			error: {
				code: "INTERNAL_SERVER_ERROR",
				message: "Internal server error",
			},
		},
		500,
	);
});

export default {
	fetch: app.fetch,
	async scheduled(controller, env) {
		if (controller.cron === "17 3 * * *") await cleanupImages(env);
		else await cleanUpMedia(env);
	},
} satisfies ExportedHandler<WorkerBindings>;
