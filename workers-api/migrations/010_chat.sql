BEGIN;

ALTER TABLE clubs ADD COLUMN chat_last_sequence bigint NOT NULL DEFAULT 0 CHECK (chat_last_sequence >= 0);
ALTER TABLE club_memberships ADD COLUMN chat_visible_after_sequence bigint NOT NULL DEFAULT 0 CHECK (chat_visible_after_sequence >= 0);

CREATE TABLE club_chat_state (
    membership_id uuid PRIMARY KEY REFERENCES club_memberships(id),
    last_read_sequence bigint NOT NULL DEFAULT 0 CHECK (last_read_sequence >= 0),
    send_window_started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    send_count integer NOT NULL DEFAULT 0 CHECK (send_count >= 0)
);
INSERT INTO club_chat_state (membership_id) SELECT id FROM club_memberships;

CREATE FUNCTION initialize_club_chat_membership() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    -- The same club row serializes message commits and membership boundaries.
    SELECT chat_last_sequence INTO NEW.chat_visible_after_sequence FROM clubs WHERE id = NEW.club_id FOR UPDATE;
    RETURN NEW;
END;
$$;
CREATE TRIGGER club_chat_join_boundary BEFORE INSERT ON club_memberships
FOR EACH ROW EXECUTE FUNCTION initialize_club_chat_membership();

CREATE FUNCTION initialize_club_chat_state() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO club_chat_state (membership_id, last_read_sequence) VALUES (NEW.id, NEW.chat_visible_after_sequence);
    RETURN NEW;
END;
$$;
CREATE TRIGGER club_chat_join_state AFTER INSERT ON club_memberships
FOR EACH ROW EXECUTE FUNCTION initialize_club_chat_state();

CREATE TABLE club_chat_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL REFERENCES clubs(id),
    sequence bigint NOT NULL CHECK (sequence > 0),
    sender_membership_id uuid NOT NULL,
    client_message_id uuid NOT NULL,
    content text NOT NULL CHECK (char_length(content) BETWEEN 1 AND 2000 AND octet_length(content) <= 8000),
    created_at timestamptz(3) NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (club_id, sequence),
    UNIQUE (sender_membership_id, client_message_id),
    FOREIGN KEY (sender_membership_id, club_id) REFERENCES club_memberships(id, club_id)
);

COMMIT;
