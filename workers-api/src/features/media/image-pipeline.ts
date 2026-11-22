import type { WorkerBindings } from "../../types";
import { ClubError } from "../clubs/errors";

export type ImagePurpose = "avatar" | "club_cover" | "club_notice" | "feed";
export const maxImageInputBytes = 5 * 1024 * 1024;
const allowed = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);
const stream = (bytes: Uint8Array) => new Blob([new Uint8Array(bytes)]).stream();

export function imageSignature(bytes: Uint8Array): string | undefined {
	if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
	if ([137, 80, 78, 71, 13, 10, 26, 10].every((value, i) => bytes[i] === value)) return "image/png";
	const prefix = new TextDecoder("ascii").decode(bytes.subarray(0, 12));
	if (prefix.startsWith("GIF87a") || prefix.startsWith("GIF89a")) return "image/gif";
	if (prefix.startsWith("RIFF") && prefix.slice(8) === "WEBP") return "image/webp";
	return undefined;
}

export async function optimizeImage(env: WorkerBindings, file: File, purpose: ImagePurpose) {
	if (file.size < 1 || file.size > maxImageInputBytes) throw new ClubError(413, "IMAGE_TOO_LARGE", "Images must contain 1 byte to 5 MiB");
	const bytes = new Uint8Array(await file.arrayBuffer());
	const signature = imageSignature(bytes);
	if (!signature || !allowed.has(file.type) || signature !== file.type) {
		throw new ClubError(400, "INVALID_IMAGE", "Image bytes and MIME type must match JPEG, PNG, WebP or GIF");
	}
	if (!env.IMAGES || !env.MEDIA_BUCKET) throw new ClubError(503, "IMAGE_SERVICE_UNAVAILABLE", "Image processing and storage are not configured");
	let info: ImageInfoResponse;
	try { info = await env.IMAGES.info(stream(bytes)); }
	catch { throw new ClubError(400, "INVALID_IMAGE", "The image cannot be decoded"); }
	if (!("width" in info) || !Number.isInteger(info.width) || !Number.isInteger(info.height)
		|| info.width < 1 || info.height < 1 || info.width > 12000 || info.height > 12000 || info.width * info.height > 40000000) {
		throw new ClubError(400, "IMAGE_DIMENSIONS_EXCEEDED", "Image dimensions exceed the 40 megapixel limit");
	}
	const edge = purpose === "avatar" || purpose === "club_cover" ? 512 : 1600;
	async function encode(source: Uint8Array, maxEdge: number, quality: number) {
		// Images applies EXIF orientation when decoding; WebP is then explicitly
		// stripped of EXIF/XMP chunks below, including GPS and copyright metadata.
		try {
			const dimensions = await env.IMAGES.info(stream(source));
			if (!("width" in dimensions)) throw new Error("Not a raster image");
			const scale = Math.min(1, maxEdge / dimensions.width, maxEdge / dimensions.height);
			const result = await env.IMAGES.input(stream(source))
				.transform({ width: Math.max(1, Math.round(dimensions.width * scale)), height: Math.max(1, Math.round(dimensions.height * scale)), fit: "scale-down" })
				.output({ format: "image/webp", quality, anim: false });
			const response = result.response();
			if (!response.ok) throw new Error("Transform failed");
			return stripWebpMetadata(new Uint8Array(await response.arrayBuffer()));
		} catch { throw new ClubError(400, "INVALID_IMAGE", "The image cannot be normalized"); }
	}
	let full = await encode(bytes, edge, 80);
	if (full.length > 700 * 1024) full = await encode(bytes, edge, 65);
	if (full.length > 1024 * 1024) full = await encode(bytes, Math.min(edge, 1280), 55);
	if (full.length > 1024 * 1024) throw new ClubError(413, "IMAGE_TOO_LARGE", "The optimized image exceeds 1 MiB");
	const thumbnail = await encode(full, 400, 70);
	if (thumbnail.length > 256 * 1024) throw new ClubError(413, "IMAGE_TOO_LARGE", "The thumbnail exceeds 256 KiB");
	const normalized = await env.IMAGES.info(stream(full));
	if (!("width" in normalized) || normalized.width < 1 || normalized.height < 1 || normalized.width > edge || normalized.height > edge) {
		throw new ClubError(400, "INVALID_IMAGE", "The normalized image has invalid dimensions");
	}
	return { full, thumbnail, width: normalized.width, height: normalized.height };
}

// Rebuild the WebP container without metadata chunks. Preserve ICC colour profiles,
// alpha, frame and pixel chunks. Clear the corresponding extended-header flags.
export function stripWebpMetadata(input: Uint8Array): Uint8Array {
	if (imageSignature(input) !== "image/webp" || input.length < 20) throw new Error("Invalid WebP");
	const chunks: Uint8Array[] = [];
	const view = new DataView(input.buffer, input.byteOffset, input.byteLength);
	if (view.getUint32(4, true) + 8 !== input.length) throw new Error("Invalid WebP size");
	let offset = 12;
	while (offset < input.length) {
		if (offset + 8 > input.length) throw new Error("Truncated WebP");
		const type = new TextDecoder("ascii").decode(input.subarray(offset, offset + 4));
		const size = view.getUint32(offset + 4, true);
		const end = offset + 8 + size + (size % 2);
		if (end > input.length) throw new Error("Truncated WebP chunk");
		if (type !== "EXIF" && type !== "XMP ") {
			const chunk = input.slice(offset, end);
			if (type === "VP8X" && size >= 10) chunk[8] &= ~(0x08 | 0x04);
			chunks.push(chunk);
		}
		offset = end;
	}
	const output = new Uint8Array(12 + chunks.reduce((size, chunk) => size + chunk.length, 0));
	output.set(input.subarray(0, 12));
	new DataView(output.buffer).setUint32(4, output.length - 8, true);
	offset = 12;
	for (const chunk of chunks) { output.set(chunk, offset); offset += chunk.length; }
	return output;
}
