"use client";

import { useEffect, useState } from "react";

type ApiHealth = {
	ok: boolean;
	service?: string;
};

type ApiStatus = "checking" | "connected" | "unavailable";

export default function Home() {
	const [status, setStatus] = useState<ApiStatus>("checking");
	const [retryCount, setRetryCount] = useState(0);
	const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/+$/, "");

	useEffect(() => {
		const controller = new AbortController();

		async function checkApi() {
			setStatus("checking");
			if (!apiBaseUrl) {
				setStatus("unavailable");
				return;
			}

			try {
				const response = await fetch(`${apiBaseUrl}/api/v1/health`, {
					cache: "no-store",
					signal: controller.signal,
				});

				if (!response.ok) {
					setStatus("unavailable");
					return;
				}

				const health = (await response.json()) as ApiHealth;
				setStatus(
					health.ok && health.service === "runline-api"
						? "connected"
						: "unavailable",
				);
			} catch {
				if (!controller.signal.aborted) {
					setStatus("unavailable");
				}
			}
		}

		void checkApi();
		return () => controller.abort();
	}, [apiBaseUrl, retryCount]);

	const statusText = {
		checking: "확인 중",
		connected: "연결됨",
		unavailable: "연결할 수 없음",
	}[status];

	return (
		<div className="flex min-h-screen items-center justify-center bg-zinc-100 px-6 font-sans text-zinc-950">
			<main className="w-full max-w-xl rounded-2xl border border-zinc-200 bg-white p-8 shadow-sm">
				<p className="text-sm font-semibold uppercase tracking-[0.2em] text-blue-700">
					RunLine Admin
				</p>
				<h1 className="mt-3 text-3xl font-bold tracking-tight">API 연결 상태</h1>
				<p className="mt-2 text-sm text-zinc-600">
					관리자 웹에서 로컬 Workers API 상태를 확인합니다.
				</p>
				<div
					className="mt-8 flex items-center gap-3 rounded-xl bg-zinc-50 p-4"
					role="status"
					aria-live="polite"
				>
					<span
						className={`h-3 w-3 rounded-full ${
							status === "connected"
								? "bg-emerald-500"
								: status === "unavailable"
									? "bg-red-500"
									: "animate-pulse bg-amber-400"
						}`}
					/>
					<span className="font-medium">{statusText}</span>
				</div>
				<p className="mt-4 break-all font-mono text-xs text-zinc-500">
					{apiBaseUrl ?? "NEXT_PUBLIC_API_BASE_URL이 설정되지 않았습니다."}
				</p>
				<button
					type="button"
					disabled={status === "checking"}
					onClick={() => setRetryCount((count) => count + 1)}
					className="mt-6 rounded-lg bg-blue-700 px-4 py-2 text-sm font-medium text-white hover:bg-blue-800 disabled:cursor-wait disabled:opacity-60"
				>
					다시 확인
				</button>
			</main>
		</div>
	);
}
