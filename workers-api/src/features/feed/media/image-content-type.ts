const jpegHeader = [0xff, 0xd8, 0xff];
const pngHeader = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
const riffHeader = [0x52, 0x49, 0x46, 0x46];
const webpHeader = [0x57, 0x45, 0x42, 0x50];

function matches(bytes: Uint8Array, header: number[], offset = 0): boolean {
	return header.every((value, index) => bytes[offset + index] === value);
}

export async function imageContentType(file: File): Promise<string | null> {
	const header = new Uint8Array(await file.slice(0, 12).arrayBuffer());
	if (matches(header, jpegHeader)) return "image/jpeg";
	if (matches(header, pngHeader)) return "image/png";
	if (matches(header, riffHeader) && matches(header, webpHeader, 8)) return "image/webp";
	return null;
}
