import { Hono, type Context } from "hono";
import { bodyLimit } from "hono/body-limit";
import { requireAuth, type AuthEnv } from "../auth/require-auth";
import { invalid } from "../clubs/errors";
import { uuid } from "../clubs/validation";
import { getImage, removeImage, uploadImage, type ImageTarget } from "./image-service";

const imageRoutes = new Hono<AuthEnv>();
const uploadLimit = bodyLimit({ maxSize: 5 * 1024 * 1024 + 8192,
	onError: (c) => c.json({ ok: false, error: { code: "PAYLOAD_TOO_LARGE", message: "Upload exceeds 5 MiB" } }, 413),
});

export async function readImageFile(c: Context<AuthEnv>): Promise<File> {
	const form = await c.req.formData().catch(() => invalid("multipart/form-data is required"));
	const files = form.getAll("file");
	if (files.length !== 1 || !(files[0] instanceof File)) invalid("Exactly one file is required");
	return files[0];
}

for (const [path, target] of [
	["/me/avatar", () => ({ purpose: "avatar" })],
	["/clubs/:clubId/image", (c: Context<AuthEnv>) => ({ purpose: "club_cover", clubId: uuid(c.req.param("clubId") ?? "") })],
	["/feed/posts/:postId/images", (c: Context<AuthEnv>) => ({ purpose: "feed", postId: uuid(c.req.param("postId") ?? "") })],
] as [string, (c: Context<AuthEnv>) => ImageTarget][]) {
	imageRoutes.post(path, requireAuth, uploadLimit, async (c) => c.json({ ok: true, ...await uploadImage(c.env, c.get("userId"), target(c), await readImageFile(c)) }, 201));
}
imageRoutes.get("/media/images/:imageId", requireAuth, async (c) => getImage(c.env, c.get("userId"), uuid(c.req.param("imageId")), c.req.query("variant") ?? "full"));
imageRoutes.delete("/media/images/:imageId", requireAuth, async (c) => {
	await removeImage(c.env, c.get("userId"), uuid(c.req.param("imageId")));
	return c.body(null, 204);
});
export default imageRoutes;
