import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  WorkoutActivityType,
  WorkoutTypeIdentifier,
  isHealthDataAvailable,
  requestAuthorization,
  queryWorkoutSamples,
  saveWorkoutSample,
} from '@kingstinct/react-native-healthkit';
import type { WorkoutSession } from '@/types';

const ENABLED_KEY = '@alchemize_apple_health_enabled';
const LAST_SYNC_KEY = '@alchemize_apple_health_last_sync';
const SENT_KEY = '@alchemize_apple_health_sent';

const ACTIVE_ENERGY_IDENTIFIER = 'HKQuantityTypeIdentifierActiveEnergyBurned' as const;
const APP_BUNDLE_ID = 'app.repo.alchemize-level-up';
const IMPORT_DAYS = 7;

export interface AppleHealthSyncResult {
  success: boolean;
  imported: number;
  sent: number;
  message: string;
}

/**
 * Apple Health is a single switch: turning it on asks for read + write access and
 * keeps both sides in sync (Alchemize workouts out, HealthKit workouts in).
 */
export function isHealthKitSupported(): { supported: boolean; reason: string } {
  if (Platform.OS === 'web') {
    return {
      supported: false,
      reason: 'Apple Health only works in the iPhone app.',
    };
  }

  if (Platform.OS === 'android') {
    return {
      supported: false,
      reason: 'Apple Health is only available on iPhone.',
    };
  }

  if (!isHealthDataAvailable()) {
    return {
      supported: false,
      reason: 'Health data is not available on this device.',
    };
  }

  return { supported: true, reason: 'Apple Health is available.' };
}

export async function isAppleHealthEnabled(): Promise<boolean> {
  try {
    if (!isHealthKitSupported().supported) return false;
    return (await AsyncStorage.getItem(ENABLED_KEY)) === '1';
  } catch {
    return false;
  }
}

export async function getLastSyncTime(): Promise<string | null> {
  try {
    return await AsyncStorage.getItem(LAST_SYNC_KEY);
  } catch {
    return null;
  }
}

async function setLastSyncTime(time: string): Promise<void> {
  try {
    await AsyncStorage.setItem(LAST_SYNC_KEY, time);
  } catch (error) {
    console.error('[AppleHealth] Error saving last sync time:', error);
  }
}

/** Turns the switch on: asks for access once, then runs the first sync. */
export async function connectAppleHealth(): Promise<AppleHealthSyncResult> {
  const { supported, reason } = isHealthKitSupported();
  if (!supported) {
    return { success: false, imported: 0, sent: 0, message: reason };
  }

  const granted = await requestAuthorization({
    toRead: [ACTIVE_ENERGY_IDENTIFIER, WorkoutTypeIdentifier],
    toShare: [ACTIVE_ENERGY_IDENTIFIER, WorkoutTypeIdentifier],
  });

  if (!granted) {
    return {
      success: false,
      imported: 0,
      sent: 0,
      message: 'Apple Health access was not granted. You can change this in the Health app.',
    };
  }

  await AsyncStorage.setItem(ENABLED_KEY, '1');
  return syncWithAppleHealth();
}

/** Turns the switch off: stops all syncing. Health access itself stays managed by iOS. */
export async function disconnectAppleHealth(): Promise<void> {
  try {
    await AsyncStorage.removeItem(ENABLED_KEY);
    await AsyncStorage.removeItem(LAST_SYNC_KEY);
  } catch (error) {
    console.error('[AppleHealth] Error disconnecting:', error);
  }
}

/** Both directions in one call: send new Alchemize workouts out, pull HealthKit ones in. */
export async function syncWithAppleHealth(): Promise<AppleHealthSyncResult> {
  if (!(await isAppleHealthEnabled())) {
    return { success: false, imported: 0, sent: 0, message: 'Apple Health is off.' };
  }

  try {
    const sent = await sendWorkoutsToHealth();
    const imported = await pullWorkoutsFromHealth();
    await setLastSyncTime(new Date().toISOString());

    return {
      success: true,
      imported,
      sent,
      message: buildMessage(imported, sent),
    };
  } catch (error) {
    console.error('[AppleHealth] Sync failed:', error);
    return { success: false, imported: 0, sent: 0, message: 'Could not sync with Apple Health.' };
  }
}

/** Quiet background sync used on screen mount — never blocks or alerts. */
export async function syncAppleHealthInBackground(): Promise<void> {
  if (!(await isAppleHealthEnabled())) return;
  await syncWithAppleHealth();
}

/** Sends a single just-finished workout to Apple Health (no-op when the switch is off). */
export async function sendWorkoutToAppleHealth(session: WorkoutSession): Promise<void> {
  if (!(await isAppleHealthEnabled())) return;

  try {
    const sent = await getSentIds();
    if (sent.has(session.id)) return;
    await saveSession(session);
    await markSent(session.id, sent);
    await setLastSyncTime(new Date().toISOString());
  } catch (error) {
    console.error('[AppleHealth] Could not send workout:', error);
  }
}

function buildMessage(imported: number, sent: number): string {
  const parts: string[] = [];
  if (sent > 0) parts.push(`sent ${sent} workout${sent === 1 ? '' : 's'}`);
  if (imported > 0) parts.push(`brought in ${imported} workout${imported === 1 ? '' : 's'}`);
  if (parts.length === 0) return 'Everything is up to date';
  return `Synced: ${parts.join(', ')}`;
}

async function getSentIds(): Promise<Set<string>> {
  try {
    const stored = await AsyncStorage.getItem(SENT_KEY);
    return new Set<string>(stored ? (JSON.parse(stored) as string[]) : []);
  } catch {
    return new Set<string>();
  }
}

async function markSent(id: string, sent: Set<string>): Promise<void> {
  sent.add(id);
  // Keep only the most recent ids so the stored list cannot grow forever.
  const trimmed = Array.from(sent).slice(-500);
  await AsyncStorage.setItem(SENT_KEY, JSON.stringify(trimmed));
}

// ── Sending Alchemize workouts to Apple Health ──────────────────────────────

const CATEGORY_ACTIVITY_TYPE: Record<string, WorkoutActivityType> = {
  strength: WorkoutActivityType.traditionalStrengthTraining,
  hiit: WorkoutActivityType.highIntensityIntervalTraining,
  yoga: WorkoutActivityType.yoga,
  core: WorkoutActivityType.coreTraining,
  mobility: WorkoutActivityType.flexibility,
  stretch: WorkoutActivityType.flexibility,
  walk: WorkoutActivityType.walking,
  run: WorkoutActivityType.running,
};

async function sendWorkoutsToHealth(): Promise<number> {
  const sent = await getSentIds();
  const { workoutSessionsDb, workoutTemplatesDb } = await import('./database');

  const [sessions, templates] = await Promise.all([
    workoutSessionsDb.getAll(),
    workoutTemplatesDb.getAll(),
  ]);
  const categoryByTemplate = new Map(templates.map((t) => [t.id, t.category]));

  const pending = sessions.filter(
    (s) => s.completed && s.source === 'manual' && !sent.has(s.id) && !s.id.startsWith('healthkit_')
  );

  let count = 0;
  for (const session of pending) {
    await saveSession(session, categoryByTemplate.get(session.templateId));
    await markSent(session.id, sent);
    count++;
  }
  return count;
}

async function saveSession(session: WorkoutSession, category?: string): Promise<void> {
  const startDate = new Date(session.startedAt);
  const endDate = new Date(session.endedAt ?? session.startedAt + session.durationMinutes * 60_000);
  const activityType = (category && CATEGORY_ACTIVITY_TYPE[category]) || WorkoutActivityType.other;

  const quantities = session.caloriesEstimate
    ? [
        {
          quantityType: ACTIVE_ENERGY_IDENTIFIER,
          quantity: session.caloriesEstimate,
          unit: 'kcal',
          startDate,
          endDate,
        },
      ]
    : [];

  await saveWorkoutSample(activityType, quantities, startDate, endDate);
}

// ── Bringing HealthKit workouts into Alchemize ──────────────────────────────

async function pullWorkoutsFromHealth(): Promise<number> {
  const endDate = new Date();
  const startDate = new Date(endDate.getTime() - IMPORT_DAYS * 24 * 60 * 60 * 1000);

  const workouts = await queryWorkoutSamples({
    filter: { date: { startDate, endDate } },
    limit: 0,
    ascending: false,
  });

  const { workoutSessionsDb, normalizedMetricsDb } = await import('./database');

  let imported = 0;
  for (const workout of workouts) {
    // Workouts Alchemize already sent to Apple Health are already in the app.
    if (workout.sourceRevision?.source?.bundleIdentifier === APP_BUNDLE_ID) continue;

    const id = `healthkit_${workout.uuid}`;
    if (await workoutSessionsDb.getById(id)) continue;

    const minutes = Math.max(1, Math.round(workout.duration.quantity));
    const calories = workout.totalEnergyBurned ? Math.round(workout.totalEnergyBurned.quantity) : null;
    const startedAt = workout.startDate.getTime();

    await workoutSessionsDb.create({
      id,
      templateId: 'healthkit',
      startedAt,
      endedAt: workout.endDate.getTime(),
      durationMinutes: minutes,
      completed: true,
      caloriesEstimate: calories,
      source: 'wearable',
    });

    const dateStr = workout.startDate.toISOString().split('T')[0];
    await normalizedMetricsDb.upsert({
      id: `healthkit_${dateStr}`,
      date: dateStr,
      activeMinutes: minutes,
      caloriesActive: calories ?? 0,
      steps: 0,
      source: 'wearable',
      deviceType: 'none',
    });

    imported++;
  }

  return imported;
}


