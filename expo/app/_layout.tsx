import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Stack, useRouter, useRootNavigationState, useSegments } from "expo-router";
import React, { useEffect } from "react";
import { StyleSheet, Platform, View, Image } from 'react-native';
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { SafeAreaProvider } from "react-native-safe-area-context";
import * as SplashScreen from "expo-splash-screen";
import BackButton from "@/components/BackButton";
import ScreenTransition from "@/components/ScreenTransition";
import { ThemeProvider } from "@/contexts/theme-context";
import { AuthProvider, useAuth } from "@/contexts/auth-context";
import { initDatabase } from '@/lib/db/core';
import NetworkBanner from "@/components/NetworkBanner";
import GestureOnboarding from "@/components/GestureOnboarding";
import { registerForPushNotifications } from "@/lib/notifications";
import { applyWebPolish } from "@/lib/web-polish";
import { installWebAlert } from "@/lib/web-alert";

// react-native-web's Alert is a no-op stub; install the browser-backed version
// before any screen can raise a confirmation or error dialog.
installWebAlert();

SplashScreen.preventAutoHideAsync().catch(() => {});

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      staleTime: 5 * 60 * 1000,
    },
  },
});

function GestureOnboardingGate() {
  const { isAuthenticated, isLoading } = useAuth();
  if (isLoading || !isAuthenticated) return null;
  return <GestureOnboarding />;
}

function AuthGate({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useAuth();
  const router = useRouter();
  const segments = useSegments();
  const navState = useRootNavigationState();

  const inAuth = segments[0] === 'auth';
  // Password-recovery links land here with a short-lived session that must not
  // be bounced to the app before the user sets a new password. The route is
  // also reachable without a session so an expired link can explain itself.
  const inRecovery = segments[0] === 'reset-password';
  // Whether a redirect is needed to align the route with auth state.
  // While true, we hold the splash screen so screens don't mount and
  // immediately unmount (which aborts in-flight image fetches → AbortError).
  const needsRedirect =
    (!isAuthenticated && !inAuth && !inRecovery) || (isAuthenticated && inAuth);

  useEffect(() => {
    if (isLoading) return;
    if (!navState?.key) return;
    if (!isAuthenticated && !inAuth && !inRecovery) {
      router.replace('/auth');
    } else if (isAuthenticated && inAuth) {
      router.replace('/');
    }
  }, [isAuthenticated, isLoading, inAuth, inRecovery, navState?.key, router]);

  const [failsafe, setFailsafe] = React.useState(false);
  useEffect(() => {
    // Failsafe: never leave the user on a frozen launch screen.
    const t = setTimeout(() => {
      setFailsafe(true);
      SplashScreen.hideAsync().catch(() => {});
    }, 6000);
    return () => clearTimeout(t);
  }, []);

  useEffect(() => {
    if (!isLoading && !needsRedirect) {
      SplashScreen.hideAsync().catch(() => {});
    }
  }, [isLoading, needsRedirect]);

  if ((isLoading || needsRedirect) && !failsafe) {
    return (
      <View style={layoutStyles.splash}>
        <Image
          source={require('../assets/images/splash-icon.png')}
          style={layoutStyles.splashImage}
          resizeMode="contain"
        />
      </View>
    );
  }

  return <>{children}</>;
}

// Web has no native screen transition, so each screen fades and rises into
// place as it mounts. Native platforms keep their own push animations.
const webScreenLayout =
  Platform.OS === 'web'
    ? ({ children }: { children: React.ReactNode }) => (
        <ScreenTransition>{children}</ScreenTransition>
      )
    : undefined;

function RootLayoutNav() {
  return (
    <Stack
      screenLayout={webScreenLayout}
      screenOptions={{
        headerBackTitle: "Back",
        headerTintColor: "#ffffff",
        headerStyle: { backgroundColor: '#0c0520' },
        headerShadowVisible: false,
        headerTitleStyle: { color: '#ffffff', fontSize: 18, fontWeight: '600' as const },
        headerLeft: () => <BackButton />,
        gestureEnabled: true,
        fullScreenGestureEnabled: true,
        animation: 'slide_from_right',
        animationDuration: 260,
        animationMatchesGesture: true,
        contentStyle: { backgroundColor: '#0c0520' },
      }}
    >
      <Stack.Screen name="auth" options={{ title: "Welcome", headerShown: false }} />
      <Stack.Screen name="reset-password" options={{ title: "Set New Password", headerShown: false }} />
      <Stack.Screen name="index" options={{ title: "Alchemize", headerShown: false }} />
      <Stack.Screen name="manifestation-board/index" options={{ title: "Portal Board", headerShown: true }} />
      <Stack.Screen name="manifestation-board/[id]" options={{ title: "Manifestation Detail", headerStyle: { backgroundColor: '#0c0520' }, headerTintColor: '#ffffff' }} />
      <Stack.Screen name="manifestation-board/add" options={{ title: "Add Manifestation", headerShown: true, presentation: "modal" }} />
      <Stack.Screen name="manifestation-board/slideshow" options={{ title: "Slideshow", headerShown: false, presentation: "fullScreenModal" }} />
      <Stack.Screen name="goals/index" options={{ title: "Goals" }} />
      <Stack.Screen name="goals/[id]" options={{ title: "Goal Detail" }} />
      <Stack.Screen name="goals/add" options={{ title: "Add Goal", presentation: "modal" }} />
      <Stack.Screen name="habits/index" options={{ title: "Habits" }} />
      <Stack.Screen name="habits/add" options={{ title: "Add Habit", presentation: "modal" }} />
      <Stack.Screen name="financial/index" options={{ title: "Financial Tracker" }} />
      <Stack.Screen name="calorie/index" options={{ title: "Calorie Tracker" }} />
      <Stack.Screen name="calorie/add" options={{ title: "Add Meal", presentation: "modal" }} />
      <Stack.Screen name="todos/index" options={{ title: "To-Do List" }} />
      <Stack.Screen name="todos/add" options={{ title: "Add Task", presentation: "modal" }} />
      <Stack.Screen name="gratitude/index" options={{ title: "Gratitude Journal" }} />
      <Stack.Screen name="gratitude/add" options={{ title: "Add Entry", presentation: "modal" }} />
      <Stack.Screen name="fitness/index" options={{ title: "Fitness" }} />
      <Stack.Screen name="fitness/add" options={{ title: "Add Workout", presentation: "modal" }} />
      <Stack.Screen name="fitness/workout" options={{ title: "Workout", presentation: "modal" }} />
      <Stack.Screen name="fitness/browse" options={{ title: "Browse Workouts" }} />
      <Stack.Screen name="calorie/scan" options={{ title: "Scan Food", presentation: "modal" }} />
      <Stack.Screen name="calorie/profile" options={{ title: "Profile", presentation: "modal" }} />
      <Stack.Screen name="calorie/meal-prep" options={{ title: "Meal Prep" }} />
      <Stack.Screen name="financial/notes" options={{ title: "Financial Notes" }} />
      <Stack.Screen name="affirmations/index" options={{ title: "Affirmations" }} />
      <Stack.Screen name="affirmations/[id]" options={{ title: "Edit Affirmation" }} />
      <Stack.Screen name="affirmations/add" options={{ title: "Add Affirmation", presentation: "modal" }} />
      <Stack.Screen name="affirmations/play" options={{ title: "Play Mode", headerShown: false, presentation: "fullScreenModal" }} />
      <Stack.Screen name="settings" options={{ title: "Settings" }} />
      <Stack.Screen name="quick-add" options={{ title: "Quick Add", presentation: "modal" }} />
      <Stack.Screen name="appointments/index" options={{ title: "Appointments" }} />
      <Stack.Screen name="appointments/add" options={{ title: "Add Appointment", presentation: "modal" }} />
      <Stack.Screen name="pwa-install-prompt" options={{ title: "Install App", presentation: "modal" }} />
    </Stack>
  );
}

export default function RootLayout() {
  useEffect(() => {
    applyWebPolish();
    if (Platform.OS !== 'web') {
      console.log('[App] Initializing database...');
      initDatabase()
        .then(() => console.log('[App] Database ready'))
        .catch((err) => console.error('[App] Database init failed:', err));

      console.log('[App] Registering for push notifications...');
      registerForPushNotifications()
        .then((token) => {
          if (token) console.log('[App] Push token registered:', token);
          else console.log('[App] Push notification registration skipped or failed');
        })
        .catch((err) => console.error('[App] Push registration error:', err));
    }
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <SafeAreaProvider>
        <AuthProvider>
          <ThemeProvider>
            <GestureHandlerRootView style={layoutStyles.root}>
              <View style={layoutStyles.root}>
                <AuthGate>
                  <RootLayoutNav />
                </AuthGate>
                <NetworkBanner />
                <GestureOnboardingGate />
              </View>
            </GestureHandlerRootView>
          </ThemeProvider>
        </AuthProvider>
      </SafeAreaProvider>
    </QueryClientProvider>
  );
}

const layoutStyles = StyleSheet.create({
  root: {
    flex: 1,
  },
  splash: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0c0520',
  },
  splashImage: {
    width: 200,
    height: 200,
  },
});
