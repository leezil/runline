import { Hono } from "hono";
import type { WorkerBindings } from "../../types";
import healthRoutes from "./health";

const v1Routes = new Hono<{ Bindings: WorkerBindings }>();

v1Routes.route("/health", healthRoutes);

export default v1Routes;
