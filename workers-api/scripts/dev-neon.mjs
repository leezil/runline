import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

const projectDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const secretsFile = resolve(projectDirectory, ".env.neon.local");
const secretsText = await readFile(secretsFile, "utf8");
const urlLine = secretsText
	.split(/\r?\n/)
	.find((line) => line.startsWith("NEON_DIRECT_URL="));
const directUrl = urlLine?.slice("NEON_DIRECT_URL=".length).trim();

if (!directUrl) {
	console.error("Set NEON_DIRECT_URL in .env.neon.local before starting Wrangler.");
	process.exit(1);
}

let parsedUrl;
try {
	parsedUrl = new URL(directUrl);
} catch {
	console.error("NEON_DIRECT_URL must be a valid PostgreSQL connection URL.");
	process.exit(1);
}

if (
	!['postgres:', 'postgresql:'].includes(parsedUrl.protocol) ||
	!parsedUrl.hostname.endsWith(".neon.tech") ||
	parsedUrl.hostname.includes("-pooler")
) {
	console.error("Use a direct, unpooled Neon PostgreSQL connection URL.");
	process.exit(1);
}

process.env.CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE = directUrl;

const wranglerPath = resolve(projectDirectory, "node_modules", "wrangler", "bin", "wrangler.js");
const wrangler = spawn(process.execPath, [wranglerPath, "dev"], {
	cwd: projectDirectory,
	env: process.env,
	stdio: "inherit",
});

wrangler.on("error", (error) => {
	console.error("Failed to start Wrangler:", error.message);
	process.exitCode = 1;
});

wrangler.on("exit", (code) => {
	process.exitCode = code ?? 1;
});
