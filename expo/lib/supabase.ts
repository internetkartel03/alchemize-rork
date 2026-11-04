import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { Platform } from 'react-native';
import { supabaseSecureStorage } from '@/lib/secure-storage';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;

let supabaseInstance: SupabaseClient | null = null;

/**
 * Creates (or returns) the singleton Supabase client.
 * On native platforms, uses AsyncStorage for session persistence.
 * On web, relies on localStorage (Supabase default) and parses the
 * session returned in the URL hash by password-recovery links.
 */
export function getSupabase(): SupabaseClient {
  if (supabaseInstance) return supabaseInstance;

  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('[Supabase] Missing EXPO_PUBLIC_SUPABASE_URL or EXPO_PUBLIC_SUPABASE_ANON_KEY');
    throw new Error(
      'Supabase is not configured. Please set EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_ANON_KEY in your environment.'
    );
  }

  supabaseInstance = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
      // Native sessions are chunked into Keychain/Keystore; web uses localStorage.
      storage: Platform.OS === 'web' ? undefined : supabaseSecureStorage,
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: Platform.OS === 'web',
    },
  });

  console.log('[Supabase] Client initialized');
  return supabaseInstance;
}

/**
 * Returns the ID of the user authenticated with Supabase Auth.
 *
 * Ownership is always taken from the stored Supabase session — never from a
 * caller-supplied value. The server independently enforces the same identity
 * through RLS (`auth.uid() = user_id`), so a forged ID cannot grant access.
 */
export async function getAuthenticatedUserId(): Promise<string> {
  const supabase = getSupabase();
  const { data, error } = await supabase.auth.getSession();
  const userId = data?.session?.user?.id;

  if (error || !userId) {
    throw new Error('User is not authenticated. Please sign in.');
  }
  return userId;
}

/**
 * Logs a Supabase operation result for development visibility.
 * In production, errors still log; successes are silent unless verbose.
 */
export function logSupabaseOp(
  operation: 'SELECT' | 'INSERT' | 'UPDATE' | 'DELETE' | 'UPSERT' | 'STORAGE_UPLOAD',
  tableOrBucket: string,
  result: { error: any } | null,
  extra?: string
): void {
  if (result?.error) {
    console.error(
      `[Supabase] ${operation} FAILED on ${tableOrBucket}:`,
      result.error.message || result.error,
      extra ?? ''
    );
  } else if (typeof __DEV__ !== 'undefined' ? __DEV__ : process.env.NODE_ENV !== 'production') {
    console.log(`[Supabase] ${operation} OK on ${tableOrBucket}`, extra ?? '');
  }
}
