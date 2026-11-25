import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { HttpError } from "../../../http/http-error";
import type { AuthEnv } from "../../auth/require-auth";
import { downloadMedia } from "./download-media";
import { maxImageBytes, uploadMedia } from "./upload-media";

const mediaRoutes = new Hono<AuthEnv>();

mediaRoutes.post("/media", bodyLimit({
	maxSize: maxImageBytes + 16 * 1024, // Space for multipart boundaries and headers.
	onError: () => {
		throw new HttpError(413, "MEDIA_TOO_LARGE", "Images must be 5 MiB or smaller");
	},
}), uploadMedia);
mediaRoutes.get("/media/:mediaId", downloadMedia);

export default mediaRoutes;
