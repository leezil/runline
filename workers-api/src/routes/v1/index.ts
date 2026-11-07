import { Hono } from "hono";
import authRoutes from "../../features/auth/auth-routes";
import { requireAuth, type AuthEnv } from "../../features/auth/require-auth";
import healthRoutes from "./health";

const v1Routes = new Hono<AuthEnv>();

v1Routes.route("/health", healthRoutes);
v1Routes.route("/auth", authRoutes);
v1Routes.on("POST", ["/feed/posts", "/crews/:crewId/join"], requireAuth);

export default v1Routes;
