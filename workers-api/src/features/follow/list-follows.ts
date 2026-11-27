import type { Client } from "pg";
import { HttpError } from "../../http/http-error";
import { parseUuid } from "../../http/parse-uuid";
import { profileNicknameSql } from "../profile/profile-nickname";

export type FollowListKind = "followers" | "following";

export function followListPage(query: Record<string, string>) {
	const limit = query.limit === undefined ? 30 : Number(query.limit);
	if (!/^\d+$/.test(query.limit ?? "30") || !Number.isInteger(limit) || limit < 1 || limit > 100) {
		throw new HttpError(400, "INVALID_REQUEST", "limit must be between 1 and 100");
	}
	return { limit, cursor: query.cursor === undefined ? null : parseUuid(query.cursor, "cursor") };
}

export async function listFollows(
	client: Client,
	userId: string,
	viewerId: string,
	kind: FollowListKind,
	page: ReturnType<typeof followListPage>,
) {
	const target = await client.query("SELECT id FROM runline_users WHERE id = $1", [userId]);
	if (!target.rows.length) throw new HttpError(404, "USER_NOT_FOUND", "User was not found");
	const ownerColumn = kind === "followers" ? "following_id" : "follower_id";
	const userColumn = kind === "followers" ? "follower_id" : "following_id";
	const { rows } = await client.query<{
		id: string; nickname: string; avatar_url: string | null; is_following: boolean;
	}>(
		`SELECT u.id, ${profileNicknameSql} AS nickname, profile.avatar_url,
			EXISTS (SELECT 1 FROM runline_user_follows mine WHERE mine.follower_id = $2 AND mine.following_id = u.id) AS is_following
		FROM runline_user_follows follows
		JOIN runline_users u ON u.id = follows.${userColumn}
		LEFT JOIN runline_user_profiles profile ON profile.user_id = u.id
		WHERE follows.${ownerColumn} = $1 AND ($3::uuid IS NULL OR u.id > $3::uuid)
		ORDER BY u.id ASC LIMIT $4`,
		[userId, viewerId, page.cursor, page.limit + 1],
	);
	const users = rows.slice(0, page.limit).map((row) => ({
		id: row.id, nickname: row.nickname, avatarUrl: row.avatar_url, isFollowing: row.is_following,
	}));
	return { users, nextCursor: rows.length > page.limit ? users[users.length - 1].id : null };
}
