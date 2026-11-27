import { randomUUID } from "node:crypto";
import { readFile, readdir } from "node:fs/promises";
import { URL as NodeURL } from "node:url";
import { Client } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createClub, joinClub } from "../../src/features/clubs/club-service";
import { createRun, joinRun } from "../../src/features/clubs/run-service";
import { clubInput, runInput } from "../../src/features/clubs/validation";

// Opt-in only: use a disposable PostgreSQL database. All tables live in a unique
// generated schema, and connections use its search_path. Never use production.
describe.skipIf(!process.env.CLUB_TEST_DATABASE_URL)("PostgreSQL multi-connection concurrency", () => {
	const schema = `club_test_${randomUUID().replaceAll("-", "")}`;
	let admin: Client;
	let connection: string;
	let users: string[];
	beforeAll(async () => {
		const original = process.env.CLUB_TEST_DATABASE_URL!;
		admin = new Client({ connectionString: original });
		await admin.connect();
		await admin.query(`CREATE SCHEMA ${schema}`);
		await admin.query(`SET search_path TO ${schema}, public`);
		for (const name of (await readdir(new NodeURL("../../migrations/", import.meta.url))).filter((name) => name.endsWith(".sql")).sort()) {
			await admin.query(await readFile(new NodeURL(`../../migrations/${name}`, import.meta.url), "utf8"));
		}
		const url = new NodeURL(original);
		url.searchParams.set("options", `-c search_path=${schema},public -c statement_timeout=10000`);
		connection = url.toString();
	});
	beforeEach(async () => {
		await admin.query("TRUNCATE runline_users, clubs CASCADE");
		users = [];
		for (let i = 1; i <= 4; i++) {
			const { rows } = await admin.query("INSERT INTO runline_users (kakao_user_id) VALUES ($1) RETURNING id", [i]);
			users.push(rows[0].id);
		}
	});
	afterAll(async () => {
		if (admin) {
			await admin.query(`DROP SCHEMA IF EXISTS ${schema} CASCADE`);
			await admin.end();
		}
	});

	it("permits only one of two simultaneous club joins", async () => {
		const first = await createClub(connection, users[0], clubInput({ name: "첫 클럽", region: "서울" }));
		const second = await createClub(connection, users[1], clubInput({ name: "두 번째", region: "부산" }));
		const results = await Promise.allSettled([
			joinClub(connection, users[2], first.club.id), joinClub(connection, users[2], second.club.id),
		]);
		expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
		expect(results.find((result) => result.status === "rejected")).toMatchObject({ reason: { code: "ALREADY_IN_CLUB" } });
		const { rows } = await admin.query("SELECT * FROM club_memberships WHERE user_id = $1 AND status = 'active'", [users[2]]);
		expect(rows).toHaveLength(1);
	});

	it("allows either joining or creation, with no orphaned club on failure", async () => {
		const existing = await createClub(connection, users[0], clubInput({ name: "기존 클럽", region: "서울" }));
		const results = await Promise.allSettled([
			joinClub(connection, users[1], existing.club.id),
			createClub(connection, users[1], clubInput({ name: "새 클럽", region: "서울" })),
		]);
		expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
		const { rows } = await admin.query(`SELECT c.id FROM clubs c WHERE c.status = 'active'
			AND NOT EXISTS (SELECT 1 FROM club_memberships m WHERE m.club_id = c.id AND m.status = 'active' AND m.role = 'owner')`);
		expect(rows).toHaveLength(0);
	});

	it("admits only one participant competing for the last spot", async () => {
		const { club } = await createClub(connection, users[0], clubInput({ name: "정원 테스트", region: "서울" }));
		await joinClub(connection, users[1], club.id);
		await joinClub(connection, users[2], club.id);
		const run = await createRun(connection, users[0], club.id, runInput({
			title: "2명 러닝", location: "공원", capacity: 2,
			startsAt: new Date(Date.now() + 86400000).toISOString(),
			endsAt: new Date(Date.now() + 90000000).toISOString(),
			registrationClosesAt: new Date(Date.now() + 82800000).toISOString(),
		}));
		const results = await Promise.allSettled([
			joinRun(connection, users[1], club.id, run.id), joinRun(connection, users[2], club.id, run.id),
		]);
		expect(results.filter((result) => result.status === "fulfilled")).toHaveLength(1);
		expect(results.find((result) => result.status === "rejected")).toMatchObject({ reason: { code: "RUN_NOT_RECRUITING" } });
		const { rows } = await admin.query("SELECT count(*)::int AS count FROM club_run_participants WHERE run_id = $1 AND status = 'joined'", [run.id]);
		expect(rows[0].count).toBe(2);
	});
});
