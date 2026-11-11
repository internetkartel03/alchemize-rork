import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  WorkoutActivityType,
  WorkoutTypeIdentifier,
  isHealthDataAvailable,
  requestAuthorization,
  queryWorkoutSamples,
  queryQuantitySamples,
  saveWorkoutSample,
  saveQuantitySample,
} from '@kingstinct/react-native-healthkit';
import type { FoodLog, WaterLog, WorkoutSession } from '@/types';

const ENABLED_KEY = '@alchemize_apple_health_enabled';
const LAST_SYNC_KEY = '@alchemize_apple_health_last_sync';
const SENT_KEY = '@alchemize_apple_health_sent';
const NUTRITION_SENT_KEY = '@alchemize_apple_health_nutrition_sent';

const ACTIVE_ENERGY_IDENTIFIER = 'HKQuantityTypeIdentifierActiveEnergyBurned' as const;

const DIETARY_ENERGY_IDENTIFIER = 'HKQuantityTypeIdentifierDietaryEnergyConsumed' as const;
const DIETARY_PROTEIN_IDENTIFIER = 'HKQuantityTypeIdentifierDietaryProtein' as const;
const DIETARY_CARBS_IDENTIFIER = 'HKQuantityTypeIdentifierDietaryCarbohydrates' as const;
const DIETARY_FAT_IDENTIFIER = 'HKQuantityTypeIdentifierDietaryFatTotal' as const;
const DIETARY_SUGAR_IDENTIFIER = 'HKQuantityTypeIdentifierDietarySugar' as const;
const DIETARY_FIBER_IDENTIFIER = 'HKQuantityTypeIdentifierDietaryFiber' as const;
const DIETARY_WATER_IDENTIFIER = 'HKQuantityTypeIdentifierDietaryWater' as const;

const DIETARY_IDENTIFIERS = [
  DIETARY_ENERGY_IDENTIFIER,
  DIETARY_PROTEIN_IDENTIFIER,
  DIETARY_CARBS_IDENTIFIER,
  DIETARY_FAT_IDENTIFIER,
  DIETARY_SUGAR_IDENTIFIER,
  DIETARY_FIBER_IDENTIFIER,
  DIETARY_WATER_IDENTIFIER,
];

const HEALTHKIT_READ_TYPES = [ACTIVE_ENERGY_IDENTIFIER, WorkoutTypeIdentifier, ...DIETARY_IDENTIFIERS];
const HEALTHKIT_SHARE_TYPES = [ACTIVE_ENERGY_IDENTIFIER, WorkoutTypeIdentifier, ...DIETARY_IDENTIFIERS];

const APP_BUNDLE_ID = 'app.repo.alchemize-level-up';
const IMPORT_DAYS = 7;
const MINUTE_MS = 60_000;
const ML_PER_OUNCE = 29.5735;

export interface AppleHealthSyncResult {
  success: boolean;
  imported: number;
  sent: number;
  nutritionImported: number;
  nutritionSent: number;
  message: string;
}

/**
 * Apple Health is a single switch: turning it on asks for read + write access and
 * keeps both sides in sync — workouts and nutrition out, HealthKit data in.
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
    return emptyResult(reason);
  }

  const granted = await requestAuthorization({
    toRead: HEALTHKIT_READ_TYPES,
    toShare: HEALTHKIT_SHARE_TYPES,
  });

  if (!granted) {
    return emptyResult(
      'Apple Health access was not granted. You can change this in the Health app.'
    );
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

/** Both directions in one call: send new Alchemize data out, pull HealthKit data in. */
export async function syncWithAppleHealth(): Promise<AppleHealthSyncResult> {
  if (!(await isAppleHealthEnabled())) {
    return emptyResult('Apple Health is off.');
  }

  try {
    const sent = await sendWorkoutsToHealth();
    const imported = await pullWorkoutsFromHealth();
    const nutritionSent = await sendNutritionToHealth();
    const nutritionImported = await pullNutritionFromHealth();
    await setLastSyncTime(new Date().toISOString());

    return {
      success: true,
      imported,
      sent,
      nutritionImported,
      nutritionSent,
      message: buildMessage(imported, sent, nutritionImported, nutritionSent),
    };
  } catch (error) {
    console.error('[AppleHealth] Sync failed:', error);
    return emptyResult('Could not sync with Apple Health.');
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
    const sent = await getSentIds(SENT_KEY);
    if (sent.has(session.id)) return;
    await saveSession(session);
    await markSent(session.id, sent);
    await setLastSyncTime(new Date().toISOString());
  } catch (error) {
    console.error('[AppleHealth] Could not send workout:', error);
  }
}

/** Sends a single just-logged food to Apple Health (no-op when the switch is off). */
export async function sendFoodLogToAppleHealth(log: FoodLog): Promise<void> {
  if (!(await isAppleHealthEnabled())) return;

  try {
    const sent = await getSentIds(NUTRITION_SENT_KEY);
    const key = `food_${log.id}`;
    if (sent.has(key)) return;
    await saveFoodLog(log);
    await markSent(key, sent, NUTRITION_SENT_KEY);
    await setLastSyncTime(new Date().toISOString());
  } catch (error) {
    console.error('[AppleHealth] Could not send food log:', error);
  }
}

function emptyResult(message: string): AppleHealthSyncResult {
  return {
    success: false,
    imported: 0,
    sent: 0,
    nutritionImported: 0,
    nutritionSent: 0,
    message,
  };
}

function buildMessage(
  imported: number,
  sent: number,
  nutritionImported: number,
  nutritionSent: number
): string {
  const parts: string[] = [];
  if (sent > 0) parts.push(`sent ${sent} workout${sent === 1 ? '' : 's'}`);
  if (imported > 0) parts.push(`brought in ${imported} workout${imported === 1 ? '' : 's'}`);
  if (nutritionSent > 0) parts.push(`sent ${nutritionSent} nutrition entr${nutritionSent === 1 ? 'y' : 'ies'}`);
  if (nutritionImported > 0) {
    parts.push(`brought in ${nutritionImported} nutrition entr${nutritionImported === 1 ? 'y' : 'ies'}`);
  }
  if (parts.length === 0) return 'Everything is up to date';
  return `Synced: ${parts.join(', ')}`;
}

async function getSentIds(key: string): Promise<Set<string>> {
  try {
    const stored = await AsyncStorage.getItem(key);
    return new Set<string>(stored ? (JSON.parse(stored) as string[]) : []);
  } catch {
    return new Set<string>();
  }
}

async function markSent(id: string, sent: Set<string>, key: string = SENT_KEY): Promise<void> {
  sent.add(id);
  // Keep only the most recent ids so the stored list cannot grow forever.
  const trimmed = Array.from(sent).slice(-500);
  await AsyncStorage.setItem(key, JSON.stringify(trimmed));
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
  const sent = await getSentIds(SENT_KEY);
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

// ── Sending Alchemize nutrition to Apple Health ─────────────────────────────

async function sendNutritionToHealth(): Promise<number> {
  const sent = await getSentIds(NUTRITION_SENT_KEY);
  const { foodLogsDb, waterLogsDb } = await import('./database');

  const [foodLogs, waterLogs] = await Promise.all([foodLogsDb.getAll(), waterLogsDb.getAll()]);

  let count = 0;
  for (const log of foodLogs) {
    // Entries that came from HealthKit are already there.
    if (log.id.startsWith('healthkit_')) continue;

    const key = `food_${log.id}`;
    if (sent.has(key)) continue;

    await saveFoodLog(log);
    await markSent(key, sent, NUTRITION_SENT_KEY);
    count++;
  }

  for (const log of waterLogs) {
    const key = `water_${log.id}`;
    if (sent.has(key)) continue;

    await saveWaterLog(log);
    await markSent(key, sent, NUTRITION_SENT_KEY);
    count++;
  }

  return count;
}

async function saveFoodLog(log: FoodLog): Promise<void> {
  const startDate = new Date(log.loggedAt);
  const endDate = new Date(log.loggedAt + MINUTE_MS);

  if (log.calories > 0) {
    await saveQuantitySample(DIETARY_ENERGY_IDENTIFIER, 'kcal', log.calories, startDate, endDate);
  }
  if (log.proteinGrams) {
    await saveQuantitySample(DIETARY_PROTEIN_IDENTIFIER, 'g', log.proteinGrams, startDate, endDate);
  }
  if (log.carbGrams) {
    await saveQuantitySample(DIETARY_CARBS_IDENTIFIER, 'g', log.carbGrams, startDate, endDate);
  }
  if (log.fatGrams) {
    await saveQuantitySample(DIETARY_FAT_IDENTIFIER, 'g', log.fatGrams, startDate, endDate);
  }
  if (log.sugarGrams) {
    await saveQuantitySample(DIETARY_SUGAR_IDENTIFIER, 'g', log.sugarGrams, startDate, endDate);
  }
  if (log.fiberGrams) {
    await saveQuantitySample(DIETARY_FIBER_IDENTIFIER, 'g', log.fiberGrams, startDate, endDate);
  }
}

async function saveWaterLog(log: WaterLog): Promise<void> {
  const milliliters = log.unit === 'oz' ? log.amount * ML_PER_OUNCE : log.amount;
  if (milliliters <= 0) return;

  const startDate = new Date(log.loggedAt);
  const endDate = new Date(log.loggedAt + MINUTE_MS);
  await saveQuantitySample(DIETARY_WATER_IDENTIFIER, 'mL', milliliters, startDate, endDate);
}

// ── Bringing HealthKit nutrition into Alchemize ─────────────────────────────

const MEAL_TYPES: FoodLog['mealType'][] = ['breakfast', 'lunch', 'dinner', 'snack'];
const MEAL_HOURS: Record<FoodLog['mealType'], number> = {
  breakfast: 8,
  lunch: 12,
  dinner: 18,
  snack: 15,
};

async function pullNutritionFromHealth(): Promise<number> {
  const endDate = new Date();
  const startDate = new Date(endDate.getTime() - IMPORT_DAYS * 24 * 60 * 60 * 1000);

  const samples = await queryQuantitySamples(DIETARY_ENERGY_IDENTIFIER, {
    filter: { date: { startDate, endDate } },
    limit: 0,
    ascending: false,
    unit: 'kcal',
  });

  const { foodLogsDb } = await import('./database');

  let imported = 0;
  for (const sample of samples) {
    // Nutrition Alchemize already sent to Apple Health is already in the app.
    if (sample.sourceRevision?.source?.bundleIdentifier === APP_BUNDLE_ID) continue;

    const id = `healthkit_nutrition_${sample.uuid}`;
    if (await foodLogsDb.getById(id)) continue;

    await foodLogsDb.create({
      id,
      foodName: 'Apple Health entry',
      servingDescription: 'Synced from Apple Health',
      calories: Math.round(sample.quantity),
      proteinGrams: null,
      carbGrams: null,
      fatGrams: null,
      sugarGrams: null,
      fiberGrams: null,
      mealType: mealTypeFor(sample.startDate),
      sourceType: 'health',
      loggedAt: sample.startDate.getTime(),
      isLocked: false,
      calendarEventId: null,
    });

    imported++;
  }

  return imported;
}

/** Picks the closest meal for a HealthKit sample that only carries a timestamp. */
function mealTypeFor(date: Date): FoodLog['mealType'] {
  const hour = date.getHours();
  return MEAL_TYPES.reduce((closest, type) =>
    Math.abs(MEAL_HOURS[type] - hour) < Math.abs(MEAL_HOURS[closest] - hour) ? type : closest
  );
}
