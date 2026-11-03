/**
 * Parses a Supabase password-recovery URL (email link) into the credentials
 * needed to open a recovery session.
 *
 * - Implicit flow: `#access_token=…&refresh_token=…`
 * - PKCE flow: `?code=…`
 */
export type RecoveryLinkCredentials =
  | { kind: 'tokens'; accessToken: string; refreshToken: string }
  | { kind: 'code'; code: string };

function paramsFrom(value: string): URLSearchParams {
  return new URLSearchParams(value.startsWith('?') || value.startsWith('#') ? value.slice(1) : value);
}

export function parseRecoveryLink(url: string): RecoveryLinkCredentials | null {
  if (!url) return null;

  const hashIndex = url.indexOf('#');
  const hash = hashIndex >= 0 ? paramsFrom(url.slice(hashIndex)) : null;
  const accessToken = hash?.get('access_token');
  const refreshToken = hash?.get('refresh_token');
  if (accessToken && refreshToken) {
    return { kind: 'tokens', accessToken, refreshToken };
  }

  const queryIndex = url.indexOf('?');
  if (queryIndex >= 0) {
    const query = paramsFrom(url.slice(queryIndex, hashIndex >= 0 ? hashIndex : undefined));
    const code = query.get('code');
    if (code) return { kind: 'code', code };
  }

  return null;
}
