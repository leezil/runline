import type { Client } from "pg";

export async function unfollowUser(client: Client, followerId: string, followingId: string): Promise<void> {
	await client.query("DELETE FROM runline_user_follows WHERE follower_id = $1 AND following_id = $2", [
		followerId,
		followingId,
	]);
}
