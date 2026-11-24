export const profileNicknameSql = "COALESCE(profile.nickname, '러너 ' || left(u.id::text, 8))";
