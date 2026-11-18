import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  AuthorizationRequestStatus,
  AuthorizationStatus,
  WorkoutActivityType,
  WorkoutTypeIdentifier,
  authorizationStatusFor,
  getRequestStatusForAuthorization,
  isHealthDataAvailable,
  queryWorkoutSamplesWithAnchor,
  queryQuantitySamplesWithAnchor,
  requestAuthorization,
  saveQuantitySample,
  saveWorkoutSample,
} from '@kingstinct/react-native-healthkit';
import type { FoodLog, WaterLog, WorkoutSession } from '@/types';

const ENABLED_KEY = '@alchemize_apple_health_enabled';
const LAST_SYNC_KEY = '@alchemize_apple_health_last_sync';
const WORKOUT_ANCHOR_KEY = '@alchemize_apple_health_anchor_workouts';
const NUTRITION_ANCHOR_KEY = '@alchemize_apple_health_anchor_nutrition';
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
const DAY_MS = 24 * 60 * 60 * 1000;
const MINUTE_MS = 60_000;
const ML_PER_OUNCE = 29.5735;
/** Background/foreground syncs closer together than this are skipped. */
const BACKGROUND_SYNC_INTERVAL_MS = 60_000;

export type AppleHealthAuthorization = 'granted' | 'notDetermined' | 'denied' | 'unknown';

export interface AppleHealthStatus {
  supported: boolean;
  reason: string;
  /** The user's switch value — a persisted preference, not proof of permission. */
  enabled: boolean;
  authorization: AppleHealthAuthorization;
  /** True when the switch is on but Apple still needs the user to grant access. */
  needsPermission: boolean;
  lastSyncedAt: string | null;
}

export interface AppleHealthSyncResult {
  success: boolean;
  /** Some directions worked and others did not — data is safe, the sync is incomplete. */
  partial: boolean;
  imported: number;
  sent: number;
  nutritionImported: number;
  nutritionSent: number;
  needsPermission: boolean;
  message: string;
}

/**
 * Apple Health is a single switch: turning it on asks for read + write access and
 * keeps both sides in sync — Alchemize workouts and nutrition out, HealthKit data in.
 *
 * HealthKit never reveals whether read access was granted (Apple's privacy model):
 * `getRequestStatusForAuthorization` only tells us whether the permission sheet has
 * been shown. Write access for workouts is the one status iOS exposes, so that is
 * what the "denied" state is based on.
 */
export function isHealthKitSupported(): { supported: boolean; reason: string } {
  if (Platform.OS === 'web') {
    return { supported: false, reason: 'Apple Health only works in the iPhone app.' };
  }

  if (Platform.OS === 'android') {
    return { supported: false, reason: 'Apple Health is only available on iPhone.' };
  }

  if (!isHealthDataAvailable()) {
    return { supported: false, reason: 'Health data is not available on this device.' };
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

/** Authorization and connection state, read without ever prompting the user. */
export async function getAppleHealthStatus(): Promise<AppleHealthStatus> {
  const { supported, reason } = isHealthKitSupported();
  const enabled = supported ? await isAppleHealthEnabled() : false;
  const lastSyncedAt = await getLastSyncTime();

  if (!supported) {
    return { supported, reason, enabled: false, authorization: 'unknown', needsPermission: false, lastSyncedAt };
  }

  const authorization = await readAuthorization();
  return {
    supported,
    reason,
    enabled,
    authorization,
    needsPermission: enabled && (authorization === 'notDetermined' || authorization === 'denied'),
    lastSyncedAt,
  };
}

async function readAuthorization(): Promise<AppleHealthAuthorization> {
  try {
    if (authorizationStatusFor(WorkoutTypeIdentifier) === AuthorizationStatus.sharingDenied) {
      return 'denied';
    }

    const status = await getRequestStatusForAuthorization({
      toRead: HEALTHKIT_READ_TYPES,
      toShare: HEALTHKIT_SHARE_TYPES,
    });

    if (status === AuthorizationRequestStatus.unnecessary) return 'granted';
    if (status === AuthorizationRequestStatus.shouldRequest) return 'notDetermined';
    return 'unknown';
  } catch (error) {
    console.error('[AppleHealth] Could not read authorization status:', error);
    return 'unknown';
  }
}

/** Turns the switch on: asks for access once, then runs the first sync. */
export async function connectAppleHealth(): Promise<AppleHealthSyncResult> {
  const { supported, reason } = isHealthKitSupported();
  if (!supported) return emptyResult(reason);

  let granted = false;
  try {
    granted = await requestAuthorization({
      toRead: HEALTHKIT_READ_TYPES,
      toShare: HEALTHKIT_SHARE_TYPES,
    });
  } catch (error) {
    console.error('[AppleHealth] Authorization request failed:', error);
    return { ...emptyResult('Could not ask Apple Health for access.'), needsPermission: true };
  }

  if (!granted) {
    return {
      ...emptyResult('Apple Health access was not granted. You can change this in the Health app.'),
      needsPermission: true,
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

// ── Sync coordination ───────────────────────────────────────────────────────

let inFlightSync: Promise<AppleHealthSyncResult> | null = null;
let lastAttemptAt = 0;

/**
 * One sync at a time: a second call while a sync runs shares the same promise
 * instead of starting a competing one.
 *
 * `allowPrompt` is only true for an explicit user action (the switch or tapping
 * Sync Now), because asking for access unprompted is not allowed. iOS never shows
 * the sheet twice for a type the user already decided, so this cannot nag.
 */
export function syncWithAppleHealth(
  options: { allowPrompt?: boolean } = {}
): Promise<AppleHealthSyncResult> {
  if (inFlightSync) return inFlightSync;

  inFlightSync = runSync(options.allowPrompt === true).finally(() => {
    inFlightSync = null;
  });
  return inFlightSync;
}

async function runSync(allowPrompt: boolean): Promise<AppleHealthSyncResult> {
  if (!(await isAppleHealthEnabled())) {
    return emptyResult('Apple Health is off.');
  }

  const support = isHealthKitSupported();
  if (!support.supported) return emptyResult(support.reason);

  let authorization = await readAuthorization();

  // A newly requested data type (or a reinstall) leaves the sheet unshown; only an
  // explicit user sync may request it. Background syncs report action required.
  if (authorization === 'notDetermined' && allowPrompt) {
    try {
      const granted = await requestAuthorization({
        toRead: HEALTHKIT_READ_TYPES,
        toShare: HEALTHKIT_SHARE_TYPES,
      });
      if (!granted) {
        return {
          ...emptyResult('Apple Health access was not granted. You can change this in the Health app.'),
          needsPermission: true,
        };
      }
      authorization = await readAuthorization();
    } catch (error) {
      console.error('[AppleHealth] Authorization request failed:', error);
    }
  }

  if (authorization === 'notDetermined') {
    return {
      ...emptyResult('Apple Health needs permission. Open the Apple Health row and sync again to allow access.'),
      needsPermission: true,
    };
  }
  if (authorization === 'denied') {
    return {
      ...emptyResult('Apple Health access is turned off. You can re-enable it in the Health app.'),
      needsPermission: true,
    };
  }

  lastAttemptAt = Date.now();

  const failures: string[] = [];
  const counts = { sent: 0, imported: 0, nutritionSent: 0, nutritionImported: 0 };

  try {
    counts.sent = await sendWorkoutsToHealth();
  } catch (error) {
    console.error('[AppleHealth] Sending workouts failed:', error);
    failures.push('workouts could not be sent');
  }

  try {
    counts.imported = await pullWorkoutsFromHealth();
  } catch (error) {
    console.error('[AppleHealth] Importing workouts failed:', error);
    failures.push('workouts could not be imported');
  }

  try {
    counts.nutritionSent = await sendNutritionToHealth();
  } catch (error) {
    console.error('[AppleHealth] Sending nutrition failed:', error);
    failures.push('nutrition could not be sent');
  }

  try {
    counts.nutritionImported = await pullNutritionFromHealth();
  } catch (error) {
    console.error('[AppleHealth] Importing nutrition failed:', error);
    failures.push('nutrition could not be imported');
  }

  // Only a fully successful sync moves the "last synced" timestamp forward.
  const success = failures.length === 0;
  if (success) {
    await setLastSyncTime(new Date().toISOString());
  } else {
    const moved =
      counts.sent + counts.imported + counts.nutritionSent + counts.nutritionImported > 0;
    return {
      ...counts,
      success: false,
      partial: moved,
      needsPermission: false,
      message: moved
        ? `Synced what it could: ${failures.join(', ')}. Your saved data is safe — try again later.`
        : 'Could not sync with Apple Health. Your saved data is safe — try again later.',
    };
  }

  return {
    ...counts,
    success,
    partial: false,
    needsPermission: false,
    message: buildMessage(counts),
  };
}

/** Quiet background sync used on launch/foreground — never blocks or alerts. */
export async function syncAppleHealthInBackground(): Promise<void> {
  if (!(await isAppleHealthEnabled())) return;
  if (Date.now() - lastAttemptAt < BACKGROUND_SYNC_INTERVAL_MS) return;
  await syncWithAppleHealth();
}

function emptyResult(message: string): AppleHealthSyncResult {
  return {
    success: false,
    partial: false,
    imported: 0,
    sent: 0,
    nutritionImported: 0,
    nutritionSent: 0,
    needsPermission: false,
    message,
  };
}

function buildMessage(counts: {
  imported: number;
  sent: number;
  nutritionImported: number;
  nutritionSent: number;
}): string {
  const parts: string[] = [];
  if (counts.sent > 0) parts.push(`sent ${counts.sent} workout${counts.sent === 1 ? '' : 's'}`);
  if (counts.imported > 0) {
    parts.push(`brought in ${counts.imported} workout${counts.imported === 1 ? '' : 's'}`);
  }
  if (counts.nutritionSent > 0) {
    parts.push(`sent ${counts.nutritionSent} nutrition entr${counts.nutritionSent === 1 ? 'y' : 'ies'}`);
  }
  if (counts.nutritionImported > 0) {
    parts.push(
      `brought in ${counts.nutritionImported} nutrition entr${counts.nutritionImported === 1 ? 'y' : 'ies'}`
    );
  }
  if (parts.length === 0) return 'Everything is up to date';
  return `Synced: ${parts.join(', ')}`;
}

/** Sends a single just-finished workout to Apple Health (no-op when the switch is off). */
export async function sendWorkoutToAppleHealth(session: WorkoutSession): Promise<void> {
  if (!(await isAppleHealthEnabled())) return;

  try {
    const sent = await getSentIds(SENT_KEY);
    if (sent.has(session.id)) return;
    await saveSession(session);
    await markSent(session.id, sent, SENT_KEY);
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

async function getSentIds(key: string): Promise<Set<string>> {
  try {
    const stored = await AsyncStorage.getItem(key);
    return new Set<string>(stored ? (JSON.parse(stored) as string[]) : []);
  } catch {
    return new Set<string>();
  }
}

async function markSent(id: string, sent: Set<string>, key: string): Promise<void> {
  sent.add(id);
  // Keep only the most recent ids so the stored list cannot grow forever.
  const trimmed = Array.from(sent).slice(-500);
  await AsyncStorage.setItem(key, JSON.stringify(trimmed));
}

async function readAnchor(key: string): Promise<string | undefined> {
  try {
    return (await AsyncStorage.getItem(key)) || undefined;
  } catch {
    return undefined;
  }
}

async function writeAnchor(key: string, anchor: string | undefined): Promise<void> {
  if (!anchor) return;
  try {
    await AsyncStorage.setItem(key, anchor);
  } catch (error) {
    console.error('[AppleHealth] Could not save sync anchor:', error);
  }
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
  let failed = 0;
  for (const session of pending) {
    try {
      await saveSession(session, categoryByTemplate.get(session.templateId));
      await markSent(session.id, sent, SENT_KEY);
      count++;
    } catch (error) {
      // One malformed session must not block the rest of the queue.
      console.error('[AppleHealth] Could not send session', session.id, error);
      failed++;
    }
  }

  if (failed > 0 && count === 0) {
    throw new Error(`${failed} workout${failed === 1 ? '' : 's'} could not be saved to Health`);
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
  const anchor = await readAnchor(WORKOUT_ANCHOR_KEY);
  const endDate = new Date();
  const startDate = new Date(endDate.getTime() - IMPORT_DAYS * DAY_MS);

  const response = await queryWorkoutSamplesWithAnchor({
    // A stored anchor already limits the query to samples we have not seen yet.
    filter: anchor ? undefined : { date: { startDate, endDate } },
    limit: 0,
    anchor,
  });

  const { workoutSessionsDb, normalizedMetricsDb } = await import('./database');

  let imported = 0;
  for (const workout of response.workouts) {
    // Workouts Alchemize already sent to Apple Health are already in the app.
    if (workout.sourceRevision?.source?.bundleIdentifier === APP_BUNDLE_ID) continue;

    const id = `healthkit_${workout.uuid}`;
    if (await workoutSessionsDb.getById(id)) continue;

    const rawDuration = workout.duration?.quantity;
    const fallbackDuration = (workout.endDate.getTime() - workout.startDate.getTime()) / MINUTE_MS;
    const minutes =
      Number.isFinite(rawDuration) && rawDuration > 0
        ? Math.max(1, Math.round(rawDuration))
        : Math.max(1, Math.round(fallbackDuration));
    const calories =
      workout.totalEnergyBurned && Number.isFinite(workout.totalEnergyBurned.quantity)
        ? Math.round(workout.totalEnergyBurned.quantity)
        : null;
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

  await writeAnchor(WORKOUT_ANCHOR_KEY, response.newAnchor);
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

/**
 * Writes one food entry's macros. Only the energy sample is treated as required:
 * a type the user did not allow to write is skipped instead of failing the sync.
 */
async function saveFoodLog(log: FoodLog): Promise<void> {
  const startDate = new Date(log.loggedAt);
  const endDate = new Date(log.loggedAt + MINUTE_MS);

  if (log.calories > 0) {
    await saveQuantitySample(DIETARY_ENERGY_IDENTIFIER, 'kcal', log.calories, startDate, endDate);
  }

  const macros: Array<{ label: string; value: number | null; save: () => Promise<unknown> }> = [
    {
      label: 'protein',
      value: log.proteinGrams,
      save: () => saveQuantitySample(DIETARY_PROTEIN_IDENTIFIER, 'g', log.proteinGrams ?? 0, startDate, endDate),
    },
    {
      label: 'carbs',
      value: log.carbGrams,
      save: () => saveQuantitySample(DIETARY_CARBS_IDENTIFIER, 'g', log.carbGrams ?? 0, startDate, endDate),
    },
    {
      label: 'fat',
      value: log.fatGrams,
      save: () => saveQuantitySample(DIETARY_FAT_IDENTIFIER, 'g', log.fatGrams ?? 0, startDate, endDate),
    },
    {
      label: 'sugar',
      value: log.sugarGrams,
      save: () => saveQuantitySample(DIETARY_SUGAR_IDENTIFIER, 'g', log.sugarGrams ?? 0, startDate, endDate),
    },
    {
      label: 'fiber',
      value: log.fiberGrams,
      save: () => saveQuantitySample(DIETARY_FIBER_IDENTIFIER, 'g', log.fiberGrams ?? 0, startDate, endDate),
    },
  ];

  for (const macro of macros) {
    if (!macro.value) continue;
    try {
      await macro.save();
    } catch (error) {
      console.error(`[AppleHealth] Could not send ${macro.label} for food log`, log.id, error);
    }
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

const MEAL_HOURS: Record<FoodLog['mealType'], number> = {
  breakfast: 8,
  lunch: 12,
  dinner: 18,
  snack: 15,
};
const MEAL_TYPES = Object.keys(MEAL_HOURS) as FoodLog['mealType'][];

async function pullNutritionFromHealth(): Promise<number> {
  const anchor = await readAnchor(NUTRITION_ANCHOR_KEY);
  const endDate = new Date();
  const startDate = new Date(endDate.getTime() - IMPORT_DAYS * DAY_MS);

  const response = await queryQuantitySamplesWithAnchor(DIETARY_ENERGY_IDENTIFIER, {
    filter: anchor ? undefined : { date: { startDate, endDate } },
    limit: 0,
    anchor,
    unit: 'kcal',
  });

  const { foodLogsDb } = await import('./database');

  let imported = 0;
  for (const sample of response.samples) {
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

  await writeAnchor(NUTRITION_ANCHOR_KEY, response.newAnchor);
  return imported;
}

/** Picks the closest meal for a HealthKit sample that only carries a timestamp. */
function mealTypeFor(date: Date): FoodLog['mealType'] {
  const hour = date.getHours();
  return MEAL_TYPES.reduce((closest, type) =>
    Math.abs(MEAL_HOURS[type] - hour) < Math.abs(MEAL_HOURS[closest] - hour) ? type : closest
  );
}
