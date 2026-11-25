BEGIN;

CREATE TABLE runline_post_media (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id uuid NOT NULL REFERENCES runline_users(id),
    object_key text NOT NULL UNIQUE,
    content_type text NOT NULL CHECK (content_type IN ('image/jpeg', 'image/png', 'image/webp')),
    byte_size integer NOT NULL CHECK (byte_size BETWEEN 1 AND 5242880),
    created_at timestamptz NOT NULL DEFAULT now(),
    uploaded_at timestamptz,
    post_id uuid REFERENCES runline_posts(id) ON DELETE SET NULL,
    position integer CHECK (position BETWEEN 0 AND 3),
    attached_at timestamptz,
    discard_after timestamptz,
    UNIQUE (post_id, position) DEFERRABLE INITIALLY DEFERRED,
    CHECK (post_id IS NULL OR (position IS NOT NULL AND attached_at IS NOT NULL AND uploaded_at IS NOT NULL))
);

CREATE INDEX runline_post_media_unattached_idx ON runline_post_media (created_at) WHERE post_id IS NULL;

COMMIT;
