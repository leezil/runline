import { defineConfig } from "vitest/config";

export default defineConfig({
	test: {
		environment: "node",
		include: ["test/clubs/**/*.spec.ts"],
		hookTimeout: 30000,
		testTimeout: 15000,
	},
});
