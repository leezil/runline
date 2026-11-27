import { randomUUID } from "node:crypto";
import { cp, mkdtemp, readFile, readdir, realpath, rm, writeFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { createServer } from "node:net";
import { URL as NodeURL } from "node:url";
import EmbeddedPostgres from "embedded-postgres";
import { Client } from "pg";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { issueTokens } from "../../src/features/auth/tokens";
import { createClub, joinClub, leaveClub, kickMember, closeClub } from "../../src/features/clubs/club-service";
import { clubInput } from "../../src/features/clubs/validation";
import { authenticateChat, dispatchAuthorized, getChatState, history, markRead, saveMessage, type ChatIdentity } from "../../src/features/chat/chat-service";
import { endSession, refreshSession } from "../../src/features/auth/session-service";
import { app as worker } from "../../src/index";
import type { WorkerBindings } from "../../src/types";

type Account = { id: string; access: string; refresh: string; hash: string };
let postgres: EmbeddedPostgres;
let stopPostgres: (() => Promise<unknown>) | undefined;
let admin: Client;
let connection: string;
let directory: string;
let owner: Account;
let member: Account;
let other: Account;
let late: Account;
let clubId: string;
let ownerIdentity: ChatIdentity;
let memberIdentity: ChatIdentity;
let env: WorkerBindings;

async function account(number: number): Promise<Account> {
	const { rows } = await admin.query("INSERT INTO runline_users (kakao_user_id, nickname) VALUES ($1, $2) RETURNING id", [number, `러너${number}`]);
	await admin.query("INSERT INTO runline_user_profiles (user_id, nickname) VALUES ($1, $2)", [rows[0].id, `러너${number}`]);
	const tokens = await issueTokens();
	await admin.query(`INSERT INTO runline_sessions (user_id, access_token_hash, refresh_token_hash, access_expires_at, refresh_expires_at)
		VALUES ($1,$2,$3,clock_timestamp() + interval '15 minutes',clock_timestamp() + interval '1 day')`, [rows[0].id, tokens.hashes.accessHash, tokens.hashes.refreshHash]);
	return { id: rows[0].id, access: tokens.accessToken, refresh: tokens.refreshToken, hash: tokens.hashes.accessHash };
}
async function identity(user: Account) {
	let value!: ChatIdentity;
	await authenticateChat(connection, clubId, user.hash, (current) => { value = current; });
	return value;
}
const send = (who: ChatIdentity, content: string, clientMessageId: string = randomUUID()) => saveMessage(connection, clubId, who, { type: "send", content, clientMessageId });
function request(user: Account, path: string, method = "GET", body?: unknown) {
	return worker.request(`https://example.com/api/v1${path}`, { method, headers: { Authorization: `Bearer ${user.access}`, "Content-Type": "application/json" },
		...(body === undefined ? {} : { body: JSON.stringify(body) }) }, env);
}

beforeAll(async () => {
	// No Neon credentials are read. This database only listens on loopback and
	// lives in a generated temporary directory, removed after stopping PostgreSQL.
	const server = createServer();
	await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
	const port = (server.address() as { port: number }).port;
	await new Promise<void>((resolve) => server.close(() => resolve()));
	directory = await mkdtemp(join(tmpdir(), "runline-chat-pg-"));
	const password = randomUUID();
	if (process.platform === "win32") {
		// PostgreSQL bootstrap on Windows embeds binary paths using the system
		// codepage. Use a temporary ASCII binary path for Korean workspace names.
		const nativePackage = "@embedded-postgres/windows-x64";
		const native = await import(nativePackage);
		const binaries = join(directory, "bin-dist");
		await cp(dirname(dirname(native.initdb)), binaries, { recursive: true, dereference: true });
		const data = join(directory, "data");
		const passwordFile = join(directory, "password");
		await writeFile(passwordFile, password);
		const run = promisify(execFile);
		await run(join(binaries, "bin", "initdb.exe"), ["-D", data, "-U", "postgres", `--pwfile=${passwordFile}`, "--auth=scram-sha-256", "--encoding=UTF8", "--locale=C"], { windowsHide: true, timeout: 30000 });
		await run(join(binaries, "bin", "pg_ctl.exe"), ["-D", data, "-l", join(directory, "server.log"), "-o", `-h 127.0.0.1 -p ${port}`, "-w", "start"], { windowsHide: true, timeout: 30000 });
		stopPostgres = () => run(join(binaries, "bin", "pg_ctl.exe"), ["-D", data, "-m", "fast", "-w", "stop"], { windowsHide: true, timeout: 30000 });
	} else {
		postgres = new EmbeddedPostgres({ databaseDir: directory, user: "postgres", password, port,
			persistent: true, createPostgresUser: false, initdbFlags: ["--encoding=UTF8", "--locale=C"],
			postgresFlags: ["-h", "127.0.0.1"], onLog: () => undefined, onError: () => undefined });
		await postgres.initialise(); await postgres.start(); stopPostgres = () => postgres.stop();
	}
	connection = `postgresql://postgres:${password}@127.0.0.1:${port}/postgres`;
	admin = new Client({ connectionString: connection }); await admin.connect();
	for (const name of (await readdir(new NodeURL("../../migrations/", import.meta.url))).filter((name) => name.endsWith(".sql")).sort()) {
		await admin.query(await readFile(new NodeURL(`../../migrations/${name}`, import.meta.url), "utf8"));
	}
	env = { HYPERDRIVE: { connectionString: connection }, ADMIN_WEB_ORIGIN: "https://example.com" } as WorkerBindings;
}, 60000);

beforeEach(async () => {
	await admin.query("TRUNCATE runline_users, clubs CASCADE");
	owner = await account(1); member = await account(2); other = await account(3); late = await account(4);
	const created = await createClub(connection, owner.id, clubInput({ name: "채팅 클럽", region: "서울" }));
	clubId = created.club.id;
	await joinClub(connection, member.id, clubId);
	ownerIdentity = await identity(owner); memberIdentity = await identity(member);
});

afterAll(async () => {
	await admin?.end(); await stopPostgres?.();
	if (directory) {
		// Validate the resolved absolute target before recursive removal on Windows.
		const target = await realpath(directory);
		const parent = await realpath(tmpdir());
		if (resolve(dirname(target)).toLowerCase() !== resolve(parent).toLowerCase() || !basename(target).startsWith("runline-chat-pg-")) throw new Error("Unsafe test cleanup path");
		await rm(target, { recursive: true, force: true, maxRetries: 20, retryDelay: 200 });
	}
}, 30000);

describe("chat on real PostgreSQL", () => {
	it("stores a message before success, derives authorship, and deduplicates concurrent retries", async () => {
		const id = randomUUID();
		const results = await Promise.all([send(ownerIdentity, "안녕하세요", id), send(ownerIdentity, "안녕하세요", id)]);
		expect(results.map((value) => value.message.id)).toEqual([results[0].message.id, results[0].message.id]);
		expect(results.filter((value) => value.duplicate)).toHaveLength(1);
		const { rows } = await admin.query("SELECT * FROM club_chat_messages");
		expect(rows).toHaveLength(1);
		expect(results[0].message.sender_membership_id).toBe(ownerIdentity.membershipId);
		await expect(send(ownerIdentity, "다른 내용", id)).rejects.toMatchObject({ code: "MESSAGE_ID_CONFLICT" });
	});

	it("hides every pre-join message including equal timestamps and resets the boundary on rejoin", async () => {
		await send(ownerIdentity, "가입 전");
		await joinClub(connection, late.id, clubId);
		await send(ownerIdentity, "가입 후");
		await admin.query("UPDATE club_chat_messages SET created_at = '2026-11-23T00:00:00Z'");
		expect((await history(connection, late.id, clubId, { after: "0" })).items.map((value) => value.content)).toEqual(["가입 후"]);
		const firstIdentity = await identity(late);
		await leaveClub(connection, late.id, clubId);
		await send(ownerIdentity, "탈퇴 중");
		await joinClub(connection, late.id, clubId);
		expect((await history(connection, late.id, clubId, {})).items).toHaveLength(0);
		await expect(send(firstIdentity, "이전 연결")).rejects.toMatchObject({ code: "CLUB_MEMBERSHIP_REQUIRED" });
	});

	it("serializes join and send races using the exact committed message boundary", async () => {
		const [message] = await Promise.all([send(ownerIdentity, "동시 가입"), joinClub(connection, late.id, clubId)]);
		const state = await getChatState(connection, late.id, clubId);
		const visible = await history(connection, late.id, clubId, {});
		expect(visible.items.some((row) => row.id === message.message.id)).toBe(BigInt(message.message.sequence) > BigInt(state.visible_after_sequence));
	});

	it("assigns contiguous sequence numbers to simultaneous sends and rolls back rate-limit failures", async () => {
		const results = await Promise.all(Array.from({ length: 20 }, (_, index) => send(ownerIdentity, `동시 ${index}`)));
		expect(results.map((value) => Number(value.message.sequence)).sort((a,b) => a-b)).toEqual(Array.from({ length: 20 }, (_, index) => index + 1));
		await expect(send(ownerIdentity, "초과")).rejects.toMatchObject({ code: "CHAT_RATE_LIMIT" });
		expect((await getChatState(connection, owner.id, clubId)).last_sequence).toBe("20");
		await expect(send(ownerIdentity, results[0].message.content, results[0].message.client_message_id)).resolves.toMatchObject({ duplicate: true });
	});

	it("paginates without gaps, clamps reads to the visible range and never moves reads backwards", async () => {
		for (let i = 0; i < 5; i++) await send(ownerIdentity, `메시지 ${i}`);
		const newest = await history(connection, member.id, clubId, { limit: "2" });
		expect(newest.items.map((row) => row.sequence)).toEqual(["5", "4"]);
		const older = await history(connection, member.id, clubId, { before: newest.nextSequence!, limit: "2" });
		expect(older.items.map((row) => row.sequence)).toEqual(["3", "2"]);
		const recovered = await history(connection, member.id, clubId, { after: "2", limit: "2" });
		expect(recovered.items.map((row) => row.sequence)).toEqual(["3", "4"]);
		expect((await getChatState(connection, member.id, clubId)).unread_count).toBe(5);
		await markRead(connection, member.id, clubId, "4");
		expect((await markRead(connection, member.id, clubId, "2")).last_read_sequence).toBe("4");
		await expect(markRead(connection, member.id, clubId, "6")).rejects.toMatchObject({ code: "INVALID_REQUEST" });
	});

	it("blocks foreign club history, forged senders, malformed sequences and oversized content", async () => {
		await expect(history(connection, other.id, clubId, {})).rejects.toMatchObject({ status: 403 });
		await expect(saveMessage(connection, clubId, ownerIdentity, { type: "send", clientMessageId: randomUUID(), content: "위조", senderId: member.id })).rejects.toMatchObject({ code: "INVALID_REQUEST" });
		await expect(send(ownerIdentity, "가".repeat(2001))).rejects.toMatchObject({ code: "INVALID_REQUEST" });
		expect((await request(member, `/clubs/${clubId}/chat/messages?after=9223372036854775808`)).status).toBe(400);
		expect((await request(member, `/clubs/${clubId}/chat/messages?before=1&after=0`)).status).toBe(400);
	});

	it("rechecks recipients after kick/logout/rotation, and preserves departed messages", async () => {
		await send(memberIdentity, "보관할 대화");
		await kickMember(connection, owner.id, clubId, memberIdentity.membershipId);
		await dispatchAuthorized(connection, clubId, [ownerIdentity, memberIdentity], (valid) => {
			expect(valid.has(`${ownerIdentity.accessHash}:${ownerIdentity.membershipId}`)).toBe(true);
			expect(valid.has(`${memberIdentity.accessHash}:${memberIdentity.membershipId}`)).toBe(false);
		});
		expect((await history(connection, owner.id, clubId, {})).items[0].content).toBe("보관할 대화");
		await expect(send(memberIdentity, "차단")).rejects.toMatchObject({ status: 403 });
		await endSession(connection, owner.refresh);
		await expect(send(ownerIdentity, "로그아웃 후")).rejects.toMatchObject({ status: 401 });
	});

	it("expires existing socket identities on token refresh and refuses closed-club access", async () => {
		await refreshSession(connection, member.refresh);
		await expect(send(memberIdentity, "갱신 전 연결")).rejects.toMatchObject({ status: 401 });
		await closeClub(connection, owner.id, clubId);
		await expect(history(connection, owner.id, clubId, {})).rejects.toMatchObject({ status: 404 });
	});

	it("rolls back sequence allocation and message storage together on SQL failure", async () => {
		await admin.query(`CREATE FUNCTION fail_chat_message() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'test failure'; END; $$;
			CREATE TRIGGER fail_chat_message BEFORE INSERT ON club_chat_messages FOR EACH ROW EXECUTE FUNCTION fail_chat_message()`);
		try { await expect(send(ownerIdentity, "실패")).rejects.toBeDefined(); }
		finally { await admin.query("DROP TRIGGER fail_chat_message ON club_chat_messages; DROP FUNCTION fail_chat_message()"); }
		expect((await getChatState(connection, owner.id, clubId)).last_sequence).toBe("0");
		expect((await history(connection, owner.id, clubId, {})).items).toHaveLength(0);
	});
});
