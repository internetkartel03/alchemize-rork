import React, { useEffect, useRef } from 'react';
import { Animated, Platform, StyleSheet } from 'react-native';
import { usePathname, useRootNavigationState, useSegments } from 'expo-router';

interface ScreenTransitionProps {
  children: React.ReactNode;
}

/**
 * Soft fade + rise whenever the route changes. Native stack transitions already
 * animate on iOS/Android, so this is applied on web only, where screen swaps are
 * otherwise instant. Renders its children unchanged everywhere else.
 */
export default function ScreenTransition({ children }: ScreenTransitionProps) {
  const pathname = usePathname();
  const segments = useSegments();
  const navigationState = useRootNavigationState();
  const activeRoute =
    navigationState?.routes?.[navigationState.index ?? 0]?.key ?? '';
  // React to whichever route signal refreshes first on this router version.
  const routeKey = `${pathname}::${segments.join('/')}::${activeRoute}::${
    navigationState?.routes?.length ?? 0
  }`;
  const opacity = useRef(new Animated.Value(1)).current;
  const lift = useRef(new Animated.Value(0)).current;
  const lastRoute = useRef(routeKey);

  useEffect(() => {
    if (lastRoute.current === routeKey) return;
    lastRoute.current = routeKey;

    opacity.setValue(0.75);
    lift.setValue(6);
    Animated.parallel([
      Animated.timing(opacity, {
        toValue: 1,
        duration: 200,
        useNativeDriver: Platform.OS !== 'web',
      }),
      Animated.timing(lift, {
        toValue: 0,
        duration: 260,
        useNativeDriver: Platform.OS !== 'web',
      }),
    ]).start();
  }, [routeKey, opacity, lift]);

  if (Platform.OS !== 'web') return <>{children}</>;

  return (
    <Animated.View
      testID="screen-transition"
      style={[styles.container, { opacity, transform: [{ translateY: lift }] }]}
    >
      {children}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
