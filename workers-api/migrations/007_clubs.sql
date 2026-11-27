BEGIN;

ALTER TABLE runline_users
    ADD COLUMN nickname text NOT NULL DEFAULT '러너' CHECK (char_length(nickname) BETWEEN 1 AND 30),
    ADD COLUMN avatar_url text CHECK (char_length(avatar_url) <= 2048);

CREATE TABLE clubs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 50),
    description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 2000),
    region text NOT NULL CHECK (char_length(region) BETWEEN 1 AND 100),
    image_url text CHECK (char_length(image_url) <= 2048),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'closed')),
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz(3) NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE club_memberships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL REFERENCES clubs(id),
    user_id uuid NOT NULL REFERENCES runline_users(id),
    role text NOT NULL CHECK (role IN ('owner', 'member')),
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'left', 'kicked', 'closed')),
    joined_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    ended_at timestamptz(3),
    UNIQUE (id, club_id),
    CHECK ((status = 'active' AND ended_at IS NULL) OR (status <> 'active' AND ended_at IS NOT NULL))
);
CREATE UNIQUE INDEX one_active_club_per_user ON club_memberships (user_id) WHERE status = 'active';
CREATE UNIQUE INDEX one_active_owner_per_club ON club_memberships (club_id) WHERE status = 'active' AND role = 'owner';
CREATE INDEX club_members_list ON club_memberships (club_id, joined_at DESC, id DESC) WHERE status = 'active';
CREATE INDEX active_clubs_list ON clubs (created_at DESC, id DESC) WHERE status = 'active';

CREATE TABLE club_notices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL REFERENCES clubs(id),
    author_membership_id uuid NOT NULL,
    title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
    content text NOT NULL CHECK (char_length(content) BETWEEN 1 AND 10000),
    pinned boolean NOT NULL DEFAULT false,
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    deleted_at timestamptz(3),
    UNIQUE (id, club_id),
    FOREIGN KEY (author_membership_id, club_id) REFERENCES club_memberships(id, club_id)
);
CREATE INDEX club_notices_list ON club_notices (club_id, pinned DESC, created_at DESC, id DESC) WHERE deleted_at IS NULL;

-- Initial private attachment storage: up to 5 files/notice, 5 MiB/file (enforced by the API).
CREATE TABLE club_attachments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL,
    notice_id uuid NOT NULL,
    filename text NOT NULL CHECK (char_length(filename) BETWEEN 1 AND 200),
    content_type text NOT NULL,
    data bytea NOT NULL CHECK (octet_length(data) BETWEEN 1 AND 5242880),
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    FOREIGN KEY (notice_id, club_id) REFERENCES club_notices(id, club_id)
);
CREATE INDEX club_attachments_notice ON club_attachments (notice_id);

CREATE TABLE club_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL REFERENCES clubs(id),
    creator_membership_id uuid NOT NULL,
    title text NOT NULL CHECK (char_length(title) BETWEEN 1 AND 100),
    description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 5000),
    location text NOT NULL CHECK (char_length(location) BETWEEN 1 AND 300),
    starts_at timestamptz(3) NOT NULL,
    ends_at timestamptz(3) NOT NULL,
    registration_closes_at timestamptz(3) NOT NULL,
    capacity integer NOT NULL CHECK (capacity BETWEEN 1 AND 10000),
    cancelled_at timestamptz(3),
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    updated_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (id, club_id),
    FOREIGN KEY (creator_membership_id, club_id) REFERENCES club_memberships(id, club_id),
    CHECK (ends_at > starts_at),
    CHECK (registration_closes_at <= starts_at)
);
CREATE INDEX club_runs_list ON club_runs (club_id, starts_at DESC, id DESC);

CREATE TABLE club_run_participants (
    run_id uuid NOT NULL,
    membership_id uuid NOT NULL,
    club_id uuid NOT NULL,
    status text NOT NULL DEFAULT 'joined' CHECK (status IN ('joined', 'cancelled')),
    joined_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    cancelled_at timestamptz(3),
    PRIMARY KEY (run_id, membership_id),
    FOREIGN KEY (run_id, club_id) REFERENCES club_runs(id, club_id),
    FOREIGN KEY (membership_id, club_id) REFERENCES club_memberships(id, club_id),
    CHECK ((status = 'joined' AND cancelled_at IS NULL) OR (status = 'cancelled' AND cancelled_at IS NOT NULL))
);

CREATE TABLE club_feed_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL REFERENCES clubs(id),
    type text NOT NULL CHECK (type IN ('notice_created', 'run_created', 'run_updated', 'run_cancelled')),
    notice_id uuid,
    run_id uuid,
    title text NOT NULL,
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    FOREIGN KEY (notice_id, club_id) REFERENCES club_notices(id, club_id),
    FOREIGN KEY (run_id, club_id) REFERENCES club_runs(id, club_id),
    CHECK ((type = 'notice_created' AND notice_id IS NOT NULL AND run_id IS NULL)
        OR (type <> 'notice_created' AND notice_id IS NULL AND run_id IS NOT NULL))
);
CREATE INDEX club_feed_list ON club_feed_events (club_id, created_at DESC, id DESC);

COMMIT;
