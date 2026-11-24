export type WorkerBindings = Cloudflare.Env & {
	ADMIN_WEB_ORIGIN?: string;
	KAKAO_APP_ID?: string;
	FEED_MEDIA_SIGNING_SECRET?: string;
	RUNLINE_WEB_ORIGIN?: string;
};
