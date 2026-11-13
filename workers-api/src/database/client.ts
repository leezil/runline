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
