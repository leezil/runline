import { createHash } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { Client } from "pg";

const directory = new URL("../migrations/", import.meta.url);
const args = new Set(process.argv.slice(2));
if ([...args].some((arg) => !["--plan", "--baseline-auth"].includes(arg))) {
	console.error("Usage: npm run db:migrate -- [--plan] [--baseline-auth]");
	process.exit(1);
}

const migrations = await Promise.all((await readdir(directory)).filter((name) => /^\d+_[a-z_]+\.sql$/.test(name)).sort().map(async (name) => {
	const sql = await readFile(new URL(name, directory), "utf8");
	return { name, sql, checksum: createHash("sha256").update(sql.replace(/\r\n/g, "\n")).digest("hex") };
}));

if (args.has("--plan")) {
	console.log("Local migration files (no database connection or changes):");
	for (const migration of migrations) console.log(`- ${migration.name}`);
	console.log("Use --baseline-auth only when 001_auth.sql has already been applied manually.");
	process.exit(0);
}

let client;
try {
	let connectionString = process.env.NEON_DIRECT_URL;
	if (!connectionString) {
		const contents = await readFile(new URL("../.env.neon.local", import.meta.url), "utf8");
		connectionString = contents.split(/\r?\n/).find((line) => line.startsWith("NEON_DIRECT_URL="))?.slice("NEON_DIRECT_URL=".length).trim();
	}
	if (!connectionString) throw new Error("DATABASE_URL_MISSING");
	client = new Client({ connectionString });
	await client.connect();
	await client.query("BEGIN");
	await client.query("SELECT pg_advisory_xact_lock(hashtext('runline_schema_migrations'))");
	await client.query(`CREATE TABLE IF NOT EXISTS runline_schema_migrations (
		name text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT clock_timestamp()
	)`);
	const { rows } = await client.query("SELECT name, checksum FROM runline_schema_migrations");
	const applied = new Map(rows.map((row) => [row.name, row.checksum]));
	for (const migration of migrations) {
		if (applied.has(migration.name)) {
			if (applied.get(migration.name) !== migration.checksum) throw new Error(`CHECKSUM_MISMATCH:${migration.name}`);
			continue;
		}
		if (migration.name === "001_auth.sql" && args.has("--baseline-auth")) {
			const expected = { runline_users: ["id", "kakao_user_id"], runline_sessions: ["user_id", "access_token_hash", "refresh_token_hash", "access_expires_at", "refresh_expires_at"] };
			for (const [table, columns] of Object.entries(expected)) {
				const result = await client.query("SELECT column_name FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = $1", [table]);
				if (columns.some((column) => !result.rows.some((row) => row.column_name === column))) throw new Error("AUTH_BASELINE_MISSING");
			}
			console.log(`Baseline: ${migration.name}`);
		} else {
			// Each migration also remains directly executable as a standalone SQL file.
			const sql = migration.sql.replace(/^\s*BEGIN;\s*/i, "").replace(/\s*COMMIT;\s*$/i, "");
			await client.query(sql);
			console.log(`Applied: ${migration.name}`);
		}
		await client.query("INSERT INTO runline_schema_migrations (name, checksum) VALUES ($1, $2)", [migration.name, migration.checksum]);
	}
	await client.query("COMMIT");
	console.log("Migrations committed.");
} catch (error) {
	await client?.query("ROLLBACK").catch(() => undefined);
	// Do not print driver messages or connection strings containing credentials.
	const known = error instanceof Error && /^(DATABASE_URL_MISSING|AUTH_BASELINE_MISSING|CHECKSUM_MISMATCH:)/.test(error.message);
	console.error("Migration failed; transaction rolled back.", known ? error.message : (error?.code ?? "DATABASE_ERROR"));
	console.error(`Connection: NEON_DIRECT_URL or ${fileURLToPath(new URL("../.env.neon.local", import.meta.url))}`);
	process.exitCode = 1;
} finally {
	await client?.end().catch(() => undefined);
}
