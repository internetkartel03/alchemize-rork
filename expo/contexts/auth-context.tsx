import { useState, useEffect, useCallback, useMemo } from 'react';
import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import createContextHook from '@nkzw/create-context-hook';
import * as AppleAuthentication from 'expo-apple-authentication';
import * as Crypto from 'expo-crypto';
import * as Linking from 'expo-linking';
import type { Session, User as SupabaseUser } from '@supabase/supabase-js';

import { setCurrentUserId } from '@/lib/db/core';
import { localUserIdForAuthUser, recordLegacyUserId } from '@/lib/legacy-user-map';
import { parseRecoveryLink } from '@/lib/recovery-link';
import { getSupabase } from '@/lib/supabase';
import { secureStorage } from '@/lib/secure-storage';

const AUTH_STORAGE_KEY = '@alchemize_auth';
const AUTH_SECURE_KEY = 'alchemize_auth_session';
const REMEMBER_ME_KEY = '@alchemize_remember_me';
const USERS_STORAGE_KEY = '@alchemize_users';

interface User {
  id: string;
  email: string;
  name: string;
}

interface AuthState {
  user: User | null;
  token: string | null;
}

interface StoredUser {
  id: string;
  email: string;
  name: string;
  password: string;
}

// Avoid re-running the idempotent upgrade on every token refresh.
const finalizedLegacyIds = new Set<string>();

type LegacyMigrationResult =
  | { status: 'no-match' }
  | { status: 'migrated'; session: Session }
  | { status: 'needs-confirmation' }
  | { status: 'failed'; error: string };

function displayNameFor(supabaseUser: SupabaseUser): string {
  const metadata = (supabaseUser.user_metadata ?? {}) as Record<string, unknown>;
  const candidate = [metadata.name, metadata.display_name, metadata.full_name].find(
    (value): value is string => typeof value === 'string' && value.trim().length > 0
  );
  if (candidate) return candidate.trim();
  return supabaseUser.email?.split('@')[0] || 'Alchemize User';
}

function mapUser(supabaseUser: SupabaseUser): User {
  return {
    id: supabaseUser.id,
    email: supabaseUser.email ?? '',
    name: displayNameFor(supabaseUser),
  };
}

function friendlyAuthError(message?: string): string {
  const text = (message || '').toLowerCase();
  if (text.includes('invalid login credentials')) return 'Invalid email or password';
  if (text.includes('email not confirmed')) return 'Please confirm your email address, then sign in';
  if (text.includes('already registered') || text.includes('already been registered')) {
    return 'An account with this email already exists';
  }
  if (text.includes('password should be at least')) return 'Password must be at least 6 characters';
  if (text.includes('invalid email')) return 'Please enter a valid email address';
  if (text.includes('rate limit') || text.includes('too many')) {
    return 'Too many attempts. Please try again shortly';
  }
  if (text.includes('auth session missing')) {
    return 'This reset link has expired. Please request a new one.';
  }
  if (text.includes('should be different from the old password')) {
    return 'Choose a password that differs from your current one';
  }
  return message || 'Authentication failed';
}

/**
 * Where Supabase sends the recovery email back to: the recovery route on the
 * current web origin, or the app's own deep link on native.
 */
function buildResetRedirectUrl(): string | undefined {
  if (Platform.OS === 'web') {
    return typeof window !== 'undefined' ? `${window.location.origin}/reset-password` : undefined;
  }
  return Linking.createURL('/reset-password');
}

function isInvalidCredentials(message?: string): boolean {
  const text = (message || '').toLowerCase();
  return text.includes('invalid login credentials') || text.includes('invalid credentials');
}

async function readLegacyUsers(): Promise<StoredUser[]> {
  try {
    const raw = await AsyncStorage.getItem(USERS_STORAGE_KEY);
    if (!raw || typeof raw !== 'string' || !raw.trim().startsWith('[')) return [];
    const parsed = JSON.parse(raw) as StoredUser[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/**
 * Runs only after a Supabase session exists. Rewrites the legacy local
 * account ID to the Supabase user ID and drops that account's stored
 * password; other local accounts and all local app data are left intact.
 */
async function finalizeLegacyMigration(legacyId: string, authId: string): Promise<void> {
  try {
    await recordLegacyUserId(legacyId, authId);

    const users = await readLegacyUsers();
    const remaining = users.filter((user) => user.id !== legacyId);
    if (remaining.length !== users.length) {
      if (remaining.length === 0) {
        await AsyncStorage.removeItem(USERS_STORAGE_KEY);
      } else {
        await AsyncStorage.setItem(USERS_STORAGE_KEY, JSON.stringify(remaining));
      }
      console.log('[Auth] Legacy credentials migrated for account:', legacyId);
    }

    // Supabase now owns session persistence for this device.
    await secureStorage.removeItem(AUTH_SECURE_KEY);
    await AsyncStorage.removeItem(AUTH_STORAGE_KEY).catch(() => {});
  } catch (error) {
    console.warn('[Auth] Legacy migration cleanup failed:', error);
  }
}

export const [AuthProvider, useAuth] = createContextHook(() => {
  const [authState, setAuthState] = useState<AuthState>({
    user: null,
    token: null,
  });
  const [rememberMe, setRememberMeState] = useState(false);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  /**
   * Single place where the app's user identity is derived. The ID always
   * comes from the Supabase session; data services read the same session.
   */
  const applySession = useCallback(async (session: Session | null) => {
    if (!session?.user) {
      setAuthState({ user: null, token: null });
      setCurrentUserId(null);
      return;
    }

    const user = mapUser(session.user);
    setAuthState({ user, token: session.access_token ?? null });

    // Finalize the legacy upgrade first so the local scope below sees the mapping.
    const legacyId = (session.user.user_metadata ?? {}).legacy_user_id;
    if (typeof legacyId === 'string' && legacyId.length > 0 && !finalizedLegacyIds.has(legacyId)) {
      await finalizeLegacyMigration(legacyId, user.id);
      finalizedLegacyIds.add(legacyId);
    }

    // Local SQLite stays scoped to the legacy ID for upgraded accounts so
    // existing rows remain readable without being rewritten.
    const localUserId = await localUserIdForAuthUser(user.id);
    setCurrentUserId(localUserId);
  }, []);

  useEffect(() => {
    let active = true;
    let finished = false;
    const finish = () => {
      if (!finished) {
        finished = true;
        setIsLoading(false);
      }
    };
    // Failsafe: never keep the launch screen up if the auth check hangs.
    const timer = setTimeout(() => {
      console.warn('[Auth] Auth load timed out, continuing');
      finish();
    }, 4000);

    let subscription: { unsubscribe: () => void } | null = null;

    try {
      const supabase = getSupabase();

      supabase.auth
        .getSession()
        .then(({ data }) => {
          if (active) return applySession(data.session);
        })
        .catch((error) => {
          console.error('[Auth] Session restore failed:', error);
        })
        .finally(() => {
          clearTimeout(timer);
          finish();
        });

      const { data } = supabase.auth.onAuthStateChange((event, session) => {
        if (!active) return;
        console.log('[Auth] Supabase auth event:', event);
        void applySession(session);
      });
      subscription = data.subscription;
    } catch (error) {
      console.error('[Auth] Supabase client unavailable:', error);
      clearTimeout(timer);
      finish();
    }

    AsyncStorage.getItem(REMEMBER_ME_KEY)
      .then((value) => {
        if (active && value === 'true') setRememberMeState(true);
      })
      .catch(() => {});

    return () => {
      active = false;
      subscription?.unsubscribe();
      clearTimeout(timer);
    };
  }, [applySession]);

  /**
   * One-time upgrade for accounts created by the old local-only auth.
   * The stored password is verified locally first; a Supabase session is
   * required before any credential is removed.
   */
  const migrateLegacyAccount = useCallback(
    async (email: string, password: string): Promise<LegacyMigrationResult> => {
      const users = await readLegacyUsers();
      const legacy = users.find(
        (user) =>
          user.email?.toLowerCase() === email.toLowerCase() && typeof user.password === 'string' && user.password.length > 0
      );

      if (!legacy || legacy.password !== password) return { status: 'no-match' };

      const supabase = getSupabase();
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { name: legacy.name, legacy_user_id: legacy.id } },
      });

      if (error) {
        // The address may already exist in Supabase; try the verified password.
        const retry = await supabase.auth.signInWithPassword({ email, password });
        if (retry.error || !retry.data.session) {
          return { status: 'failed', error: friendlyAuthError(error.message) };
        }
        await finalizeLegacyMigration(legacy.id, retry.data.user?.id ?? retry.data.session.user.id);
        return { status: 'migrated', session: retry.data.session };
      }

      if (data.session?.user) {
        await finalizeLegacyMigration(legacy.id, data.session.user.id);
        return { status: 'migrated', session: data.session };
      }

      if (data.user) {
        // Supabase returns an existing address with no identities when
        // confirmation is off; treat it as an existing account, not a new one.
        const identities = data.user.identities ?? [];
        if (identities.length === 0) {
          return {
            status: 'failed',
            error: 'An account with this email already exists. Sign in with its password or use Forgot Password.',
          };
        }
        return { status: 'needs-confirmation' };
      }
      return { status: 'failed', error: 'Account migration failed' };
    },
    []
  );

  const login = useCallback(
    async (email: string, password: string, remember: boolean) => {
      const trimmedEmail = email.trim();
      try {
        console.log('[Auth] Logging in:', trimmedEmail);
        const supabase = getSupabase();
        const { data, error } = await supabase.auth.signInWithPassword({
          email: trimmedEmail,
          password,
        });

        if (!error && data.session) {
          await applySession(data.session);
          setRememberMeState(remember);
          await AsyncStorage.setItem(REMEMBER_ME_KEY, remember.toString());
          console.log('[Auth] Login successful:', trimmedEmail);
          return { success: true };
        }

        // Only a rejected password may trigger the legacy upgrade. A network or
        // server failure must never fall through to account creation.
        if (!isInvalidCredentials(error?.message)) {
          return { success: false, error: friendlyAuthError(error?.message) };
        }

        const migration = await migrateLegacyAccount(trimmedEmail, password);
        if (migration.status === 'migrated') {
          await applySession(migration.session);
          setRememberMeState(remember);
          await AsyncStorage.setItem(REMEMBER_ME_KEY, remember.toString());
          console.log('[Auth] Legacy account migrated and signed in:', trimmedEmail);
          return { success: true };
        }
        if (migration.status === 'needs-confirmation') {
          return {
            success: false,
            error: 'Account created. Check your email to confirm it, then sign in.',
          };
        }
        if (migration.status === 'failed') {
          return { success: false, error: migration.error };
        }

        return { success: false, error: friendlyAuthError(error?.message) };
      } catch (error: any) {
        console.error('[Auth] Login error:', error);
        return { success: false, error: error.message || 'Login failed' };
      }
    },
    [applySession, migrateLegacyAccount]
  );

  const signup = useCallback(
    async (email: string, password: string, name: string) => {
      const trimmedEmail = email.trim();
      const trimmedName = name.trim();
      try {
        console.log('[Auth] Signing up:', trimmedEmail);
        const supabase = getSupabase();
        const { data, error } = await supabase.auth.signUp({
          email: trimmedEmail,
          password,
          options: { data: { name: trimmedName, display_name: trimmedName } },
        });

        if (error) return { success: false, error: friendlyAuthError(error.message) };

        if (data.session) {
          await applySession(data.session);
          console.log('[Auth] Signup successful:', trimmedEmail);
          return { success: true };
        }

        if (data.user) {
          return {
            success: false,
            error: 'Account created. Check your email to confirm it, then sign in.',
          };
        }

        return { success: false, error: 'Sign up failed' };
      } catch (error: any) {
        console.error('[Auth] Signup error:', error);
        return { success: false, error: error.message || 'Signup failed' };
      }
    },
    [applySession]
  );

  const loginWithApple = useCallback(async () => {
    try {
      console.log('[Auth] Starting Apple Sign In...');

      if (Platform.OS === 'web') {
        return { success: false, error: 'Apple Sign In is not available on web' };
      }

      const isAvailable = await AppleAuthentication.isAvailableAsync();
      if (!isAvailable) {
        return { success: false, error: 'Apple Sign In is not available on this device' };
      }

      const rawNonce = Crypto.randomUUID();
      const hashedNonce = await Crypto.digestStringAsync(
        Crypto.CryptoDigestAlgorithm.SHA256,
        rawNonce
      );

      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
        nonce: hashedNonce,
      });

      if (!credential.identityToken) {
        return { success: false, error: 'Apple did not return an identity token' };
      }

      const supabase = getSupabase();
      const { data, error } = await supabase.auth.signInWithIdToken({
        provider: 'apple',
        token: credential.identityToken,
        nonce: rawNonce,
      });

      if (error || !data.session) {
        console.error('[Auth] Supabase Apple Sign In error:', error);
        return {
          success: false,
          error: friendlyAuthError(error?.message) || 'Apple Sign In failed',
        };
      }

      const appleName = credential.fullName
        ? [credential.fullName.givenName, credential.fullName.familyName].filter(Boolean).join(' ')
        : '';

      if (appleName) {
        await supabase.auth.updateUser({ data: { name: appleName } }).catch(() => {});
        const { data: refreshed } = await supabase.auth.getSession();
        await applySession(refreshed.session ?? data.session);
      } else {
        await applySession(data.session);
      }

      console.log('[Auth] Apple Sign In successful');
      return { success: true };
    } catch (error: any) {
      if (error.code === 'ERR_REQUEST_CANCELED') {
        console.log('[Auth] Apple Sign In cancelled by user');
        return { success: false, error: 'Sign in was cancelled' };
      }
      console.error('[Auth] Apple Sign In error:', error);
      return { success: false, error: error.message || 'Apple Sign In failed' };
    }
  }, [applySession]);

  const resetPassword = useCallback(async (email: string) => {
    try {
      const trimmedEmail = email.trim();
      console.log('[Auth] Password reset requested for:', trimmedEmail);
      const supabase = getSupabase();
      const redirectTo = buildResetRedirectUrl();
      console.log('[Auth] Password reset redirect:', redirectTo ?? '(Supabase default)');

      const { error } = await supabase.auth.resetPasswordForEmail(
        trimmedEmail,
        redirectTo ? { redirectTo } : undefined
      );

      // Supabase does not reveal whether an address exists; mirror that.
      if (error) {
        console.error('[Auth] Password reset error:', error);
        return { success: false, error: friendlyAuthError(error.message) };
      }
      return { success: true };
    } catch (error: any) {
      console.error('[Auth] Password reset error:', error);
      return { success: false, error: error.message || 'Password reset failed' };
    }
  }, []);

  /**
   * Opens a recovery session from a native deep link (tokens or PKCE code).
   * Web links are handled by the Supabase client's `detectSessionInUrl`.
   */
  const applyRecoveryLink = useCallback(async (url: string) => {
    const credentials = parseRecoveryLink(url);
    if (!credentials) {
      return { success: false, error: 'This reset link is invalid or has expired.' };
    }

    try {
      const supabase = getSupabase();
      const { error } = credentials.kind === 'code'
        ? await supabase.auth.exchangeCodeForSession(credentials.code)
        : await supabase.auth.setSession({
            access_token: credentials.accessToken,
            refresh_token: credentials.refreshToken,
          });

      if (error) {
        console.error('[Auth] Recovery link error:', error);
        return { success: false, error: friendlyAuthError(error.message) };
      }
      return { success: true };
    } catch (error: any) {
      console.error('[Auth] Recovery link error:', error);
      return { success: false, error: error?.message || 'Could not open the reset link' };
    }
  }, []);

  /**
   * Sets a new password for the user holding the current (recovery) session.
   * No current password is required — Supabase authorizes by session.
   */
  const updatePassword = useCallback(async (newPassword: string) => {
    try {
      const supabase = getSupabase();
      const { error } = await supabase.auth.updateUser({ password: newPassword });

      if (error) {
        console.error('[Auth] Password update error:', error);
        return { success: false, error: friendlyAuthError(error.message) };
      }
      return { success: true };
    } catch (error: any) {
      console.error('[Auth] Password update error:', error);
      return { success: false, error: error?.message || 'Could not update your password' };
    }
  }, []);

  const logout = useCallback(async () => {
    console.log('[Auth] Logging out');
    try {
      const supabase = getSupabase();
      try {
        await supabase.auth.signOut();
      } catch (error) {
        console.warn('[Auth] Server sign-out failed, clearing local session:', error);
        await supabase.auth.signOut({ scope: 'local' }).catch(() => {});
      }
    } catch (error) {
      console.error('[Auth] Supabase client unavailable during sign-out:', error);
    }

    setAuthState({ user: null, token: null });
    setCurrentUserId(null);

    await secureStorage.removeItem(AUTH_SECURE_KEY);
    await AsyncStorage.multiRemove([AUTH_STORAGE_KEY, REMEMBER_ME_KEY]).catch(() => {});

    console.log('[Auth] Logout successful');
  }, []);

  return useMemo(() => ({
    user: authState.user,
    token: authState.token,
    isAuthenticated: !!authState.user,
    isLoading,
    rememberMe,
    login,
    signup,
    loginWithApple,
    resetPassword,
    applyRecoveryLink,
    updatePassword,
    logout,
  }), [authState.user, authState.token, isLoading, rememberMe, login, signup, loginWithApple, resetPassword, applyRecoveryLink, updatePassword, logout]);
});
