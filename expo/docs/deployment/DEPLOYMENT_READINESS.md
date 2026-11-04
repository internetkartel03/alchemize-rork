# Deployment Readiness

## Release Gates

Run from `expo/` before every release:

```bash
npm install --legacy-peer-deps
npx tsc --noEmit
npm run lint
npm run validate:final
```

## Required Build-Time Environment

Expo inlines `EXPO_PUBLIC_*` values at build time, so they must be set in the EAS
build environment (never committed). `expo/.env.example` lists them.

| Variable | Purpose | If missing |
| --- | --- | --- |
| `EXPO_PUBLIC_SUPABASE_URL` | Supabase project (auth, journal, image upload) | sign-in and journal screens fall back to their error state |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key | same |
| `EXPO_PUBLIC_AI_API_URL` | base URL of the AI proxy | AI calorie estimate and food scan report "AI service is not configured" |

## The AI Proxy Has To Be Hosted

`expo/lib/ai.ts` posts to `${EXPO_PUBLIC_AI_API_URL}/api/ai/object`, served by
`expo/backend/ai/server.mjs`. That service holds `AI_API_KEY` server-side; the key
must never ship in the bundle or carry an `EXPO_PUBLIC_` prefix. The server has no
dependencies — run `node backend/ai/server.mjs` on any Node host, expose it over
HTTPS, and point `EXPO_PUBLIC_AI_API_URL` at its origin. `GET /health` reports
whether a key is configured.

## Supabase Schema

Tables, RLS policies and the habit-reminder columns live in the Supabase project,
not in this repository. Apply them to the production project before the first
build, otherwise journal and image-upload calls can answer with permission errors.
Capture the schema as migrations in the repo so a fresh project can be built
reproducibly.

## Device Coverage

- iOS simulator or physical iPhone
- Android emulator or physical Android device

Still unverified on device: camera + food photo scan, barcode scan, notification
permissions and reminders, Apple sign-in, HealthKit / pedometer.

## Build & Submit

```bash
cd expo
npx eas build --platform all --profile production
npx eas submit --platform ios --profile production
```

Both need the Expo account credentials and the existing App Store Connect record
(`eas.json` already references app id `6762407627`).

## Release Blockers

Do not release if any are true:

- route crash on launch
- database migration failure
- reminder duplication
- barcode entries save as manual
- persistent blank screen
- Expo build failure
- unresolved permission crash
