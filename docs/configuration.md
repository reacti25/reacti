# Configuration — backend environment variables

The Laravel backend (`backend/`) is configured entirely through environment
variables. `backend/.env.example` is the template; copy it to `backend/.env`
and fill in the real values for your environment. The committed `.env.example`
ships **production-safe defaults** (`APP_ENV=production`, `APP_DEBUG=false`,
`LOG_LEVEL=error`) so it is safe to copy to a server as-is — for local
development, apply the three dev overrides noted at the top of the file.

> **Never commit a real `.env`** (only `.env.example`), and never put a real
> secret in a file tracked by git. Secrets reach CI via GitHub Actions secrets
> (`gh secret set`), never chat, never the repo.

## Required to boot

The app will not function correctly without these:

| Variable | Meaning | Notes |
|---|---|---|
| `APP_KEY` | Laravel app encryption key | Generate with `php artisan key:generate`. Required. |
| `APP_ENV` | Environment name | `production` on servers, `local` in dev. |
| `APP_DEBUG` | Verbose error pages | **Must be `false` in production** (Ignition leaks source/env on errors). |
| `APP_URL` | Canonical base URL | `https://reacti.io` in prod; used for absolute asset/media URLs. |
| `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | MySQL connection | The app uses MySQL in every non-test environment (tests use in-memory SQLite). |
| `JWT_SECRET` | `tymon/jwt-auth` signing secret | Generate with `php artisan jwt:secret`. All API auth tokens depend on it. |
| `APP_KEY_VALUE` | Mobile `App-Key` header gate | The mobile client sends this on every request; generate a fresh random value per environment. |
| `CORS_ALLOWED_ORIGINS` | Browser origins allowed to call `/api/*` | Comma-separated. The native app sends no `Origin`, so it is unaffected. Defaults to the `reacti.io` web origins. |

## Required for realtime (patent flow + live chat)

Realtime broadcasting (Pusher) drives live message delivery and the patent
reaction/viewed events. Without it, chat falls back to no live updates.

| Variable | Meaning |
|---|---|
| `BROADCAST_DRIVER` / `BROADCAST_CONNECTION` | `pusher` |
| `PUSHER_APP_ID`, `PUSHER_APP_KEY`, `PUSHER_APP_SECRET` | Pusher app credentials |
| `PUSHER_APP_CLUSTER`, `PUSHER_HOST`, `PUSHER_PORT`, `PUSHER_SCHEME` | Pusher host/transport |

> The **client** realtime host/key is being moved out of hardcoded Flutter code
> into build-time `--dart-define` config (plan A2). Confirm the correct
> production realtime host before wiring it (see `NEEDS-ACHIA.md`).

## Required for push notifications

| Variable | Meaning |
|---|---|
| `FIREBASE_CREDENTIALS` | Path to the Firebase service-account JSON (the file lives **outside** the repo, e.g. `storage/app/firebase/credentials.json`). |
| `FIREBASE_PROJECT` | Firebase project id. |

## Optional / feature-gated

| Group | Variables | When needed |
|---|---|---|
| Mail | `MAIL_*`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME` | OTP/registration/reset emails. |
| AWS S3 | `AWS_*` | Only if media uploads use S3 instead of the local disk (`FILESYSTEM_DISK`). |
| Social login | `GOOGLE_*`, `APPLE_*`, `FACEBOOK_*` | Per provider you enable. |
| Reverb | `REVERB_*`, `VITE_REVERB_*` | Self-hosted realtime alternative to Pusher; usually disabled in prod. |
| Redis / Memcached | `REDIS_*`, `MEMCACHED_HOST` | Only if you switch cache/queue drivers off the file/database defaults. |
| Stripe | `STRIPE_*` | Billing (Cashier) — being removed per DG6; leave blank. |
| Session/cache tuning | `SESSION_DRIVER`, `SESSION_LIFETIME`, `SESSION_SECURE_COOKIE`, `CACHE_STORE`, `QUEUE_CONNECTION` | Have sane defaults; override only intentionally. `SESSION_SECURE_COOKIE` must stay `true` outside plain-HTTP local dev. |

## Deploying checklist

Before a production deploy, confirm in `.env`:

- [ ] `APP_ENV=production`
- [ ] `APP_DEBUG=false` (no Ignition stack traces to clients)
- [ ] `LOG_LEVEL=error` (or `warning`) — not `debug`
- [ ] `APP_KEY` is set (`php artisan key:generate`)
- [ ] `JWT_SECRET` is set (`php artisan jwt:secret`)
- [ ] `APP_URL` is the real HTTPS origin (`https://reacti.io`)
- [ ] `APP_KEY_VALUE` is set to this environment's mobile gate value
- [ ] `CORS_ALLOWED_ORIGINS` lists only the intended web origins
- [ ] `SESSION_SECURE_COOKIE=true`
- [ ] Database credentials point at the production DB, and migrations have run
- [ ] Pusher and Firebase credentials are present (realtime + push work)
- [ ] No real secret is committed anywhere — `.env` is not in git
