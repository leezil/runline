import type { Client } from "pg";
import type { WorkerBindings } from "../../types";
import { ClubError, missing } from "../clubs/errors";
import { inClub, requireOwner, transaction } from "../clubs/repository";
import { optimizeImage, type ImagePurpose } from "./image-pipeline";

export type ImageTarget = { purpose: ImagePurpose; clubId?: string; noticeId?: string; postId?: string };
type ImageRow = {
	id: string; uploader_user_id: string; purpose: ImagePurpose; club_id: string | null; notice_id: string | null; post_id: string | null;
	object_key: string; thumbnail_key: string; width: number; height: number; size: number; thumbnail_size: number; created_at: Date;
};

export function imageResponse(row: Pick<ImageRow, "id" | "width" | "height" | "size" | "thumbnail_size">) {
	return { id: row.id, width: row.width, height: row.height, size: row.size, thumbnail_size: row.thumbnail_size,
		content_type: "image/webp", url: `/api/v1/media/images/${row.id}`, thumbnail_url: `/api/v1/media/images/${row.id}?variant=thumbnail` };
}

async function forUpload<T>(env: WorkerBindings, userId: string, target: ImageTarget, run: (client: Client) => Promise<T>) {
	if (target.purpose === "club_cover" || target.purpose === "club_notice") {
		return inClub(env.HYPERDRIVE.connectionString, userId, target.clubId!, true, async ({ client, membership }) => {
			requireOwner(membership);
			if (target.purpose === "club_notice") {
				const notice = await client.query("SELECT id FROM club_notices WHERE id = $1 AND club_id = $2 AND deleted_at IS NULL", [target.noticeId, target.clubId]);
				if (!notice.rows[0]) missing("Notice");
				const count = await client.query<{ count: number }>("SELECT count(*)::int AS count FROM club_attachments WHERE notice_id = $1", [target.noticeId]);
				if (count.rows[0].count >= 5) throw new ClubError(409, "ATTACHMENT_LIMIT", "A notice can have at most five attachments");
			}
			return run(client);
		});
	}
	return transaction(env.HYPERDRIVE.connectionString, async (client) => {
		if (target.purpose === "feed") {
			const post = await client.query("SELECT user_id FROM feed_posts WHERE id = $1 AND deleted_at IS NULL FOR UPDATE", [target.postId]);
			if (!post.rows[0]) missing("Post");
			if (post.rows[0].user_id !== userId) throw new ClubError(403, "POST_AUTHOR_REQUIRED", "Only the author can upload post images");
			const count = await client.query<{ count: number }>("SELECT count(*)::int AS count FROM media_images WHERE post_id = $1 AND deleted_at IS NULL", [target.postId]);
			if (count.rows[0].count >= 5) throw new ClubError(409, "IMAGE_LIMIT", "A post can have at most five images");
		} else {
			await client.query("SELECT id FROM runline_users WHERE id = $1 FOR UPDATE", [userId]);
		}
		return run(client);
	});
}

export async function uploadImage(env: WorkerBindings, userId: string, target: ImageTarget, file: File) {
	// Authorize before spending CPU/storage, then recheck under lock before committing.
	await forUpload(env, userId, target, async () => undefined);
	const optimized = await optimizeImage(env, file, target.purpose);
	const imageId = crypto.randomUUID();
	const key = `images/${imageId}/full.webp`;
	const thumbnailKey = `images/${imageId}/thumbnail.webp`;
	try {
		await env.MEDIA_BUCKET.put(key, optimized.full, { httpMetadata: { contentType: "image/webp" } });
		await env.MEDIA_BUCKET.put(thumbnailKey, optimized.thumbnail, { httpMetadata: { contentType: "image/webp" } });
		return await forUpload(env, userId, target, async (client) => {
			if (target.purpose === "avatar") {
				await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE uploader_user_id = $1 AND purpose = 'avatar' AND deleted_at IS NULL", [userId]);
			}
			if (target.purpose === "club_cover") {
				await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE club_id = $1 AND purpose = 'club_cover' AND deleted_at IS NULL", [target.clubId]);
			}
			const { rows } = await client.query<ImageRow>(`INSERT INTO media_images
				(id, uploader_user_id, purpose, club_id, notice_id, post_id, object_key, thumbnail_key, width, height, size, thumbnail_size)
				VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
				[imageId, userId, target.purpose, target.clubId ?? null, target.noticeId ?? null, target.postId ?? null, key, thumbnailKey,
					optimized.width, optimized.height, optimized.full.length, optimized.thumbnail.length]);
			const image = imageResponse(rows[0]);
			if (target.purpose === "avatar") await client.query(`INSERT INTO runline_user_profiles (user_id, nickname, avatar_url)
				SELECT id, '러너 ' || left(id::text, 8), $2 FROM runline_users WHERE id = $1
				ON CONFLICT (user_id) DO UPDATE SET avatar_url = EXCLUDED.avatar_url`, [userId, image.url]);
			if (target.purpose === "club_cover") await client.query("UPDATE clubs SET image_url = $2, updated_at = clock_timestamp() WHERE id = $1", [target.clubId, image.url]);
			let attachment;
			if (target.purpose === "club_notice") {
				const result = await client.query(`INSERT INTO club_attachments (club_id, notice_id, filename, content_type, image_id)
					VALUES ($1,$2,'image.webp','image/webp',$3) RETURNING id, filename, content_type, created_at`, [target.clubId, target.noticeId, imageId]);
				attachment = { ...result.rows[0], size: image.size, image };
			}
			return { image, ...(attachment ? { attachment } : {}) };
		});
	} catch (error) {
		await env.MEDIA_BUCKET.delete([key, thumbnailKey]).catch(() => undefined);
		throw error;
	}
}

export async function getImage(env: WorkerBindings, userId: string, imageId: string, variant: string) {
	if (variant !== "full" && variant !== "thumbnail") throw new ClubError(400, "INVALID_REQUEST", "Unknown image variant");
	const image = await transaction(env.HYPERDRIVE.connectionString, async (client) => {
		const { rows } = await client.query<ImageRow>("SELECT * FROM media_images WHERE id = $1 AND deleted_at IS NULL", [imageId]);
		const row = rows[0] ?? missing("Image");
		if (row.club_id) {
			const result = await client.query(`SELECT c.id FROM clubs c WHERE c.id = $1 AND c.status = 'active'
				AND ($2::boolean OR EXISTS (SELECT 1 FROM club_memberships m WHERE m.club_id = c.id AND m.user_id = $3 AND m.status = 'active'))`,
				[row.club_id, row.purpose === "club_cover", userId]);
			if (!result.rows[0]) throw new ClubError(403, "CLUB_MEMBERSHIP_REQUIRED", "Current club membership is required");
		}
		if (row.notice_id) {
			const result = await client.query("SELECT id FROM club_notices WHERE id = $1 AND deleted_at IS NULL", [row.notice_id]);
			if (!result.rows[0]) missing("Image");
		}
		if (row.post_id) {
			const result = await client.query("SELECT id FROM feed_posts WHERE id = $1 AND deleted_at IS NULL", [row.post_id]);
			if (!result.rows[0]) missing("Image");
		}
		return row;
	});
	const stored = await env.MEDIA_BUCKET.get(variant === "thumbnail" ? image.thumbnail_key : image.object_key);
	if (!stored) missing("Image");
	return new Response(stored.body, { headers: {
		"Content-Type": "image/webp", "Content-Length": String(stored.size), "Cache-Control": "private, no-store",
		"X-Content-Type-Options": "nosniff", "Content-Disposition": "inline; filename=\"image.webp\"",
	} });
}

export async function removeImage(env: WorkerBindings, userId: string, imageId: string) {
	const image = await transaction(env.HYPERDRIVE.connectionString, async (client) => {
		const { rows } = await client.query<ImageRow>("SELECT * FROM media_images WHERE id = $1 AND deleted_at IS NULL", [imageId]);
		return rows[0] ?? missing("Image");
	});
	const target = { purpose: image.purpose, clubId: image.club_id ?? undefined, noticeId: image.notice_id ?? undefined, postId: image.post_id ?? undefined };
	// Existing image deletion must not be rejected simply because the post is full.
	if (image.purpose === "club_notice" || image.purpose === "club_cover") {
		await inClub(env.HYPERDRIVE.connectionString, userId, image.club_id!, true, async ({ client, membership }) => {
			requireOwner(membership);
			await markDeleted(client, image);
		});
	} else {
		await transaction(env.HYPERDRIVE.connectionString, async (client) => {
			if (image.uploader_user_id !== userId) throw new ClubError(403, "IMAGE_OWNER_REQUIRED", "Only the image owner can remove it");
			if (target.postId) await client.query("SELECT id FROM feed_posts WHERE id = $1 FOR UPDATE", [target.postId]);
			else await client.query("SELECT id FROM runline_users WHERE id = $1 FOR UPDATE", [userId]);
			await markDeleted(client, image);
		});
	}
}

async function markDeleted(client: Client, image: ImageRow) {
	await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE id = $1 AND deleted_at IS NULL", [image.id]);
	await client.query("DELETE FROM club_attachments WHERE image_id = $1", [image.id]);
	const url = `/api/v1/media/images/${image.id}`;
	if (image.purpose === "avatar") await client.query("UPDATE runline_user_profiles SET avatar_url = NULL WHERE user_id = $1 AND avatar_url = $2", [image.uploader_user_id, url]);
	if (image.purpose === "club_cover") await client.query("UPDATE clubs SET image_url = NULL WHERE id = $1 AND image_url = $2", [image.club_id, url]);
}

export async function cleanupImages(env: WorkerBindings) {
	return transaction(env.HYPERDRIVE.connectionString, async (client) => {
		const { rows } = await client.query<ImageRow>("SELECT * FROM media_images WHERE deleted_at IS NOT NULL ORDER BY deleted_at LIMIT 100 FOR UPDATE SKIP LOCKED");
		for (const row of rows) {
			await env.MEDIA_BUCKET.delete([row.object_key, row.thumbnail_key]);
			await client.query("DELETE FROM media_images WHERE id = $1", [row.id]);
		}
		return rows.length;
	});
}
