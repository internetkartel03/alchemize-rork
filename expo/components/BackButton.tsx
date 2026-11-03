import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { usePathname, useRouter } from 'expo-router';
import { ChevronLeft } from 'lucide-react-native';
import { TouchableOpacity } from '@/components/HapticTouchable';

/** Routes that are entry points and should never show a back affordance. */
const ROOT_ROUTES = new Set(['/', '/index', '/auth', '/reset-password']);

interface BackButtonProps {
  /** Optional explicit destination when there is no history to pop. */
  fallbackHref?: string;
  label?: string;
}

/**
 * Global header back control. Always rendered on non-root screens so a fresh
 * load / deep link (where the stack has a single entry) still has a way back;
 * in that case it lands on the home screen instead of doing nothing.
 */
export default function BackButton({ fallbackHref = '/', label = 'Back' }: BackButtonProps) {
  const router = useRouter();
  const pathname = usePathname();

  if (ROOT_ROUTES.has(pathname)) return null;

  const handlePress = () => {
    if (router.canGoBack()) {
      router.back();
      return;
    }
    router.replace(fallbackHref as any);
  };

  return (
    <TouchableOpacity
      onPress={handlePress}
      style={styles.pressable}
      activeOpacity={0.7}
      testID="global-back-button"
    >
      <View style={styles.pill}>
        <ChevronLeft color="#ffffff" size={18} strokeWidth={2.6} />
        <Text style={styles.label}>{label}</Text>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  pressable: {
    paddingVertical: 4,
    paddingRight: 8,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
    paddingLeft: 4,
    paddingRight: 12,
    paddingVertical: 6,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.10)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.16)',
  },
  label: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '600' as const,
    letterSpacing: 0.2,
  },
});
