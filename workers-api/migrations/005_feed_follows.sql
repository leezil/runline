BEGIN;

CREATE TABLE runline_user_follows (
    follower_id uuid NOT NULL REFERENCES runline_users(id) ON DELETE CASCADE,
    following_id uuid NOT NULL REFERENCES runline_users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id <> following_id)
);

CREATE INDEX runline_user_follows_following_idx ON runline_user_follows (following_id);

COMMIT;
