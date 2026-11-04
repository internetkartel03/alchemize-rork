import { Alert, Platform } from 'react-native';

type AlertButton = {
  text?: string;
  onPress?: () => void;
  style?: 'default' | 'cancel' | 'destructive';
};

/**
 * react-native-web ships `Alert` as an empty stub (`static alert() {}`), so every
 * confirmation dialog and error message in the app is silently dropped on web:
 * destructive actions (delete task, delete entry, sign-out confirm, "please enter
 * a title") never run and the user gets no feedback.
 *
 * This installs a browser-backed implementation for web only: one-button alerts
 * map to `window.alert`, multi-button dialogs map to `window.confirm` and fire the
 * matching button's `onPress`. Native platforms keep the real `Alert` untouched.
 */
export function installWebAlert(): void {
  if (Platform.OS !== 'web' || typeof window === 'undefined') return;

  const marker = '__alchemizeWebAlertInstalled';
  const w = window as unknown as Record<string, unknown>;
  if (w[marker]) return;
  w[marker] = true;

  (Alert as unknown as { alert: (title?: string, message?: string, buttons?: AlertButton[]) => void }).alert = (
    title?: string,
    message?: string,
    buttons?: AlertButton[],
  ) => {
    const body = [title, message].filter(Boolean).join('\n\n');

    if (!buttons || buttons.length <= 1) {
      window.alert(body);
      buttons?.[0]?.onPress?.();
      return;
    }

    const cancelButton = buttons.find((b) => b.style === 'cancel');
    const confirmButton =
      buttons.find((b) => b.style === 'destructive') ??
      [...buttons].reverse().find((b) => b.style !== 'cancel') ??
      buttons[buttons.length - 1];

    if (window.confirm(body)) {
      confirmButton?.onPress?.();
    } else {
      cancelButton?.onPress?.();
    }
  };
}
