import { Hono } from "hono";
import { Client } from "pg";
import type { WorkerBindings } from "../../types";

const healthRoutes = new Hono<{ Bindings: WorkerBindings }>();

healthRoutes.get("/", (c) => {
	return c.json({ ok: true, service: "runline-api" });
});

healthRoutes.get("/db", async (c) => {
	const connectionString = c.env.HYPERDRIVE?.connectionString;
	if (!connectionString) {
		return c.json(
			{ ok: false, service: "runline-api", database: "unconfigured" },
			503,
		);
	}

	const client = new Client({ connectionString });
	try {
		await client.connect();
		const result = await client.query<{ postgis_enabled: boolean }>(
			"SELECT PostGIS_Full_Version() IS NOT NULL AS postgis_enabled",
		);

		return c.json({
			ok: true,
			service: "runline-api",
			database: "connected",
			postgis: result.rows[0]?.postgis_enabled === true,
		});
	} catch (error) {
		console.error(
			"Database health check failed",
			error instanceof Error ? error.name : "UnknownError",
		);
		return c.json(
			{ ok: false, service: "runline-api", database: "unavailable" },
			503,
		);
	} finally {
		await client.end().catch(() => undefined);
	}
});

export default healthRoutes;
