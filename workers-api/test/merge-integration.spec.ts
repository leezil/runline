import { env } from "cloudflare:test";
import { beforeEach, expect, it, vi } from "vitest";
import worker from "../src/index";

const cleanup = vi.hoisted(() => ({ feed: vi.fn(), club: vi.fn() }));
vi.mock("../src/features/feed/media/media-cleanup", () => ({ cleanUpMedia: cleanup.feed }));
vi.mock("../src/features/media/image-service", async (original) => ({
	...await original<typeof import("../src/features/media/image-service")>(),
	cleanupImages: cleanup.club,
}));

beforeEach(() => vi.clearAllMocks());

it.each([
	["15 * * * *", "feed"],
	["17 3 * * *", "club"],
] as const)("retains the %s media cleanup schedule", async (cron, target) => {
	await worker.scheduled({ cron } as ScheduledController, env);
	expect(cleanup[target]).toHaveBeenCalledExactlyOnceWith(env);
	expect(cleanup[target === "feed" ? "club" : "feed"]).not.toHaveBeenCalled();
});
