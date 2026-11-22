import { Buffer } from "node:buffer";
import type { Client } from "pg";
import { ClubError, invalid, missing } from "./errors";
import { addEvent, inClub, requireOwner, seek, updateRow } from "./repository";
import { pageResult, text, type Page, type noticeInput } from "./validation";

type Notice = {
	id: string; club_id: string; title: string; content: string; pinned: boolean;
	created_at: Date; updated_at: Date;
};

async function findNotice(client: Client, clubId: string, noticeId: string) {
	const { rows } = await client.query<Notice>(
		`SELECT n.*, u.id AS author_user_id, u.nickname AS author_nickname, u.avatar_url AS author_avatar_url
		FROM club_notices n JOIN club_memberships m ON m.id = n.author_membership_id
		JOIN runline_users u ON u.id = m.user_id
		WHERE n.id = $1 AND n.club_id = $2 AND n.deleted_at IS NULL`, [noticeId, clubId],
	);
	return rows[0] ?? missing("Notice");
}

export function listNotices(connection: string, userId: string, clubId: string, page: Page) {
	return inClub(connection, userId, clubId, false, async ({ client }) => {
		const params: unknown[] = [clubId];
		const where = seek(page, params, "n.created_at", "n.id", "n.pinned");
		params.push(page.limit + 1);
		const { rows } = await client.query<Notice>(
			`SELECT n.id, n.club_id, n.title, n.pinned, n.created_at, n.updated_at, u.nickname AS author_nickname,
			(SELECT count(*)::int FROM club_attachments a WHERE a.notice_id = n.id) AS attachment_count
			FROM club_notices n JOIN club_memberships m ON m.id = n.author_membership_id
			JOIN runline_users u ON u.id = m.user_id
			WHERE n.club_id = $1 AND n.deleted_at IS NULL ${where}
			ORDER BY n.pinned DESC, n.created_at DESC, n.id DESC LIMIT $${params.length}`, params,
		);
		return pageResult(rows, page, `notices:${clubId}`, "created_at", true);
	});
}

export function getNotice(connection: string, userId: string, clubId: string, noticeId: string) {
	return inClub(connection, userId, clubId, false, async ({ client }) => {
		const notice = await findNotice(client, clubId, noticeId);
		const { rows: attachments } = await client.query(
			`SELECT a.id, a.filename, a.content_type, COALESCE(i.size, octet_length(a.data)) AS size, a.created_at,
			a.image_id, CASE WHEN i.id IS NOT NULL THEN '/api/v1/media/images/' || i.id::text END AS image_url,
			CASE WHEN i.id IS NOT NULL THEN '/api/v1/media/images/' || i.id::text || '?variant=thumbnail' END AS thumbnail_url
			FROM club_attachments a LEFT JOIN media_images i ON i.id = a.image_id
			WHERE a.notice_id = $1 AND a.club_id = $2 ORDER BY a.created_at, a.id`, [noticeId, clubId],
		);
		return { ...notice, attachments };
	});
}

export function createNotice(connection: string, userId: string, clubId: string, fields: ReturnType<typeof noticeInput>) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		const { rows } = await client.query<Notice>(
			"INSERT INTO club_notices (club_id, author_membership_id, title, content, pinned) VALUES ($1, $2, $3, $4, $5) RETURNING *",
			[clubId, membership.id, fields.title, fields.content, fields.pinned],
		);
		await addEvent(client, clubId, "notice_created", rows[0].id, rows[0].title);
		return rows[0];
	});
}

export function editNotice(connection: string, userId: string, clubId: string, noticeId: string, fields: ReturnType<typeof noticeInput>) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		await findNotice(client, clubId, noticeId);
		return updateRow<Notice>(client, "club_notices", noticeId, fields);
	});
}

export function deleteNotice(connection: string, userId: string, clubId: string, noticeId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		await findNotice(client, clubId, noticeId);
		await client.query("UPDATE club_notices SET deleted_at = clock_timestamp(), updated_at = clock_timestamp() WHERE id = $1", [noticeId]);
		await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE notice_id = $1 AND deleted_at IS NULL", [noticeId]);
		await client.query("DELETE FROM club_attachments WHERE notice_id = $1", [noticeId]);
	});
}

const attachmentTypes = new Set([
	"application/pdf", "text/plain",
	"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
	"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
]);

export async function attachmentInput(file: File) {
	if (file.size < 1 || file.size > 5 * 1024 * 1024) {
		throw new ClubError(413, "ATTACHMENT_TOO_LARGE", "Files must contain 1 byte to 5 MiB");
	}
	if (!attachmentTypes.has(file.type)) invalid("Unsupported attachment type");
	const filename = text(file.name, "filename", 200).replace(/[\x00-\x1f\x7f/\\]/g, "_");
	return { filename, contentType: file.type, data: Buffer.from(await file.arrayBuffer()) };
}

export function uploadAttachment(connection: string, userId: string, clubId: string, noticeId: string, file: Awaited<ReturnType<typeof attachmentInput>>) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		await findNotice(client, clubId, noticeId);
		const { rows: counts } = await client.query<{ count: number }>("SELECT count(*)::int AS count FROM club_attachments WHERE notice_id = $1", [noticeId]);
		if (counts[0].count >= 5) throw new ClubError(409, "ATTACHMENT_LIMIT", "A notice can have at most five attachments");
		const { rows } = await client.query(
			`INSERT INTO club_attachments (club_id, notice_id, filename, content_type, data) VALUES ($1, $2, $3, $4, $5)
			RETURNING id, filename, content_type, octet_length(data) AS size, created_at`,
			[clubId, noticeId, file.filename, file.contentType, file.data],
		);
		return rows[0];
	});
}

export function downloadAttachment(connection: string, userId: string, clubId: string, noticeId: string, attachmentId: string) {
	return inClub(connection, userId, clubId, false, async ({ client }) => {
		await findNotice(client, clubId, noticeId);
		const { rows } = await client.query<{ filename: string; content_type: string; data: Buffer; image_id: string | null }>(
			"SELECT filename, content_type, data, image_id FROM club_attachments WHERE id = $1 AND club_id = $2 AND notice_id = $3", [attachmentId, clubId, noticeId],
		);
		return rows[0] ?? missing("Attachment");
	});
}

export function deleteAttachment(connection: string, userId: string, clubId: string, noticeId: string, attachmentId: string) {
	return inClub(connection, userId, clubId, true, async ({ client, membership }) => {
		requireOwner(membership);
		await findNotice(client, clubId, noticeId);
		const { rows } = await client.query("DELETE FROM club_attachments WHERE id = $1 AND club_id = $2 AND notice_id = $3 RETURNING id, image_id", [attachmentId, clubId, noticeId]);
		if (!rows[0]) missing("Attachment");
		if (rows[0].image_id) await client.query("UPDATE media_images SET deleted_at = clock_timestamp() WHERE id = $1", [rows[0].image_id]);
	});
}
