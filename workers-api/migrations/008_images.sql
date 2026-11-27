BEGIN;

CREATE TABLE feed_posts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES runline_users(id),
    title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
    content text NOT NULL DEFAULT '' CHECK (char_length(content) <= 10000),
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    deleted_at timestamptz(3)
);
CREATE INDEX feed_posts_list ON feed_posts (created_at DESC, id DESC) WHERE deleted_at IS NULL;

CREATE TABLE media_images (
    id uuid PRIMARY KEY,
    uploader_user_id uuid NOT NULL REFERENCES runline_users(id),
    purpose text NOT NULL CHECK (purpose IN ('avatar', 'club_cover', 'club_notice', 'feed')),
    club_id uuid REFERENCES clubs(id),
    notice_id uuid,
    post_id uuid REFERENCES feed_posts(id),
    object_key text NOT NULL UNIQUE,
    thumbnail_key text NOT NULL UNIQUE,
    content_type text NOT NULL DEFAULT 'image/webp' CHECK (content_type = 'image/webp'),
    width integer NOT NULL CHECK (width BETWEEN 1 AND 1600),
    height integer NOT NULL CHECK (height BETWEEN 1 AND 1600),
    size integer NOT NULL CHECK (size BETWEEN 1 AND 1048576),
    thumbnail_size integer NOT NULL CHECK (thumbnail_size BETWEEN 1 AND 262144),
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    deleted_at timestamptz(3),
    FOREIGN KEY (notice_id, club_id) REFERENCES club_notices(id, club_id),
    CHECK ((purpose = 'avatar' AND club_id IS NULL AND notice_id IS NULL AND post_id IS NULL)
        OR (purpose = 'club_cover' AND club_id IS NOT NULL AND notice_id IS NULL AND post_id IS NULL)
        OR (purpose = 'club_notice' AND club_id IS NOT NULL AND notice_id IS NOT NULL AND post_id IS NULL)
        OR (purpose = 'feed' AND club_id IS NULL AND notice_id IS NULL AND post_id IS NOT NULL))
);
CREATE UNIQUE INDEX one_current_avatar ON media_images (uploader_user_id) WHERE purpose = 'avatar' AND deleted_at IS NULL;
CREATE UNIQUE INDEX one_current_club_cover ON media_images (club_id) WHERE purpose = 'club_cover' AND deleted_at IS NULL;
CREATE INDEX notice_images ON media_images (notice_id) WHERE deleted_at IS NULL;
CREATE INDEX post_images ON media_images (post_id) WHERE deleted_at IS NULL;

ALTER TABLE club_attachments ADD COLUMN image_id uuid REFERENCES media_images(id) ON DELETE CASCADE;
ALTER TABLE club_attachments ALTER COLUMN data DROP NOT NULL;
ALTER TABLE club_attachments ADD CONSTRAINT attachment_storage CHECK (
    (image_id IS NULL AND data IS NOT NULL) OR (image_id IS NOT NULL AND data IS NULL)
);

COMMIT;
