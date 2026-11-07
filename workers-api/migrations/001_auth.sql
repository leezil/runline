BEGIN;

CREATE TABLE runline_users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kakao_user_id bigint NOT NULL UNIQUE
);

CREATE TABLE runline_sessions (
    user_id uuid NOT NULL REFERENCES runline_users(id) ON DELETE CASCADE,
    access_token_hash text NOT NULL UNIQUE,
    refresh_token_hash text PRIMARY KEY,
    access_expires_at timestamptz NOT NULL,
    refresh_expires_at timestamptz NOT NULL
);

COMMIT;
