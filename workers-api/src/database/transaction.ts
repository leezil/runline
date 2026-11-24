import type { Client } from "pg";

export async function inTransaction<T>(client: Client, run: () => Promise<T>): Promise<T> {
	await client.query("BEGIN");
	try {
		const result = await run();
		await client.query("COMMIT");
		return result;
	} catch (error) {
		await client.query("ROLLBACK").catch(() => undefined);
		throw error;
	}
}
