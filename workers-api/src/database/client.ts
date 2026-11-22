import { Client } from "pg";

export async function withDatabase<T>(
	connectionString: string,
	run: (client: Client) => Promise<T>,
): Promise<T> {
	const client = new Client({ connectionString });
	try {
		await client.connect();
		return await run(client);
	} finally {
		await client.end().catch(() => undefined);
	}
}

export async function withTransaction<T>(client: Client, run: () => Promise<T>): Promise<T> {
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
