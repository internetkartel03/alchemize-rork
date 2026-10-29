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
