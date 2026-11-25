import type { Client } from "pg";
import { profileNicknameSql } from "./profile-nickname";

type ProfileRow = {
	id: string;
	nickname: string;
	avatar_url: string | null;
	bio: string | null;
	follower_count: number;
	following_count: number;
	is_following: boolean;
};

export async function findProfile(client: Client, userId: string, viewerId: string) {
	const { rows: [row] } = await client.query<ProfileRow>(
		`SELECT u.id, ${profileNicknameSql} AS nickname, profile.avatar_url, profile.bio,
			(SELECT COUNT(*)::integer FROM runline_user_follows WHERE following_id = u.id) AS follower_count,
			(SELECT COUNT(*)::integer FROM runline_user_follows WHERE follower_id = u.id) AS following_count,
			EXISTS (
				SELECT 1 FROM runline_user_follows WHERE follower_id = $2 AND following_id = u.id
			) AS is_following
		FROM runline_users AS u
		LEFT JOIN runline_user_profiles AS profile ON profile.user_id = u.id
		WHERE u.id = $1`,
		[userId, viewerId],
	);
	if (!row) return undefined;

	return {
		id: row.id,
		nickname: row.nickname,
		avatarUrl: row.avatar_url,
		bio: row.bio,
		followerCount: row.follower_count,
		followingCount: row.following_count,
		isFollowing: row.is_following,
	};
}
