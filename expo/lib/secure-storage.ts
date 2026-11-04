import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';
import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Cross-platform secure key/value storage.
 * - Native (iOS/Android): expo-secure-store (Keychain / EncryptedSharedPreferences).
 * - Web: falls back to AsyncStorage (SecureStore is unavailable in browsers).
 *
 * Note: SecureStore keys may only contain alphanumerics, ".", "-", and "_".
 */
export const secureStorage = {
  async getItem(key: string): Promise<string | null> {
    if (Platform.OS === 'web') {
      return AsyncStorage.getItem(key).catch(() => null);
    }
    try {
      return await SecureStore.getItemAsync(key);
    } catch (error) {
      console.error('[SecureStorage] getItem failed:', error);
      return null;
    }
  },

  async setItem(key: string, value: string): Promise<void> {
    if (Platform.OS === 'web') {
      await AsyncStorage.setItem(key, value).catch((error) => {
        console.error('[SecureStorage] setItem (web) failed:', error);
      });
      return;
    }
    try {
      await SecureStore.setItemAsync(key, value);
    } catch (error) {
      console.error('[SecureStorage] setItem failed:', error);
    }
  },

  async removeItem(key: string): Promise<void> {
    if (Platform.OS === 'web') {
      await AsyncStorage.removeItem(key).catch(() => {});
      return;
    }
    try {
      await SecureStore.deleteItemAsync(key);
    } catch (error) {
      console.error('[SecureStorage] removeItem failed:', error);
    }
  },
};

/**
 * SecureStore documents a 2048-byte value limit, and a Supabase session
 * (access + refresh tokens plus the serialized user) is routinely larger,
 * so sessions are split into chunks with a trailing chunk-count manifest.
 */
const SUPABASE_CHUNK_SIZE = 1800;
const SUPABASE_KEY_PREFIX = 'sb_auth_';

function safeSegment(value: string): string {
  return value.replace(/[^A-Za-z0-9._-]/g, '_');
}

function chunkKey(baseKey: string, index: number): string {
  return `${SUPABASE_KEY_PREFIX}${safeSegment(baseKey)}_${index}`;
}

function countKey(baseKey: string): string {
  return `${SUPABASE_KEY_PREFIX}${safeSegment(baseKey)}_count`;
}

async function readChunkCount(baseKey: string): Promise<number> {
  const raw = await SecureStore.getItemAsync(countKey(baseKey));
  if (!raw) return 0;
  const count = Number.parseInt(raw, 10);
  return Number.isFinite(count) && count > 0 ? count : 0;
}

/**
 * Storage adapter for the Supabase client: Keychain/Keystore on native
 * (chunked), localStorage on web. Falls back to AsyncStorage per operation so
 * a SecureStore failure cannot silently drop the session.
 */
export const supabaseSecureStorage = {
  async getItem(key: string): Promise<string | null> {
    if (Platform.OS === 'web') {
      return AsyncStorage.getItem(key).catch(() => null);
    }
    try {
      const count = await readChunkCount(key);
      if (count === 0) return null;

      const parts: string[] = [];
      for (let index = 0; index < count; index++) {
        const part = await SecureStore.getItemAsync(chunkKey(key, index));
        // A partial write must read as "no session", never as truncated JSON.
        if (part === null) return null;
        parts.push(part);
      }
      return parts.join('');
    } catch (error) {
      console.error('[SecureStorage] Supabase chunked read failed:', error);
      return AsyncStorage.getItem(key).catch(() => null);
    }
  },

  async setItem(key: string, value: string): Promise<void> {
    if (Platform.OS === 'web') {
      await AsyncStorage.setItem(key, value).catch((error) => {
        console.error('[SecureStorage] Supabase setItem (web) failed:', error);
      });
      return;
    }
    try {
      const chunks: string[] = [];
      for (let offset = 0; offset < value.length; offset += SUPABASE_CHUNK_SIZE) {
        chunks.push(value.slice(offset, offset + SUPABASE_CHUNK_SIZE));
      }

      const previousCount = await readChunkCount(key);
      for (let index = 0; index < chunks.length; index++) {
        await SecureStore.setItemAsync(chunkKey(key, index), chunks[index]);
      }
      // Manifest last: the value only counts as written once every chunk exists.
      await SecureStore.setItemAsync(countKey(key), String(chunks.length));

      for (let index = chunks.length; index < previousCount; index++) {
        await SecureStore.deleteItemAsync(chunkKey(key, index));
      }
    } catch (error) {
      console.error('[SecureStorage] Supabase chunked write failed, using AsyncStorage:', error);
      await AsyncStorage.setItem(key, value).catch(() => {});
    }
  },

  async removeItem(key: string): Promise<void> {
    if (Platform.OS === 'web') {
      await AsyncStorage.removeItem(key).catch(() => {});
      return;
    }
    try {
      const count = await readChunkCount(key);
      for (let index = 0; index < count; index++) {
        await SecureStore.deleteItemAsync(chunkKey(key, index));
      }
      await SecureStore.deleteItemAsync(countKey(key));
    } catch (error) {
      console.error('[SecureStorage] Supabase chunked remove failed:', error);
    }
    await AsyncStorage.removeItem(key).catch(() => {});
  },
};
