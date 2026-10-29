import { Audio } from 'expo-av';
import { Platform } from 'react-native';

const WORKOUT_COMPLETE_CHIME_URL =
  'https://r2-pub.rork.com/generated-audio/q7fskfcpqy3eg5isjew63/8b94af0e-6724-4ae0-990f-8d7db1338af3.mp3';

/**
 * Plays a short celebratory chime (e.g. when a workout is completed).
 * Fails silently — audio is a nice-to-have, never blocking.
 */
export async function playCompletionChime(): Promise<void> {
  try {
    if (Platform.OS !== 'web') {
      await Audio.setAudioModeAsync({ playsInSilentModeIOS: true });
    }
    const { sound } = await Audio.Sound.createAsync(
      { uri: WORKOUT_COMPLETE_CHIME_URL },
      { shouldPlay: true, volume: 0.8 }
    );
    sound.setOnPlaybackStatusUpdate((status) => {
      if (status.isLoaded && status.didJustFinish) {
        void sound.unloadAsync();
      }
    });
  } catch (error) {
    console.log('[Sound] Could not play completion chime:', error);
  }
}
