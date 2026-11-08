# Server inventory, October 2026

Read from the live box on 2026-10-21 (not from older docs; the June 2026
hosting brief PDF is wrong about realtime). This is the inventory Gon asked
for in July (`docs/FEEDBACK-triage-2026-07-14.md`, item 31). It is also the
"before" picture for `docs/PLAN-aws-migration-2026-10-21.md`.

## The box
| | |
|---|---|
| Provider / plan | Hostinger KVM 4, Manchester (UK) |
| Host | `srv1153282.hstgr.cloud`, 72.61.202.136 |
| OS / panel | Ubuntu 24.04, CloudPanel |
| Size | 4 vCPU, 16 GB RAM, 193 GB disk (12 GB used), load ~1% |
| SSH | `ssh -i ~/.ssh/reacti_deploy root@72.61.202.136` (deploy key also used by GitHub Actions) |
| Runtime | PHP 8.4.22 FPM per site (CI pins 8.3; both work), Percona Server 8.4.10, Redis 7, supervisor; memcached and varnish installed but unused |
| Backups | Hostinger weekly full image (two kept, off-site in France) plus a per-deploy `mysqldump` kept on the same box; recovery point up to 7 days |

## Sites
| | Production | Staging |
|---|---|---|
| URL | `https://reacti.io` | `https://staging.reacti.io` |
| Path | `/home/reacti/htdocs/reacti.io` | `/home/reacti-staging/htdocs/staging.reacti.io` |
| Unix user | `reacti` | `reacti-staging` |
| Deploy | `backend-deploy.yml` on `main` (needs `production` environment approval) | `staging-deploy.yml` on `develop` |
| DB | `reacti`, 28 tables, 1.59 MB, 38 users, 1,567 chat rows, 308 group messages | 1.12 MB, pruned hourly by `staging-prune.yml` (chat data older than 24 h) |
| Media | `public/uploads`: 1.9 GB, 718 files (`chat` 1.5 GB, `group_message` 428 MB, `profile` 17 MB, `groups` 11 MB) | 8 MB |
| Realtime | Laravel Reverb on the **old agency's AWS box** `climbiq-goonclimbers.com:8081` (54.160.206.108, us-east-1, their TLS cert, their nginx). The app's compiled host points there too. | Pusher cloud, `ws-eu.pusher.com`, free sandbox |
| Mail | Resend, `Reacti <no-reply@reacti.io>` | Mailtrap sandbox |
| Push | Firebase, credentials file at `storage/app/private/push-notification-token.json` | same |
| Cache / session / queue | Redis (`CACHE_DRIVER`, `SESSION_DRIVER`, `QUEUE_CONNECTION` all `redis`) | same |
| Queue worker | `reacti-worker` under supervisor (since 2026-10-21, see below) | `reacti-staging-worker` |
| Scheduler | none (cron is empty; `routes/console.php` only schedules `inspire`) | none |

## Network and edge
- nginx: TLS on 443 (Let's Encrypt via CloudPanel), proxies to a second
  nginx on 8080 that runs PHP-FPM. `/uploads/...` is served as static files
  with `expires max`.
- Cloudflare proxies `reacti.io` and `staging.reacti.io` (orange cloud), so
  every request arrives from a Cloudflare IP. Media is almost entirely
  served from Cloudflare's cache (3 of 2,529 requests reached the origin in
  one day).
- Traffic: ~2,500 requests/day, ~5 MB/day from origin.
- Limits: nginx `client_max_body_size 64M`; PHP `upload_max_filesize 2G`,
  `post_max_size 3G`, `memory_limit 768M`, `max_execution_time 90`.
- Time: MySQL `time_zone` SYSTEM = UTC, Laravel `APP_TIMEZONE` UTC.

## How data is referenced
The database stores relative media paths (`uploads/chat/phpXXXX.mp4`); API
resources build the URL with `asset()` at read time. No row points at a
host, which is what makes the media move to S3 a config change.

## Phase 0 changes made on 2026-10-21
1. **Queue workers.** No `queue:work` had ever run on this box, so every
   event declared `ShouldBroadcast` (reaction, online status, read, delete)
   was queued and never delivered; prod held 179 stale jobs, staging 715.
   Both backlogs were flushed (`redis-cli del reacti_database_queues:default
   ...`; the events were weeks old) and two supervisor programs were added:

   ```ini
   ; /etc/supervisor/conf.d/reacti-worker.conf (staging: reacti-staging-worker.conf)
   [program:reacti-worker]
   command=/usr/bin/php /home/reacti/htdocs/reacti.io/artisan queue:work --tries=3 --max-time=3600 --sleep=3
   directory=/home/reacti/htdocs/reacti.io
   user=reacti
   autostart=true
   autorestart=true
   stopasgroup=true
   killasgroup=true
   stopwaitsecs=60
   redirect_stderr=true
   stdout_logfile=/var/log/supervisor/reacti-worker.log
   stdout_logfile_maxbytes=20MB
   stdout_logfile_backups=3
   ```

   No `--connection` argument: the `.env` decides, so the same program
   survives the switch to the database driver planned in Phase 1. Both
   deploy workflows already run `php artisan queue:restart`, so workers pick
   up new code on every deploy. Verified: a test `UserOnlineEvent` on
   staging was processed in 140 ms.
2. **Dead Reverb config retired.** The agency's `reverb.conf` (Dec 2025,
   `reverb:start --server`, FATAL on every boot) and the nginx vhost on
   8081 that proxied to the dead port 8083 were moved to
   `/root/phase0-backup-2026-10-21/`. Nothing used them: realtime was and
   still is served from the agency's box. Port 8081 is now closed. A
   dangling `chatspeedx.com` symlink in `sites-enabled` was removed.

## Daily checks until Phase 1
```sh
ssh -i ~/.ssh/reacti_deploy root@72.61.202.136 'supervisorctl status; redis-cli llen reacti_database_queues:default; tail -3 /var/log/supervisor/reacti-worker.log'
```
Expected: both workers RUNNING, queue length near 0, log lines ending in
`DONE`.

## Risks this inventory makes visible
- Realtime depends on a server the company does not own. If the agency's
  box goes away, reactions and presence stop for everyone until app 1.8.0
  points at `ws.reacti.io` (Phase 1).
- The admin UI (`FirebaseSettingService`, `SocialSettingService`) rewrites
  `.env` on disk; a deploy does not touch `.env`, so this is the only place
  those values live.
- `backend/.env.example` says `QUEUE_CONNECTION=database` and
  `MAIL_FROM_ADDRESS="hello@reacti.io"`; production differs.
