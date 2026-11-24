CREATE TABLE runline_user_profiles (
    user_id uuid PRIMARY KEY REFERENCES runline_users(id) ON DELETE CASCADE,
    nickname text NOT NULL CHECK (length(trim(nickname)) BETWEEN 1 AND 40),
    avatar_url text,
    bio text
);
