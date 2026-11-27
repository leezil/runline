import type { Context } from "hono";
import { withDatabase } from "../../../database/client";
import { inTransaction } from "../../../database/transaction";
import { HttpError } from "../../../http/http-error";
import type { AuthEnv } from "../../auth/require-auth";
import { imageContentType } from "./image-content-type";

export const maxImageBytes = 5 * 1024 * 1024;

async function readImage(c: Context<AuthEnv>): Promise<File> {
	if (!/^multipart\/form-data(?:\s*;|$)/i.test(c.req.header("Content-Type") ?? "")) {
		throw new HttpError(400, "INVALID_MEDIA_UPLOAD", "Use multipart/form-data with one file field");
	}
	let form: FormData;
	try {
		form = await c.req.formData();
	} catch {
		throw new HttpError(400, "INVALID_MEDIA_UPLOAD", "Could not read the uploaded image");
	}
	const files = form.getAll("file");
	const file = files[0];
	if (files.length !== 1 || !(file instanceof File) || file.size === 0) {
		throw new HttpError(400, "INVALID_MEDIA_UPLOAD", "Upload one non-empty image in the file field");
	}
	if (file.size > maxImageBytes) {
		throw new HttpError(413, "MEDIA_TOO_LARGE", "Images must be 5 MiB or smaller");
	}
	return file;
}

export async function uploadMedia(c: Context<AuthEnv>): Promise<Response> {
	if (!c.env.FEED_MEDIA_SIGNING_SECRET) {
		throw new HttpError(503, "MEDIA_UNAVAILABLE", "Feed media is not configured");
	}
	const file = await readImage(c);
	const contentType = await imageContentType(file);
	if (!contentType || (file.type && file.type !== "application/octet-stream" && file.type !== contentType)) {
		throw new HttpError(415, "INVALID_MEDIA_TYPE", "Use a JPEG, PNG, or WebP image");
	}
	const id = crypto.randomUUID();
	const objectKey = `feed/${id}`;
	const ownerId = c.get("userId");
	await withDatabase(c.env.HYPERDRIVE.connectionString, async (db) => {
		// Commit the reservation before writing to R2 so cleanup can recover an interrupted upload.
		await db.query(
			`INSERT INTO runline_post_media (id, owner_id, object_key, content_type, byte_size)
			 VALUES ($1, $2, $3, $4, $5)`,
			[id, ownerId, objectKey, contentType, file.size],
		);
		await inTransaction(db, async () => {
			const reserved = await db.query(
				`SELECT id FROM runline_post_media WHERE id = $1 FOR UPDATE`,
				[id],
			);
			if (!reserved.rowCount) {
				throw new HttpError(409, "MEDIA_UPLOAD_EXPIRED", "Upload reservation expired. Upload the image again");
			}
			await c.env.FEED_MEDIA.put(objectKey, file, { httpMetadata: { contentType } });
			await db.query("UPDATE runline_post_media SET uploaded_at = now() WHERE id = $1", [id]);
		});
	});
	return c.json({ ok: true, media: { id } }, 201);
}
