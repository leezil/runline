export type WorkerBindings = Cloudflare.Env & {
	ADMIN_WEB_ORIGIN?: string;
	ENABLE_WEB_TEST_LOGIN?: string;
	KAKAO_REST_API_KEY?: string;
	KAKAO_WEB_REDIRECT_URI?: string;
	KAKAO_CLIENT_SECRET?: string;
	KAKAO_APP_ID?: string;
	FEED_MEDIA_SIGNING_SECRET?: string;
	RUNLINE_WEB_ORIGIN?: string;
};
