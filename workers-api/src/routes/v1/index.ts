import { Hono } from "hono";
import authRoutes from "../../features/auth/auth-routes";
import { requireAuth, type AuthEnv } from "../../features/auth/require-auth";
import healthRoutes from "./health";
import clubRoutes, { meRoutes } from "../../features/clubs/club-routes";
import imageRoutes from "../../features/media/image-routes";
import feedRoutes from "../../features/media/feed-routes";

const v1Routes = new Hono<AuthEnv>();
v1Routes.route("/", imageRoutes);
v1Routes.route("/feed", feedRoutes);

v1Routes.route("/health", healthRoutes);
v1Routes.route("/auth", authRoutes);
v1Routes.route("/me", meRoutes);
v1Routes.route("/clubs", clubRoutes);
v1Routes.on("POST", ["/feed/posts", "/crews/:crewId/join"], requireAuth);

export default v1Routes;
