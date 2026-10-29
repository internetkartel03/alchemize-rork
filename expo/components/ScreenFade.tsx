import React, { useEffect, useRef } from 'react';
import { Animated, StyleProp, ViewStyle } from 'react-native';

interface ScreenFadeProps {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  /** Delay before the entrance starts, in ms. */
  delay?: number;
}

/**
 * Soft fade-and-rise entrance for screen content — matches the premium
 * motion language used on the home and settings screens.
 */
export default function ScreenFade({ children, style, delay = 0 }: ScreenFadeProps) {
  const fade = useRef(new Animated.Value(0)).current;
  const rise = useRef(new Animated.Value(12)).current;

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fade, {
        toValue: 1,
        duration: 320,
        delay,
        useNativeDriver: true,
      }),
      Animated.spring(rise, {
        toValue: 0,
        delay,
        useNativeDriver: true,
        speed: 14,
        bounciness: 4,
      }),
    ]).start();
  }, [fade, rise, delay]);

  return (
    <Animated.View style={[{ flex: 1 }, style, { opacity: fade, transform: [{ translateY: rise }] }]}>
      {children}
    </Animated.View>
  );
}
