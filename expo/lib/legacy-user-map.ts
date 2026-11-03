import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Maps legacy local account IDs (`user_<epoch>_<rand>`) to Supabase Auth user IDs.
 *
 * Local SQLite rows are scoped by `userId`, and pre-migration data still carries
 * the legacy ID. Rather than rewriting those rows, the local DB scope is resolved
 * through this map so both old and new rows stay reachable.
 */
export const LEGACY_USER_ID_MAP_KEY = '@alchemize_user_id_map';

export async function readLegacyUserIdMap(): Promise<Record<string, string>> {
  try {
    const raw = await AsyncStorage.getItem(LEGACY_USER_ID_MAP_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as Record<string, string>;
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (error) {
    console.warn('[LegacyUserMap] Could not read map:', error);
    return {};
  }
}

export async function recordLegacyUserId(legacyId: string, authId: string): Promise<void> {
  try {
    const map = await readLegacyUserIdMap();
    map[legacyId] = authId;
    await AsyncStorage.setItem(LEGACY_USER_ID_MAP_KEY, JSON.stringify(map));
  } catch (error) {
    console.warn('[LegacyUserMap] Could not record mapping:', error);
  }
}

/**
 * Returns the ID local SQLite should scope to for this authenticated user.
 * Migrated accounts keep their legacy ID so existing rows remain visible;
 * accounts with no legacy history use the Supabase user ID directly.
 */
export async function localUserIdForAuthUser(authId: string): Promise<string> {
  const map = await readLegacyUserIdMap();
  for (const [legacyId, mappedAuthId] of Object.entries(map)) {
    if (mappedAuthId === authId && legacyId) return legacyId;
  }
  return authId;
}
