import { Hono } from "hono";
import type { AuthEnv } from "../../auth/require-auth";
import { followingFeed } from "./following-feed";
import { recommendedFeed } from "./recommended-feed";

const timelineRoutes = new Hono<AuthEnv>();
timelineRoutes.get("/recommended", recommendedFeed);
timelineRoutes.get("/following", followingFeed);

export default timelineRoutes;
