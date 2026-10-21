# Background processes: queue worker and scheduler

Two long-running processes besides the web server. On Hostinger they are
supervisor programs; on AWS they become the `worker` ECS service running the
same two commands. Neither takes a `--connection` or driver argument: the
environment decides, so the same definition survives the Redis to database
switch (AWS plan, step 1.4).

| Process | Command | Does |
|---|---|---|
| worker | `php artisan queue:work --tries=3 --max-time=3600 --sleep=3` | Delivers queued broadcast events (reactions, online status, read receipts, deletes) and any queued job. Exits after an hour and supervisor restarts it, so a deploy's `queue:restart` and memory growth are both bounded. |
| scheduler | `php artisan schedule:work` | Runs `schedule:run` once a minute; the schedule is `backend/routes/console.php`. |

## What is scheduled
- `chat:prune-stale-staging`, hourly at :17. Staging only: it no-ops unless
  both gates in `config/staging.php` pass (`STAGING_PRUNE_ENABLED=true` and
  the app host is `staging.reacti.io`). Replaced the GitHub Actions cron
  `staging-prune.yml` on 2026-10-21.
- `media:prune-orphans --force`, Mondays 04:30 UTC. Deletes files under the
  chat media folders that no live message or group references and that are
  older than an hour. Report-only dry run: `php artisan media:prune-orphans`.

## Hostinger
Programs live in `/etc/supervisor/conf.d/`: `reacti-worker.conf`,
`reacti-scheduler.conf` and the `reacti-staging-*` pair. Logs in
`/var/log/supervisor/<program>.log`.

```sh
ssh -i ~/.ssh/reacti_deploy root@72.61.202.136 '
supervisorctl status
redis-cli llen reacti_database_queues:default      # should stay near 0
tail -3 /var/log/supervisor/reacti-worker.log
tail -3 /var/log/supervisor/reacti-scheduler.log
sudo -u reacti php /home/reacti/htdocs/reacti.io/artisan schedule:list'
```

Deploys do not restart these programs: `queue:restart` (already in both
deploy workflows) makes the worker exit and supervisor brings it back on the
new code; `schedule:work` spawns a fresh `schedule:run` each minute, so it
picks up new code by itself.

## AWS
The `worker` task runs both commands as two containers of one task
definition (Phase 2 of the AWS plan). Same commands, same schedule file.
