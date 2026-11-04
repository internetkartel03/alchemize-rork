import React, { useEffect, useRef } from 'react';
import { Animated, Platform, StyleSheet } from 'react-native';

interface ScreenTransitionProps {
  children: React.ReactNode;
}

/**
 * Soft fade-and-rise that plays as a screen mounts. Native stack transitions
 * already animate on iOS/Android, so this is mounted on web only, where screen
 * swaps are otherwise instant.
 */
export default function ScreenTransition({ children }: ScreenTransitionProps) {
  const opacity = useRef(new Animated.Value(0.7)).current;
  const lift = useRef(new Animated.Value(8)).current;

  useEffect(() => {
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
  }, [opacity, lift]);

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
