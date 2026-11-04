import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import type { Habit } from '@/types';

/**
 * Daily habit alarms backed by local notifications.
 *
 * Alarms are scheduled as repeating DAILY triggers, so they fire without the app
 * running. Web has no local notification support, so scheduling is a no-op there.
 */

export function isAlarmSupported(): boolean {
  return Platform.OS !== 'web';
}

export function isValidAlarmTime(value: string | null | undefined): boolean {
  if (!value) return false;
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!match) return false;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  return hours >= 0 && hours <= 23 && minutes >= 0 && minutes <= 59;
}

export function formatAlarmTime(value: string | null | undefined): string {
  if (!isValidAlarmTime(value)) return '';
  const [rawHours, rawMinutes] = value!.trim().split(':');
  const hours = Number(rawHours);
  const suffix = hours >= 12 ? 'PM' : 'AM';
  const displayHours = hours % 12 === 0 ? 12 : hours % 12;
  return `${displayHours}:${rawMinutes} ${suffix}`;
}

export async function cancelHabitAlarm(notificationId?: string | null): Promise<void> {
  if (Platform.OS === 'web' || !notificationId) return;

  try {
    await Notifications.cancelScheduledNotificationAsync(notificationId);
  } catch (error) {
    console.error('[HabitAlarm] Failed to cancel alarm:', error);
  }
}

/**
 * (Re)schedules a habit's daily alarm. Returns the notification id, or null when
 * the habit has no alarm, the time is invalid, or alarms are unavailable.
 */
export async function scheduleHabitAlarm(habit: Habit): Promise<string | null> {
  if (Platform.OS === 'web') return null;
  if (!habit.reminderEnabled || !isValidAlarmTime(habit.reminderTime)) return null;

  try {
    const { status: existing } = await Notifications.getPermissionsAsync();
    let status = existing;
    if (status !== 'granted') {
      status = (await Notifications.requestPermissionsAsync()).status;
    }
    if (status !== 'granted') {
      console.log('[HabitAlarm] Notification permission not granted');
      return null;
    }

    if (Platform.OS === 'android') {
      await Notifications.setNotificationChannelAsync('habits', {
        name: 'Habit alarms',
        importance: Notifications.AndroidImportance.HIGH,
        sound: 'default',
        vibrationPattern: [0, 250, 250, 250],
      });
    }

    // Replace any previous alarm so re-saving the habit never stacks duplicates.
    await cancelHabitAlarm(habit.reminderNotificationId);

    const [rawHours, rawMinutes] = habit.reminderTime!.trim().split(':');
    const notificationId = await Notifications.scheduleNotificationAsync({
      content: {
        title: `${habit.icon} ${habit.name}`,
        body: 'Time for your habit — keep your streak going.',
        sound: 'default',
        data: { habitId: habit.id },
      },
      trigger: {
        type: Notifications.SchedulableTriggerInputTypes.DAILY,
        hour: Number(rawHours),
        minute: Number(rawMinutes),
        ...(Platform.OS === 'android' ? { channelId: 'habits' } : {}),
      },
    });

    console.log('[HabitAlarm] Scheduled daily alarm for', habit.name, 'at', habit.reminderTime);
    return notificationId;
  } catch (error) {
    console.error('[HabitAlarm] Failed to schedule alarm:', error);
    return null;
  }
}
