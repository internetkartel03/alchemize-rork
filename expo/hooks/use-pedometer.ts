import { useEffect, useState } from 'react';
import { Platform } from 'react-native';
import { Pedometer } from 'expo-sensors';

interface PedometerState {
  steps: number;
  isAvailable: boolean;
}

/**
 * Live step count for today using the device pedometer (expo-sensors).
 * - iOS: seeds with today's total via getStepCountAsync, then adds live updates.
 * - Android: counts steps live while the screen is open.
 * - Web / unavailable hardware: returns 0 with isAvailable=false (graceful fallback).
 */
export function usePedometer(): PedometerState {
  const [baseSteps, setBaseSteps] = useState<number>(0);
  const [liveSteps, setLiveSteps] = useState<number>(0);
  const [isAvailable, setIsAvailable] = useState<boolean>(false);

  useEffect(() => {
    if (Platform.OS === 'web') return;

    let cancelled = false;
    let subscription: { remove: () => void } | null = null;

    const start = async () => {
      try {
        const available = await Pedometer.isAvailableAsync();
        if (cancelled) return;
        setIsAvailable(available);
        if (!available) {
          console.log('[Pedometer] Not available on this device');
          return;
        }

        const permission = await Pedometer.requestPermissionsAsync();
        if (cancelled || permission.status !== 'granted') {
          console.log('[Pedometer] Permission not granted');
          return;
        }

        if (Platform.OS === 'ios') {
          try {
            const startOfDay = new Date();
            startOfDay.setHours(0, 0, 0, 0);
            const result = await Pedometer.getStepCountAsync(startOfDay, new Date());
            if (!cancelled && result) {
              setBaseSteps(result.steps);
            }
          } catch (error) {
            console.log('[Pedometer] Could not read today step count:', error);
          }
        }

        subscription = Pedometer.watchStepCount((result) => {
          if (!cancelled) {
            setLiveSteps(result.steps);
          }
        });
      } catch (error) {
        console.log('[Pedometer] Setup failed:', error);
      }
    };

    void start();

    return () => {
      cancelled = true;
      subscription?.remove();
    };
  }, []);

  return { steps: baseSteps + liveSteps, isAvailable };
}
