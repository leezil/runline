import { Hono } from "hono";
import { cors } from "hono/cors";
import type { WorkerBindings } from "./types";
import v1Routes from "./routes/v1";

const app = new Hono<{ Bindings: WorkerBindings }>();

app.use("/api/*", async (c, next) => {
	const corsMiddleware = cors({
		origin: c.env.ADMIN_WEB_ORIGIN,
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

export default app;
