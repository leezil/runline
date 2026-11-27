BEGIN;

-- Main's profile table is canonical for feed, club, notices and chat.
-- Import legacy club-only values without replacing an existing main profile.
-- Keep the old columns and prototype feed tables for non-destructive upgrades.
INSERT INTO runline_user_profiles (user_id, nickname, avatar_url)
SELECT id, nickname, avatar_url
FROM runline_users
WHERE nickname <> '러너' OR avatar_url IS NOT NULL
ON CONFLICT (user_id) DO NOTHING;

COMMIT;
