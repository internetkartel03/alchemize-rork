import React, { useRef, useCallback } from 'react';
import {
  Animated,
  Pressable,
  PressableProps,
  StyleProp,
  ViewStyle,
  GestureResponderEvent,
} from 'react-native';
import { hapticLight } from '@/lib/haptics';

const AnimatedPressable = Animated.createAnimatedComponent(Pressable);

export interface HapticTouchableProps extends Omit<PressableProps, 'style'> {
  /** Opacity when pressed. Mirrors TouchableOpacity's prop. */
  activeOpacity?: number;
  style?: StyleProp<ViewStyle>;
  /** Fire a light haptic on press. Defaults to true. */
  haptic?: boolean;
  children?: React.ReactNode;
}

/**
 * Drop-in replacement for React Native's TouchableOpacity that adds the
 * native iOS "squish" spring scale, a soft opacity dip, and light haptic
 * feedback on every press. Same API surface, premium feel.
 */
export function TouchableOpacity({
  activeOpacity = 0.9,
  style,
  haptic = true,
  onPress,
  onPressIn,
  onPressOut,
  disabled,
  children,
  ...rest
}: HapticTouchableProps) {
  const scale = useRef(new Animated.Value(1)).current;
  const opacity = useRef(new Animated.Value(1)).current;

  const handlePressIn = useCallback(
    (event: GestureResponderEvent) => {
      Animated.parallel([
        Animated.spring(scale, {
          toValue: 0.97,
          useNativeDriver: true,
          speed: 50,
          bounciness: 0,
        }),
        Animated.timing(opacity, {
          toValue: activeOpacity,
          duration: 80,
          useNativeDriver: true,
        }),
      ]).start();
      onPressIn?.(event);
    },
    [scale, opacity, activeOpacity, onPressIn]
  );

  const handlePressOut = useCallback(
    (event: GestureResponderEvent) => {
      Animated.parallel([
        Animated.spring(scale, {
          toValue: 1,
          useNativeDriver: true,
          speed: 30,
          bounciness: 6,
        }),
        Animated.timing(opacity, {
          toValue: 1,
          duration: 120,
          useNativeDriver: true,
        }),
      ]).start();
      onPressOut?.(event);
    },
    [scale, opacity, onPressOut]
  );

  const handlePress = useCallback(
    (event: GestureResponderEvent) => {
      if (haptic) hapticLight();
      onPress?.(event);
    },
    [haptic, onPress]
  );

  return (
    <AnimatedPressable
      {...rest}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      onPress={handlePress}
      disabled={disabled}
      style={[style, { transform: [{ scale }], opacity }]}
    >
      {children}
    </AnimatedPressable>
  );
}

export default TouchableOpacity;
