import NetInfo from '@react-native-community/netinfo';
import { Platform } from 'react-native';

/**
 * Configured NetInfo singleton. Always import NetInfo through this module so the
 * configuration below is in place before the first subscription.
 *
 * Web only: @react-native-community/netinfo 11.4.1 runs a periodic reachability
 * probe (`HEAD /`). At boot the library refreshes twice (the state constructor and
 * the first listener both call `update()`, which starts a check), so the second
 * refresh cancels the first one's in-flight request. The cancellation path
 * (`internetReachability.js:91`) aborts the fetch without handling the rejection,
 * surfacing as an uncaught `signal is aborted without reason` error overlay.
 * Native reads reachability from the OS, so it never takes that JS path and stays
 * untouched. The app only needs link status (`isConnected`), which on web comes
 * from `navigator.onLine` and its online/offline events.
 */
if (Platform.OS === 'web') {
  NetInfo.configure({ reachabilityShouldRun: () => false });
}

export default NetInfo;
export type { NetInfoState } from '@react-native-community/netinfo';
