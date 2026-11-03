import React, { useEffect, useState } from 'react';
import { ActivityIndicator, Platform, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import * as Linking from 'expo-linking';
import { LinearGradient } from 'expo-linear-gradient';
import { ArrowLeft, CheckCircle2, Eye, EyeOff, Lock, ShieldAlert } from 'lucide-react-native';
import { TouchableOpacity } from '@/components/HapticTouchable';
import { useAuth } from '@/contexts/auth-context';

const MIN_PASSWORD_LENGTH = 6;

/**
 * Set-new-password screen reached from a Supabase recovery email.
 *
 * Web: `detectSessionInUrl` exchanges the link for a recovery session, then
 * AuthGate keeps this route mounted (it is exempt from the auth redirects).
 * Native: the deep link is exchanged below via `applyRecoveryLink`.
 */
export default function ResetPasswordScreen() {
  const router = useRouter();
  const { isAuthenticated, isLoading, updatePassword, applyRecoveryLink } = useAuth();

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  // Native only: the recovery email deep-links back into the app.
  useEffect(() => {
    if (Platform.OS === 'web') return;
    let active = true;

    const openLink = async (url: string | null) => {
      if (!url) return;
      const result = await applyRecoveryLink(url);
      if (active && !result.success) {
        setError(result.error || 'This reset link is invalid or has expired.');
      }
    };

    Linking.getInitialURL().then(openLink).catch(() => {});
    const subscription = Linking.addEventListener('url', ({ url }) => {
      openLink(url);
    });

    return () => {
      active = false;
      subscription.remove();
    };
  }, [applyRecoveryLink]);

  // Success: leave recovery mode and enter the authenticated app.
  useEffect(() => {
    if (!success) return;
    const timer = setTimeout(() => router.replace('/'), 1400);
    return () => clearTimeout(timer);
  }, [success, router]);

  const handleSubmit = async () => {
    if (busy || success) return;

    if (password.length < MIN_PASSWORD_LENGTH) {
      setError(`Password must be at least ${MIN_PASSWORD_LENGTH} characters`);
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setBusy(true);
    setError('');
    const result = await updatePassword(password);
    setBusy(false);

    if (result.success) {
      setPassword('');
      setConfirmPassword('');
      setSuccess(true);
      return;
    }
    setError(result.error || 'Could not update your password');
  };

  const missingSession = !isLoading && !isAuthenticated;

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scroll} keyboardShouldPersistTaps="handled">
        <TouchableOpacity
          style={styles.backRow}
          onPress={() => router.replace('/auth')}
          activeOpacity={0.7}
        >
          <ArrowLeft color="#a78bfa" size={16} strokeWidth={2.4} />
          <Text style={styles.backText}>Back to sign in</Text>
        </TouchableOpacity>

        <View style={styles.card}>
          {success ? (
            <View style={styles.stateWrap}>
              <View style={[styles.iconWrap, styles.iconWrapSuccess]}>
                <CheckCircle2 color="#34d399" size={24} strokeWidth={2.2} />
              </View>
              <Text style={styles.title}>Password updated</Text>
              <Text style={styles.subtitle}>Taking you into the app…</Text>
            </View>
          ) : (
            <>
              <View style={styles.stateWrap}>
                <View style={styles.iconWrap}>
                  <Lock color="#a78bfa" size={22} strokeWidth={2.2} />
                </View>
                <Text style={styles.title}>Set a new password</Text>
                <Text style={styles.subtitle}>Choose a new password for your account.</Text>
              </View>

              {missingSession && (
                <View style={styles.noticeRow}>
                  <ShieldAlert color="#fbbf24" size={14} strokeWidth={2.2} />
                  <Text style={styles.noticeText}>
                    No recovery session found. This link may be expired — request a new one from the sign-in screen.
                  </Text>
                </View>
              )}

              <View style={styles.field}>
                <Lock color="rgba(167,139,250,0.4)" size={16} style={styles.fieldIcon} />
                <TextInput
                  style={styles.fieldInput}
                  placeholder="New password"
                  placeholderTextColor="rgba(255,255,255,0.3)"
                  value={password}
                  onChangeText={setPassword}
                  secureTextEntry={!showPassword}
                  autoCapitalize="none"
                  autoComplete="new-password"
                  testID="new-password-input"
                />
                <TouchableOpacity
                  onPress={() => setShowPassword(!showPassword)}
                  style={styles.eyeBtn}
                  activeOpacity={0.7}
                >
                  {showPassword ? (
                    <EyeOff color="rgba(167,139,250,0.4)" size={16} />
                  ) : (
                    <Eye color="rgba(167,139,250,0.4)" size={16} />
                  )}
                </TouchableOpacity>
              </View>

              <View style={styles.field}>
                <Lock color="rgba(167,139,250,0.4)" size={16} style={styles.fieldIcon} />
                <TextInput
                  style={styles.fieldInput}
                  placeholder="Confirm new password"
                  placeholderTextColor="rgba(255,255,255,0.3)"
                  value={confirmPassword}
                  onChangeText={setConfirmPassword}
                  secureTextEntry={!showPassword}
                  autoCapitalize="none"
                  autoComplete="new-password"
                  testID="confirm-password-input"
                />
              </View>

              {error ? <Text style={styles.errorMsg}>{error}</Text> : null}

              <TouchableOpacity
                style={styles.submitBtn}
                onPress={handleSubmit}
                disabled={busy}
                activeOpacity={0.85}
                testID="update-password-button"
              >
                <LinearGradient colors={['#7c3aed', '#a855f7']} style={styles.submitGradient}>
                  {busy ? (
                    <ActivityIndicator color="#fff" size="small" />
                  ) : (
                    <Text style={styles.submitText}>Update password</Text>
                  )}
                </LinearGradient>
              </TouchableOpacity>
            </>
          )}
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0c0520',
  },
  scroll: {
    flexGrow: 1,
    justifyContent: 'center',
    paddingHorizontal: 20,
    paddingVertical: 32,
  },
  backRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 16,
    alignSelf: 'flex-start',
  },
  backText: {
    color: '#a78bfa',
    fontSize: 12,
    fontWeight: '600' as const,
  },
  card: {
    backgroundColor: 'rgba(15,8,30,0.85)',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: 'rgba(139,92,246,0.12)',
    maxWidth: 440,
    width: '100%',
    alignSelf: 'center',
  },
  stateWrap: {
    alignItems: 'center',
    marginBottom: 16,
  },
  iconWrap: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: 'rgba(139,92,246,0.12)',
    borderWidth: 1,
    borderColor: 'rgba(139,92,246,0.3)',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 10,
  },
  iconWrapSuccess: {
    backgroundColor: 'rgba(52,211,153,0.12)',
    borderColor: 'rgba(52,211,153,0.3)',
  },
  title: {
    fontSize: 17,
    fontWeight: '700' as const,
    color: '#fff',
    marginBottom: 4,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 12,
    color: 'rgba(196,181,253,0.7)',
    textAlign: 'center',
  },
  noticeRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
    backgroundColor: 'rgba(251,191,36,0.08)',
    borderWidth: 1,
    borderColor: 'rgba(251,191,36,0.25)',
    borderRadius: 12,
    padding: 10,
    marginBottom: 12,
  },
  noticeText: {
    flex: 1,
    fontSize: 11,
    lineHeight: 16,
    color: 'rgba(251,191,36,0.85)',
  },
  field: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(139,92,246,0.06)',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(139,92,246,0.12)',
    marginBottom: 10,
    height: 46,
  },
  fieldIcon: {
    marginLeft: 14,
    marginRight: 2,
  },
  fieldInput: {
    flex: 1,
    paddingHorizontal: 10,
    fontSize: 14,
    color: '#fff',
    height: '100%',
  },
  eyeBtn: {
    paddingHorizontal: 14,
    height: '100%',
    justifyContent: 'center',
  },
  errorMsg: {
    color: '#f87171',
    fontSize: 12,
    marginBottom: 8,
    textAlign: 'center',
  },
  submitBtn: {
    borderRadius: 12,
    overflow: 'hidden',
    marginTop: 6,
  },
  submitGradient: {
    paddingVertical: 13,
    alignItems: 'center',
    justifyContent: 'center',
  },
  submitText: {
    fontSize: 15,
    fontWeight: '700' as const,
    color: '#fff',
    letterSpacing: 0.5,
  },
});
