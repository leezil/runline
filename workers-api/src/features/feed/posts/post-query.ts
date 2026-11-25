import type { Client } from "pg";
import { profileNicknameSql } from "../../profile/profile-nickname";

export type PostRow = {
	id: string;
	body: string;
	created_at: string;
	updated_at: string;
	author_id: string;
	nickname: string;
	avatar_url: string | null;
	media_ids: string[];
};

export const postSelect = `
	SELECT p.id, p.body,
		to_char(p.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS created_at,
		to_char(p.updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS updated_at,
		u.id AS author_id, ${profileNicknameSql} AS nickname, profile.avatar_url,
		ARRAY(SELECT id FROM runline_post_media WHERE post_id = p.id ORDER BY position)::text[] AS media_ids
	FROM runline_posts p
	JOIN runline_users u ON u.id = p.author_id
	LEFT JOIN runline_user_profiles profile ON profile.user_id = p.author_id`;

export async function findPost(client: Client, id: string): Promise<PostRow | undefined> {
	const result = await client.query<PostRow>(`${postSelect} WHERE p.id = $1`, [id]);
	return result.rows[0];
}
