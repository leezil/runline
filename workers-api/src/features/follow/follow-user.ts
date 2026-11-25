import type { Client } from "pg";

export async function followUser(client: Client, followerId: string, followingId: string): Promise<boolean> {
	const { rows: [row] } = await client.query<{ target_exists: boolean }>(
		`WITH target AS (
			SELECT id FROM runline_users WHERE id = $2 FOR KEY SHARE
		), new_follow AS (
			INSERT INTO runline_user_follows (follower_id, following_id)
			SELECT $1, id FROM target
			ON CONFLICT (follower_id, following_id) DO NOTHING
		)
		SELECT EXISTS (SELECT 1 FROM target) AS target_exists`,
		[followerId, followingId],
	);
	return row.target_exists;
}
