CREATE TABLE runline_posts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id uuid NOT NULL REFERENCES runline_users(id) ON DELETE CASCADE,
    body text NOT NULL CHECK (length(body) <= 2000),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX runline_posts_feed_order_idx ON runline_posts (created_at DESC, id DESC);
CREATE INDEX runline_posts_author_order_idx ON runline_posts (author_id, created_at DESC, id DESC);
