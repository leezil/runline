import { Hono } from "hono";
import authRoutes from "../../features/auth/auth-routes";
import { requireAuth, type AuthEnv } from "../../features/auth/require-auth";
import mediaRoutes from "../../features/feed/media/media-routes";
import postRoutes from "../../features/feed/posts/post-routes";
import { myPosts } from "../../features/feed/timeline/my-posts";
import timelineRoutes from "../../features/feed/timeline/timeline-routes";
import followRoutes from "../../features/follow/follow-routes";
import profileRoutes from "../../features/profile/profile-routes";
import runs from "../../features/runs";
import healthRoutes from "./health";
import clubRoutes, { meRoutes } from "../../features/clubs/club-routes";
import imageRoutes from "../../features/media/image-routes";
import chatRoutes from "../../features/chat/chat-routes";

const v1Routes = new Hono<AuthEnv>();

v1Routes.route("/", chatRoutes);
v1Routes.route("/", imageRoutes);
v1Routes.route("/me", meRoutes);
v1Routes.route("/clubs", clubRoutes);

v1Routes.route("/health", healthRoutes);
v1Routes.route("/auth", authRoutes);
v1Routes.on("POST", "/crews/:crewId/join", requireAuth);

v1Routes.use("/feed/*", requireAuth);
v1Routes.use("/me/*", requireAuth);
v1Routes.use("/users/*", requireAuth);
v1Routes.route("/feed", postRoutes);
v1Routes.route("/feed", mediaRoutes);
v1Routes.route("/feed", timelineRoutes);
v1Routes.route("/me/runs", runs);
v1Routes.get("/me/posts", myPosts);
v1Routes.route("/", profileRoutes);
v1Routes.route("/", followRoutes);

export default v1Routes;
