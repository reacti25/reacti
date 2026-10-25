# Reacti on AWS: migration plan

Status: PLAN, nothing built yet. Draft reviewed by the author, then by an
independent adversarial review that verified 14 technical claims against
the primary docs (all held) and raised 16 findings plus 10 omissions, all
folded in (proxy trust, data-load order, private RDS load path, S3 ACL,
KMS grants, broadcast guards, ACM validation, worker lifecycle, default
images, image size, secret rotation, staging layout, upload limits,
rollback details, S3 backup, observability, region SCP, Cloudflare bypass).
Written 2026-10-21 from the live server, the repo, the official AWS price
lists and regional-services table, and the AWS / Laravel / Terraform docs
(sources at the end). Owner: Achia. Executor: Claude Code, step by step on
the branch `aws-migration`.

The goal, in Achia's words: build and test every step now, so that when the
AWS account arrives the move is a sequence of already-rehearsed commands and
works out of the box, for staging first and then the real app.

---

## 0. One-screen summary

| | Today (Hostinger) | Target (AWS) |
|---|---|---|
| Compute | 1 VPS, CloudPanel, nginx + PHP-FPM, prod and staging on the same box | ECS Fargate (Graviton), one container image, 3 services per environment: `web`, `reverb`, `worker` |
| Database | Percona MySQL 8.4 on the box, 1.6 MB | RDS for MySQL 8.4, `db.t4g.micro`, 20 GB gp3, 14-day backups with point-in-time restore |
| Media | 1.9 GB of files under `public/uploads`, served by nginx through Cloudflare | Private S3 bucket (KMS-encrypted) behind CloudFront at `media.reacti.io`; same relative paths, so the database does not change |
| Realtime | Laravel Reverb on the old agency's AWS box (`climbiq-goonclimbers.com:8081`) | Reverb as our own ECS service at `ws.reacti.io` |
| Queue / scheduler | Redis queue with **no worker** (179 jobs stuck), no scheduler | `worker` service runs `queue:work` and `schedule:work`; database queue driver |
| Deploy | rsync over root SSH, `artisan` over SSH | GitHub Actions with OIDC (no long-lived keys) builds the image, runs migrations as a one-off task, rolls the services with automatic rollback |
| Secrets | `.env` on the box, edited by hand and by the admin UI | SSM Parameter Store (SecureString), injected into tasks; admin UI no longer writes `.env` |
| Infra definition | none (CloudPanel clicks) | Terraform, one module, two environments, unit-tested without credentials |
| Accounts | one Hostinger login | AWS Organizations: management + `reacti-staging` + `reacti-prod`, IAM Identity Center, Budgets, CloudTrail |
| Region | Manchester (UK) | **il-central-1 Tel Aviv** (decided 2026-10-21; Frankfurt is a one-variable switch, see D1) |
| Cost (list, both envs) | ~$25/mo | ~$225/mo in Tel Aviv (prod ~$127, staging ~$96); credits cover the first 6 to 24 months |

What can be proven before the account exists: the container, the whole
application against a production-shaped stack (MySQL 8.4, S3 emulator,
Reverb, worker, scheduler) including a websocket end-to-end test, the
Terraform (validate, mocked plan/apply, lint, policy scan), the deploy
workflow's build half, and the runbooks. What cannot: an ALB, RDS, CloudFront
and IAM actually talking to each other. That is why staging goes to AWS first
and runs for a week as the full dress rehearsal before production moves.

Two things to do **now**, independent of AWS, because they are live bugs:
1. Start a queue worker on the VPS (10 minutes, section 1.3).
2. Bring realtime in-house (Phase 1), which also needs an app release.

---

## 1. What we actually run today (read from the server 2026-10-21)

### 1.1 The box
- Hostinger KVM 4, `srv1153282.hstgr.cloud`, 72.61.202.136, Ubuntu 24.04,
  CloudPanel. 4 vCPU, 16 GB RAM, 193 GB disk (12 GB used). Load ~1%.
- PHP 8.4.22 FPM per site (the repo pins 8.3 in CI; both work), Percona
  Server 8.4.10, Redis 7, memcached, varnish (installed, unused), supervisor.
- Both sites on one box: `/home/reacti/htdocs/reacti.io` (prod) and
  `/home/reacti-staging/htdocs/staging.reacti.io` (staging).
- nginx: TLS on 443 (Let's Encrypt via CloudPanel), proxies to a second nginx
  on 8080 which runs PHP-FPM. Static files (`/uploads/...`) are served
  directly with `expires max`.
- Cloudflare proxies `reacti.io` and `staging.reacti.io` (orange cloud). All
  requests arrive from Cloudflare IPs. Media is almost entirely served from
  Cloudflare's cache (3 of 2,529 requests reached the origin in a day).
- Traffic: ~2,500 requests/day, ~5 MB/day from origin.

### 1.2 Data
- Prod DB `reacti`: 28 tables, **1.59 MB**, 38 users, 1,567 chat rows, 308
  group messages. Staging DB: 1.12 MB.
- Prod media: **1.9 GB, 718 files** (`chat` 1.5 GB, `group_message` 428 MB,
  `profile` 17 MB, `groups` 11 MB). Staging: 8 MB.
- The database stores **relative paths** (`uploads/chat/phpXXXX.mp4`); API
  resources build the URL with `asset()` at read time (41 call sites). No
  row points at any other host.

### 1.3 Surprises found during the inventory
- **No queue worker has ever run on this server.** `QUEUE_CONNECTION=redis`,
  supervisor has no `queue:work`, and the prod queue holds **179 stuck
  jobs: 114 `MessageReactionEvent`, 45 `UserOnlineEvent`, 15
  `MessageReadEvent`, 5 `MessageDeletedEvent`** (staging: 715). These are
  the events declared `ShouldBroadcast` (queued) rather than
  `ShouldBroadcastNow`; they are silently never delivered. Messages
  themselves use `ShouldBroadcastNow`, which is why chat still works.
  Fix now: a supervisor program `php artisan queue:work --tries=3
  --max-time=3600` for each site (no connection argument, so the env
  decides and the same program survives the switch to the database driver in
  1.4), then watch the backlog drain (the stuck jobs reference events that
  are months old; flush them first with
  `redis-cli del reacti_database_queues:default`).
- **No scheduler cron.** `routes/console.php` only schedules `inspire`. The
  staging prune runs from GitHub Actions over SSH instead.
- **Reverb on the box is broken and always was.** `/etc/supervisor/conf.d/
  reverb.conf` (Dec 2025, the agency) runs `reverb:start --server ...`;
  `--server` is not an option, so it is FATAL on every boot. An nginx vhost
  on 8081 proxies to the dead 8083. Nothing points at it: the backend's
  `REVERB_HOST=climbiq-goonclimbers.com:8081` and the app's compiled host are
  both the agency's AWS box (54.160.206.108, us-east-1, their Let's Encrypt
  cert, their nginx, their Reverb). The June 2026 hosting brief PDF says
  Reverb runs on the VPS; that is wrong.
- Staging realtime is Pusher cloud (`ws-eu.pusher.com`, free sandbox).
- The admin UI (`FirebaseSettingService`, `SocialSettingService`) rewrites
  `.env` on disk. That cannot work on containers.
- `backend/.env.example` still says `MAIL_FROM_ADDRESS="hello@reacti.io"`
  and `QUEUE_CONNECTION=database`; prod differs. The example will be
  regenerated from the container env contract in Phase 2.
- Hostinger backups: weekly full image (two kept, off-site in France) plus a
  per-deploy `mysqldump` kept on the same box. Recovery point up to 7 days.

### 1.4 What must change in the application (the "cloud-readiness" list)
Everything below is a single-server assumption; each is a small, testable
change that is also correct on Hostinger, so it ships before the move.

| # | Assumption | Change |
|---|---|---|
| R1 | Media written with `public_path('uploads/...')` and deleted with `unlink` (Helper.php:42, :89, :116; AdminProfileService:103; GeneralSettingService:52; PruneStaleStagingChat:116; PruneOrphanMedia:40-56) | One `media` disk (`Storage::disk('media')`); on Hostinger it is a local disk rooted at `public/`, on AWS it is S3. Same relative paths. |
| R2 | URLs built with `asset($path)` (41 sites in `Http/Resources`) | One helper `media_url($path)` = `Storage::disk('media')->url($path)`. On Hostinger it returns exactly today's URL. |
| R3 | No queue worker, no scheduler | `worker` process definition (supervisor on Hostinger now, ECS service later). Staging prune and `media:prune-orphans` move into `routes/console.php` behind the existing config gates. |
| R4 | `LOG_CHANNEL=stack` to a file; `CACHE_DRIVER=redis`; `SESSION_DRIVER=redis`; maintenance driver `file` | Env-only: `LOG_CHANNEL=stderr` (JSON), `CACHE_STORE=database`, `SESSION_DRIVER=database`, `QUEUE_CONNECTION=database`, `APP_MAINTENANCE_DRIVER=cache` + `APP_MAINTENANCE_STORE=database`. The `cache`, `sessions`, `jobs` tables already exist. No Redis on AWS at all. |
| R5 | Firebase credentials are a JSON file path | kreait accepts a JSON string in `FIREBASE_CREDENTIALS`; verify with a test, inject from SSM. |
| R6 | Admin UI writes `.env` | Those two settings pages become read-only ("set via environment"). |
| R7 | Realtime host is compiled into the app and belongs to the agency | App 1.8.0 points at `ws.reacti.io:443`; Reverb runs under our control (Phase 1). |
| R8 | Deploy = rsync + SSH + chown + FPM reload | Image build + ECS deploy (Phase 3). Hostinger deploy stays untouched until cutover. |
| R9 | `/up` health route | Exists in Laravel 11 (`bootstrap/app.php` `health: '/up'`); confirm it does not touch the DB (it should not, so a DB blip does not restart web tasks) and that it is exempt from maintenance mode (otherwise the ALB marks every task unhealthy while the app is "down"). |
| R10 | No `trustProxies` in `bootstrap/app.php` (CloudPanel's inner nginx hides this today) | Behind the ALB, TLS ends at the load balancer and PHP sees plain HTTP: `url()`/`asset()` would emit `http://`, `$request->ip()` would be the ALB and login throttling would share one bucket. `trustProxies(at: <VPC CIDR>, headers: X-Forwarded-For/Host/Port/Proto)`. The compose stack's fake ALB asserts `https://` URLs and the real client IP. |
| R11 | Upload limits live in nginx/php.ini on the box (`client_max_body_size 64M`, `upload_max_filesize 2G`, `post_max_size 3G`, `memory_limit 768M`, `max_execution_time 90`) | Same values via the image's env (`PHP_UPLOAD_MAX_FILE_SIZE`, `PHP_POST_MAX_SIZE`, `PHP_MEMORY_LIMIT`, nginx body size); a 60 MB upload is part of the smoke. |

---

## 2. Target design

```
                       Cloudflare (DNS for reacti.io; proxy ON for reacti.io API only)
                                   │ reacti.io ──────────────────┐
   phone ── wss ws.reacti.io ──────┼─────────────────┐           │
   phone ── https media.reacti.io ─┤                 │           │
                                   ▼                 ▼           ▼
                         CloudFront (OAC)     ┌──────────── ALB (ACM cert: reacti.io, *.reacti.io) ───────────┐
                               │              │ host ws.*  → TG reverb      path /uploads/* → 301 media.*       │
                               ▼              │ default    → TG web                                             │
                      S3 reacti-media         └───────┬──────────────────────┬───────────────────────────────┘
                     (private, SSE-KMS)               ▼                      ▼
                               ▲              ECS service web (2)    ECS service reverb (1)     ECS service worker (1)
                               │              nginx+php-fpm :8080    reverb:start :8080         queue:work + schedule:work
                               └──────────────── task role (s3:Put/Get/Delete on the bucket) ─────────────┘
                                                      │
                                                      ▼
                                        RDS MySQL 8.4 db.t4g.micro (private subnet, TLS required)

   GitHub Actions ──OIDC──▶ ECR (image) ──▶ run-task migrate ──▶ update-service web/reverb/worker
   SSM Parameter Store ──▶ task definition `secrets` (every .env value)
   CloudWatch Logs ◀── awslogs driver (stderr JSON); Sentry and PostHog unchanged; Resend unchanged
```

One identical stack per environment, in its own AWS account:
`reacti-staging` (staging.reacti.io, ws-staging.reacti.io,
media-staging.reacti.io) and `reacti-prod`.

### 2.1 Components and why

**ECS on Fargate, Graviton (ARM64), public subnets, no NAT.**
No OS to patch, no SSH, rolling deploys with health checks and the
deployment circuit breaker (automatic rollback), per-task IAM roles, ECS
Exec for break-glass `artisan`. Public subnets with a security group that
only admits the ALB avoid the NAT gateway (~$38/mo per environment for a
service that would carry 5 MB/day). ARM is ~20% cheaper than x86 and the
image builds natively on GitHub's `ubuntu-24.04-arm` runners.
Rejected: Lightsail (no IAM roles, a VPS on AWS), EC2 + Forge (cheaper, but
OS and PHP upgrades stay ours and it is a single point of failure), Elastic
Beanstalk (dated, no upside), App Runner and Laravel Vapor (closed to new
customers), Laravel Cloud (not our AWS account, so no credits and no IAM
story), ECS Express Mode (a bootstrap wrapper around the same resources;
Terraform gives us the same thing with a readable definition).

**One image, three services.** `serversideup/php:8.3-fpm-nginx` (nginx +
php-fpm, unprivileged `www-data`, port 8080, container healthcheck at
`/healthcheck` served by nginx; the image many Laravel teams run on ECS)
plus `default-mysql-client` for the one-off database load. The same image
runs `reverb:start`, `queue:work` and `schedule:work` with a different
command. Four task definitions: `web`, `reverb`, `worker`, `migrate`.
Sizes (prod): web 2 × 0.5 vCPU / 1 GB, reverb 1 × 0.25 / 0.5 GB, worker
1 × 0.25 / 0.5 GB. Staging: the same three services, one task each at
0.25 / 0.5 GB, so the two Terraform roots differ only in sizes and names.
Every deploy replaces the single Reverb task, which drops all realtime
connections for a few seconds; clients reconnect with backoff (this is
also true of the VPS today whenever Reverb restarts).

**ALB.** Native websocket support (HTTP/1.1 upgrade), ACM certificate,
idle timeout raised to 300 s (default 60 s would cut idle Pusher-protocol
connections; Reverb pings every 60 s). Rules, in order: host `ws.reacti.io`
→ reverb target group (health `/up`); host `reacti.io` without the
`X-Reacti-Edge` header that a Cloudflare Transform Rule adds → 403
(the ALB must be open to the world for the websocket host, so this is what
keeps the API behind Cloudflare); path `/uploads/*` → 301 to
`https://media.reacti.io/#{path}` so any URL an old app cached keeps
working; default → web (health `/up`). Deregistration delay 30 s. Access
logs to S3 (30-day lifecycle).

**RDS for MySQL 8.4, db.t4g.micro, Single-AZ, 20 GB gp3.** Plain MySQL,
no Aurora quirks. 8.4 is the LTS line; 8.0 on RDS has been in paid
Extended Support since 1 Aug 2026 (it would add ~$178/mo on a micro). The
micro has 1 GiB RAM (~85 connections); our four tasks use a handful.
Automated backups 14 days with PITR, `require_secure_transport=ON`, TLS CA
bundle baked into the image, a dedicated app user (not the master user),
deletion protection on, final snapshot on destroy. Upgrade path: `small`,
then Multi-AZ, by changing one variable.

**S3 + CloudFront with Origin Access Control.** Bucket private (Block
Public Access on, ACLs disabled), SSE-KMS with S3 Bucket Key and key
rotation on (revocable key and a CloudTrail record of every decrypt, which
matters for face videos), versioning **on** with noncurrent versions expiring
after 7 days (this is the media backup: an accidental delete or overwrite is
recoverable for a week, and a user's deletion is final after a week, which
the privacy policy wording must allow), `prevent_destroy` on the bucket,
lifecycle rule to abort incomplete multipart uploads after 7 days. Because
ACLs are disabled, every PUT must carry `ACL: bucket-owner-full-control` or
no ACL; Flysystem's S3 adapter always sends one, so the disk config sets
`options.ACL = bucket-owner-full-control` and drops `visibility`. The task
role gets `s3:GetObject/PutObject/DeleteObject` on the bucket **and**
`kms:GenerateDataKey`/`kms:Decrypt` on the key; the key policy grants
`kms:Decrypt` to `cloudfront.amazonaws.com` for this distribution, or every
media GET is a 403. CloudFront serves `media.reacti.io` from the bucket via
OAC; nothing but CloudFront can read the bucket. URLs stay
public-by-unguessable-name exactly like today; signed URLs are a listed
follow-up because they need the app to tolerate expiring URLs. CloudFront
replaces Cloudflare for media, which also closes the open "reaction media
through a third-party CDN without a DPA" item: the AWS DPA is part of the
AWS Service Terms (section 1.14) automatically. S3 → CloudFront transfer is
free and CloudFront's always-free tier is 1 TB/month.

**Database queue, database cache, database sessions.** Zero new
infrastructure, the tables exist, and at 2,500 requests/day the DB does
not notice. SQS and ElastiCache are env-level upgrades later. Reverb with
one task needs no Redis.

**SSM Parameter Store** (free) instead of Secrets Manager ($0.40/secret).
One SecureString per env key under `/reacti/<env>/...`; ECS injects them as
`secrets`. Terraform creates the parameters with placeholder values and
ignores later value changes; a script fills the real values on day one.

**Terraform** (≥ 1.11, S3 backend with native locking, no DynamoDB). One
module `infra/modules/reacti-stack`, two roots `infra/envs/staging` and
`infra/envs/prod`. The Cloudflare provider (a token scoped to DNS edit on
the `reacti.io` zone) creates the ACM validation records and the
`ws-*`/`media-*` records, so an `apply` completes in one pass instead of
blocking on certificate validation; the two apex/API records that are
flipped by hand at cutover stay outside Terraform on purpose. Tested
without credentials by `terraform test` with `mock_provider` for both
providers, `tflint` with the AWS ruleset and `trivy config`.
Rejected: CDK (Node toolchain, slower CloudFormation loop), raw
CloudFormation (worst review story), OpenTofu (keep as an escape hatch;
state is compatible).

**GitHub Actions with OIDC.** One deploy role per account, trust scoped to
`repo:reacti25/reacti:environment:staging` / `:environment:production`.
No AWS keys in GitHub. `aws-actions/configure-aws-credentials@v6`,
`amazon-ecr-login@v2`, `amazon-ecs-render-task-definition@v1`,
`amazon-ecs-deploy-task-definition@v2` (`run-task` for the migration,
`wait-for-service-stability` for the rollout).

**Accounts.** Management account (billing, Organizations, nothing else) +
`reacti-staging` + `reacti-prod` in a `Workloads` OU, IAM Identity Center
for humans (no IAM users), an SCP restricting regions to the home region
**plus `us-east-1`** (CloudFront's certificate, IAM, Budgets and CloudTrail
are global services that live there; forgetting this is the classic
footgun), Budgets per account with actual + forecast alerts, one
organization CloudTrail (free first copy), GuardDuty on prod after its
30-day trial shows the cost, alternate security and billing contacts set.

**Observability.** CloudWatch alarms (ALB 5xx rate, unhealthy targets,
running-task count per service, RDS CPU and free storage, CloudFront 5xx,
a Logs metric filter on `Job failed` lines) → SNS → email; RDS error and
slow-query logs exported; ALB access logs; an external uptime check
(free tier of any uptime service) on `/up` and the websocket handshake, so
an AWS-wide problem is still seen; Sentry and the synthetic-perf workflow
unchanged.

**Unchanged:** Cloudflare for DNS and as the proxy in front of the API
(so the cutover is an origin change with no DNS propagation), Resend for
email, Firebase for push, PostHog and Sentry, the Insights site.

### 2.2 Decisions (D)

| # | Decision | Choice | Why | Alternative kept open |
|---|---|---|---|---|
| D1 | Region | `il-central-1` (Tel Aviv), decided by Achia 2026-10-21 | The team and the users are in Israel and the next phases concentrate there; a region move later is a second migration, so start where the users are. All needed services are present (checked in the official regional table); Fargate +11% and storage +12% over Frankfurt (~$20/mo). Cross-region backup copies go to Ireland. | `eu-central-1` (Frankfurt): ~10% cheaper, "EU-hosted" reads cleanly for the Swedish/German users. It is one variable (`region`). Privacy policy must be updated either way (it says UK today). |
| D2 | Hosting shape | ECS Fargate | Section 2.1 | EC2 + Forge at ~$83/mo if cost ever matters more than ops |
| D3 | Realtime | Self-hosted Reverb, our ECS service | Pusher protocol, no app library change, no per-connection pricing | Pusher cloud ($49/mo for 500 connections) if we ever want zero realtime ops |
| D4 | Queue / cache | database drivers | nothing to run; tables exist | SQS / Valkey by env change |
| D5 | Media CDN | CloudFront + OAC, Cloudflare out of the media path | DPA, free egress, private bucket | keep Cloudflare for the API only |
| D6 | Media URLs | plain CloudFront URLs, unguessable names (today's posture) | no app change | signed URLs + app change (follow-up F2) |
| D7 | DB migration | `mysqldump` on the VPS → S3 → a one-off ECS task loads it into RDS; RDS never becomes public | 1.6 MB loads in seconds; replication/DMS are for databases 1,000× this size | binlog replication runbook is in the sources if the DB grows past ~5 GB before the move |
| D8 | Secrets | SSM Parameter Store | free, native ECS injection | Secrets Manager if rotation is ever needed |
| D9 | Accounts | three accounts | AWS's own recommendation; separate budgets and blast radius; cleaner OIDC trust | one account with two VPCs (not recommended) |
| D10 | Image base | serversideup/php fpm-nginx | proven on ECS, built-in health and process management | FrankenPHP/Octane rejected (long-lived process semantics never tested against this code) |
| D11 | Staging first, one-week soak | staging on AWS is the real rehearsal | the only way to test ALB + RDS + CloudFront + IAM together | none |
| D12 | Old Hostinger VPS | frozen in maintenance mode for 30 days after cutover, then a final snapshot, then cancelled | cheap insurance; rollback is seconds | none |

---

## 3. Testing principle

Every phase ends with a gate that **fails in CI if the piece is wrong**.
Nothing is "done" on the word of the person who built it.

| Layer | How it is proven before the account exists | Residual risk, closed on day one |
|---|---|---|
| Application changes (R1-R9) | PHPUnit (sqlite, as today) + the same suite against **MySQL 8.4** and an **S3 emulator** (RustFS, S3-compatible, service container) in CI; staging on Hostinger runs the changes for real | none; the code is live on Hostinger before the move |
| Container image | builds on ARM in CI, boots, `/up` returns 200, Trivy scan (CRITICAL/HIGH, fixed only), size ceiling | none |
| Production-shaped stack | `compose.aws.yaml`: web ×2 behind an nginx "fake ALB", reverb, worker, mysql:8.4, rustfs. CI runs `docker compose up --wait`, then the **AWS smoke suite**: register, login, upload a photo to the emulated S3, mark viewed, upload a reaction, assert the reaction arrives over a websocket subscription (Python `websockets` client speaking the Pusher protocol), queued event delivered by the worker, scheduler tick observed | real S3 ACL/KMS/OAC behaviour; real ALB websocket behaviour; real RDS TLS |
| Terraform | `fmt`, `validate`, `terraform test` with `mock_provider` (plans and applies against fakes, asserts on sizes, encryption, public-access blocks, idle timeout, SG rules), `tflint`, `trivy config` | real `apply`: done on staging first |
| Deploy workflow | the build half runs on every push to the branch; the AWS half is guarded and exercised with `--dry-run` rendering of the task definitions | first real run targets staging |
| Runbooks | each command in the day-one and cutover runbooks is copied from a script in `infra/scripts/`, and those scripts have a `--dry-run` that prints what they would do | none |

---

## 4. The plan

### Branch model
- Long-lived branch **`aws-migration`** off `develop`, rebased weekly.
- Each step below is a PR **into `aws-migration`**, with its gate green.
- **Nothing from this plan goes into `develop` until it is ready to ship to
  production as is.** `develop` is the only road to prod and must stay
  releasable; work that waits on a soak or the cutover stays here.
  Bringing any of it into `develop` is Achia's call, asked in plain words
  before the first merge.
- *Corrected 2026-10-25.* This line used to say "Phase 0 and Phase 1 PRs also
  go to `develop` → `main` the normal way". That put #496-#502 on develop
  although they needed a week's soak, and it blocked an unrelated release.
  They were reverted off develop in #507 (squash `b03a388`) and live only on
  this branch. **When this branch merges into develop, first revert
  `b03a388`**: git treats the seven as already merged, so a plain merge
  will not bring them back.
- After the production cutover, `aws-migration` merges to `develop` and
  `main`, and the Hostinger deploy workflows are deleted.

### Phase 0: stop the bleeding (this week, no AWS)
| Step | What | Gate |
|---|---|---|
| 0.1 | Supervisor `queue:work` for prod and staging on the VPS; flush the stale backlog; document in `docs/ops/`. **Done 2026-10-21**: `reacti-worker` and `reacti-staging-worker` RUNNING, 179 + 715 stale jobs flushed, a test `UserOnlineEvent` on staging processed in 140 ms. | `supervisorctl status` shows RUNNING ✅; `redis-cli llen` stays near 0 for a day (check 2026-10-22); a `MessageReactionEvent` is observed on a test device in real time (Achia) |
| 0.2 | Delete the dead `reverb.conf` and the 8081 vhost on the VPS (they are reinstated correctly in 1.3). **Done 2026-10-21**: both moved to `/root/phase0-backup-2026-10-21/`, port 8081 closed, nginx reloaded. | supervisor no longer shows the FATAL program ✅ |
| 0.3 | Save every fact from section 1 as `docs/ops/server-inventory-2026-10.md` (the inventory Gon asked for in July). **Written 2026-10-21.** | reviewed by Achia |

### Phase 1: cloud-ready application (on Hostinger first; ~1 week)
Each step is small, behaviour-preserving on Hostinger, and covered by a
test that would fail on AWS if skipped.

| Step | What | Gate |
|---|---|---|
| 1.1 | **Media disk** (R1, R2): `config/filesystems.php` gets a `media` disk (local, root `public/`) and an `s3` variant selected by `MEDIA_DISK` (with `options.ACL = bucket-owner-full-control`, no `visibility`); `Helper::uploadImage/fileUpload/deleteFile`, `AdminProfileService`, `GeneralSettingService`, `ChatService` (2 sites) and the two prune commands use it; `media_url()` replaces the `asset()` calls that point at `uploads/...` (about 24 of the 44 hits in 13 files). The ~20 `asset('default/...')` calls for the bundled default avatar and group images **stay** `asset()`: those files ship in the image under `public/default/`, not in the bucket. | Existing suite green. New tests: upload/delete through the disk; `media_url` returns `https://reacti.io/uploads/...` on the local disk and `https://media.reacti.io/uploads/...` on an S3 disk with `AWS_URL` set; a grep test that no `asset('uploads` remains; an integration test against RustFS covers a 20 MB multipart video upload, `url()`, and `delete()`. Staging on Hostinger: upload, view, delete a photo, nothing changed. |
| 1.2 | **Worker and scheduler** (R3): `routes/console.php` schedules `chat:prune-stale-staging` hourly (behind its config gates) and `media:prune-orphans --force` weekly; `staging-prune.yml` deleted; `docs/ops/worker.md`. | `php artisan schedule:list` test; staging prune observed from the scheduler, not from GitHub |
| 1.3 | **Realtime in-house** (R7), app-first: (a) fix the VPS Reverb (`reverb:start --host=127.0.0.1 --port=8083` for prod and a second program on 8084 for staging, nginx vhosts `ws.reacti.io` and `ws-staging.reacti.io` on 443 with their own Let's Encrypt certs, Cloudflare DNS-only A records); (b) the 9 broadcast events get the `InteractsWithBroadcasting` trait and `broadcastVia(['reverb', 'reverb_legacy'])` for a transition window, where `reverb` = ws.reacti.io (listed first) and `reverb_legacy` = the agency box with `client_options.timeout = 2`; the five unguarded `broadcast()` call sites (`GroupService` ×2, `AuthService` ×2, `AdminChatService`) are wrapped so a dead legacy box cannot fail a request; (c) app 1.8.0 built with `PUSHER_HOST=ws.reacti.io PUSHER_PORT=443`; same app id/key/secret as today (we hold them), so nothing else changes; (d) staging app build points at `ws-staging.reacti.io` and staging drops Pusher cloud. | Backend tests: every broadcast event lists both connections; a legacy connection that throws still yields a 200 and the event reaches `reverb`. Manual: new TestFlight build receives a message live through ws.reacti.io while an old install still receives it through the agency box. Two weeks after 1.8.0 is live, remove `reverb_legacy` and the agency host from code and env. |
| 1.4 | **Drivers by env** (R4): staging `.env` on Hostinger switched to `LOG_CHANNEL=stderr`, `CACHE_STORE=database`, `SESSION_DRIVER=database`, `QUEUE_CONNECTION=database`, maintenance driver `cache`; prod follows a week later. `phpunit.xml` and CI matrix add a MySQL 8.4 job. | Suite green on sqlite and MySQL 8.4; staging runs a week on the database drivers; `php artisan down/up` works with the cache driver |
| 1.5 | **Firebase credentials from env** (R5): `FIREBASE_CREDENTIALS` accepts the JSON string; staging deploy passes it as a string. | Test: push send with a JSON-string credential (kreait fake); staging push received |
| 1.6 | **Admin settings read-only** (R6). | Feature test: the two POST routes return 405/redirect with a notice; no `.env` write path remains (grep test) |
| 1.7 | **Health route** (R9): `/up` returns 200 without a DB query and is excluded from maintenance mode; `/up/deep` (DB + disk) for humans only. A 3-line middleware adds `X-Reacti-Origin: <SERVED_BY env>` (`hostinger` today, `aws` later) so the cutover check can tell which origin answered through Cloudflare. | Tests assert no queries on `/up`, 200 while `down`, and the header value |
| 1.8 | **Trust the load balancer** (R10) and **upload limits by env** (R11). | Test: with `X-Forwarded-Proto: https` from a trusted address, `url()` is https and `ip()` is the forwarded one; from an untrusted address the headers are ignored |

**Phase 1 status, 2026-10-21 evening.** All code merged to `develop` and verified on staging, one PR at a time: 1.1 media disk (#496), 1.2 scheduler (#497, GitHub prune cron deleted, prune observed from the scheduler at 17:17), 1.3 backend fan-out (#498, proven live on staging publishing to Pusher and the local Reverb), 1.4 MySQL 8.4 CI job (#502) plus staging `.env` on database session/queue and cache-based maintenance, 1.5 + 1.6 (#501), 1.7 + 1.8 (#500). Still open: 1.3 server side (DNS `ws` / `ws-staging` to the VPS, then CloudPanel reverse-proxy sites + Let's Encrypt, then env flips) and app 1.8.0 (#499, draft). Production has none of this yet: it follows after a week of staging soak, via the normal `develop` → `main` release.

### Phase 2: the container and the production-shaped stack (~1 week)
| Step | What | Gate |
|---|---|---|
| 2.1 | `backend/Dockerfile` (multi-stage: composer install `--no-dev`, Vite build, final `serversideup/php:8.4-fpm-nginx` (8.4 to match the VPS; CI still tests 8.3) ARM64 + x86 with `default-mysql-client`, RDS CA bundle at `/etc/ssl/rds/global-bundle.pem`, `php.ini` prod values, OPcache on, `.dockerignore`). `container-ci.yml`: multi-arch build with buildx (QEMU for the arch the runner lacks; GitHub's native ARM runners are used if the private-repo plan includes them, checked at this step), boot, `/up`, Trivy, uncompressed size ≤ 900 MB (measured 2026-10-22: 790 MB arm64, 804 MB amd64; the base image alone is ~550 MB, vendor ~150 MB; the AWS SDK's unused services are the only cheap trim, ~40 MB, if pull time ever matters). | workflow green |
| 2.2 | `compose.aws.yaml` + `infra/scripts/smoke_aws.py` (the websocket end-to-end smoke, section 3; the fake ALB terminates TLS and sets the forwarded headers; the smoke also uploads a 60 MB video and checks every URL in API responses is `https://`). `aws-stack-ci.yml` runs it on every push to the branch. | the smoke passes: reaction broadcast received over the websocket, queued event delivered, scheduler tick logged, URLs https, client IP correct |
| 2.3 | **Env contract**: `backend/.env.aws.example` lists every variable the container reads, which are secrets, and their SSM path. Generated test asserts the task definition templates reference exactly these names (no drift between code, Terraform and docs). | test green; `.env.example` regenerated |
| 2.4 | Entry commands: `web` (image default), `reverb` (`php artisan reverb:start --host=0.0.0.0 --port=8080`), `worker` (two containers: `queue:work --tries=3` with **no** `--max-time`, because an exiting essential container would stop the task and count against the circuit breaker; deploys replace the task anyway; and `schedule:work`), `migrate` (one-off: `migrate --force --isolated`; note `--isolated` exits 0 when another run holds the lock, acceptable with one pipeline), `dbload` (one-off: stream the dump from a presigned S3 URL in `DUMP_URL` into RDS with the bundled mysql client; keeps the AWS CLI out of the image, `db_move.sh` in 3.5 mints the URL). The roles live in one script, `backend/docker/bin/reacti`; the image default command stays the web server. | each exercised by 2.2 |

**Phase 2 status (2026-10-22):** all four steps built on this branch and green in CI. 2.1 `backend/Dockerfile` + `docker/bin/reacti` + `container-ci.yml` (native amd64 and arm64 runners, image 790/804 MB, Trivy scoped to the image layers because the composer packages belong to the Dependency Audit). 2.2 `infra/compose.aws.yaml` + `infra/fake-alb/nginx.conf` + `infra/scripts/smoke_aws.py` + `aws-stack-ci.yml`: two web replicas (both observed serving), 40 MB upload stored in the emulator and read back byte-exact through the media host, message received live, reaction received live through the database queue and the worker, scheduler lists both jobs, no pending or failed jobs. Findings while building it: `up --wait` needs one-off services to be dependencies and refuses a disabled healthcheck; a variable in nginx `proxy_pass` drops the URI part; the emulator is RustFS (MinIO no longer ships images) and honours bucket policies for anonymous reads, which stands in for CloudFront. 2.3 `backend/.env.aws.example` + `EnvContractTest` (caught the dead `MAIL_ENCRYPTION` key on its first run). 2.4 roles in `docker/bin/reacti`; `migrate --isolated` needs the cache table, so a fresh database migrates with `CACHE_STORE=array` once (compose does this; on AWS the dump load precedes the first migrate). Not proven here and closed on day one: real S3 ACL/KMS/OAC, real ALB websocket behaviour, real RDS TLS.

### Phase 3: infrastructure as code and the deploy pipeline (~1 to 2 weeks)
| Step | What | Gate |
|---|---|---|
| 3.1 | `infra/bootstrap/` (per account: state bucket, OIDC provider, deploy role, Budgets, CloudTrail hookup). Applied once by hand on day one with `--dry-run` support. | `terraform validate` + `test` |
| 3.2 | `infra/modules/reacti-stack/`: VPC (2 AZ, public subnets for tasks, private for RDS), SGs, ALB + listeners + rules (incl. the Cloudflare header rule and the `/uploads/*` redirect) + ACM, ECR (lifecycle: keep last 10 tagged, expire untagged), ECS cluster + 3 services + 4 task definitions (secrets from SSM, awslogs, ulimits, `stopTimeout` 60 for reverb), task roles (S3 + KMS), RDS + parameter group (`require_secure_transport`, utf8mb4, UTC; the VPS is UTC too) + log exports, S3 (versioning, 7-day noncurrent expiry, `prevent_destroy`) + KMS (rotation on, CloudFront grant) + bucket policy, a `migration/` prefix for dumps with a 7-day expiry, CloudFront + OAC + ACM (us-east-1) + alias, Cloudflare records, SSM parameters (placeholders; the Firebase JSON is ~2.3 KB, under the 4 KB standard limit), CloudWatch log groups (30 d), the alarms from section 2.1, SNS → email. | `terraform test` asserts: RDS storage encrypted, deletion protection on, not publicly accessible; S3 block-public-access all four, versioning on; task role has the KMS actions; key policy has the CloudFront statement; CloudFront OAC and HTTPS-only; ALB idle timeout 300; the 403 rule precedes the default; web/reverb SGs only admit the ALB SG; task CPU/memory per environment; log retention set. `tflint`, `trivy config` clean. |
| 3.3 | `infra/envs/staging` and `infra/envs/prod` roots; `infra/README.md` with the exact apply order. | `terraform validate` both; plan diff between the two roots is only sizes and names |
| 3.4 | GitHub environment `staging` created (only `production` exists today). `aws-deploy.yml`: `workflow_call` reusable job with inputs `environment`, triggered by `staging-deploy-aws.yml` (push to `develop`, later) and `prod-deploy-aws.yml` (push to `main`, GitHub `production` environment approval, later). Steps: OIDC → build → push (SHA tag) → render 4 task definitions → RDS manual snapshot (prod only, async) → run-task migrate with `run-task-assign-public-IP: ENABLED` (no NAT, so the task needs a public IP to pull the image), wait, fail on non-zero → deploy web, reverb, worker with stability wait → post-deploy smoke (the existing `tests/Smoke` suite) against the environment URL. Input `skip_migrate` for the first deploy of an environment, which happens **after** the database load. Until day one it runs on `workflow_dispatch` with `dry_run: true` which stops after rendering. | dry run green; rendered task definitions diffed against the env contract (2.3) |
| 3.5 | `infra/scripts/`: `fill_ssm.sh` (reads a local `.env`-style file, writes SecureStrings; `--dry-run`), `media_sync.sh` (rclone from the VPS to S3 with checksum verify and counts, using a short-lived IAM access key for a `media-migration` user that is deleted on day 30; `--dry-run`), `db_move.sh` (on the VPS: `mysqldump --single-transaction --set-gtid-purged=OFF --no-tablespaces` with routines/triggers/events off and `DEFINER` stripped, upload to `s3://<bucket>/migration/`, then `aws ecs run-task` the `dbload` task definition, wait, and compare row counts and `CHECKSUM TABLE` per table from a second one-off task; `--dry-run`; `--reverse` for rollback dumps RDS the same way and loads into the VPS, skipping `cache`, `sessions`, `jobs`), `cutover_check.sh` (uses `curl --resolve` so SNI and the `Host` match, hits every health URL and asserts `X-Reacti-Origin`), `rollback.sh` (includes a Cloudflare cache purge, because the `/uploads/*` 301 is cacheable). RDS is never public. | each has a bats or pytest test of its argument handling and dry-run output |
| 3.6 | **Cloudflare**: Terraform owns the ACM validation CNAMEs and the `ws-*`/`media-*` records (DNS-only); the apex/API records are documented as an exact table (type, name, target, proxy on/off) for both environments; a Transform Rule adds `X-Reacti-Edge: <secret>` on the way to the origin (the secret lives in SSM and the ALB rule); a new Cloudflare API token scoped to DNS edit on `reacti.io` is stored in `.local-secrets/` and as a GitHub secret for the Terraform workflow. | reviewed; `terraform test` covers the records |

### Phase 4: paperwork and rehearsal (parallel with 3)
| Step | What | Gate |
|---|---|---|
| 4.1 | Privacy policy text ready: AWS (Tel Aviv, Israel) replaces Hostinger (UK) and the US realtime line; Resend added; Android/Google Play mentioned. Published on cutover day (admin page `/admin/dynamic-page/edit/1`). | draft in `docs/legal/` |
| 4.2 | `docs/ops/aws-day-one.md` (section 5) and `docs/ops/aws-cutover.md` (section 6) finished, every command copied from a script. | dry-runs of all scripts |
| 4.3 | AWS Activate application prepared (needs: AWS Builder ID, business email, website, product and traction summary; no architecture document is required). | Achia submits on day one |
| 4.4 | Rollback and restore drills written: restore an RDS snapshot to a new instance and point staging at it; repoint Cloudflare back to the VPS. | run on staging in Phase 5 |

### Phase 5: day one on AWS, staging (when access arrives; 1 day + 1 week soak)
1. Management account: root MFA, Organizations, two member accounts via the
   `Workloads` OU, Identity Center user for Achia, SCP for regions, Budgets,
   organization CloudTrail. Confirm D1 (region) with `aws ssm
   get-parameters-by-path --path /aws/service/global-infrastructure/regions/<region>/services`.
2. Submit the Activate application.
3. Bootstrap `reacti-staging` (`infra/bootstrap`), then `terraform apply`
   `infra/envs/staging` (one pass; Terraform writes the ACM validation
   records into Cloudflare itself).
4. `fill_ssm.sh staging` from the staging `.env` values (and a fresh
   `APP_KEY`, JWT secret, Reverb secret for staging).
5. Push the image (`staging-deploy-aws.yml` with `skip_migrate`, which
   builds, pushes and registers the task definitions but starts nothing
   that needs the schema), then **load the database first**:
   `db_move.sh staging` (dump → S3 → `dbload` task). Only then deploy the
   three services and run the migrate task (a no-op on a loaded schema).
6. **One real S3 upload** through the API to confirm the
   `bucket-owner-full-control` ACL and the KMS grants (section 8, U1).
7. Media: `media_sync.sh staging` (8 MB), then `rclone check`.
8. Flip Cloudflare: `staging.reacti.io` origin → staging ALB (proxied),
   `ws-staging.reacti.io` → ALB (DNS-only), `media-staging.reacti.io` →
   CloudFront (DNS-only). Staging TestFlight build with the new hosts.
9. Soak one week: synthetic-perf workflow, smoke suite, a real device each
   day, Sentry quiet, CloudWatch alarms quiet, cost explorer matches the
   estimate. Restore drill (4.4). Delete the Hostinger staging site at the
   end of the week.

### Phase 6: production cutover (one evening, ~45 minutes, after the staging soak)
Preconditions: staging green for 7 days; app 1.8.0 live for ≥ 2 weeks and
the legacy realtime connection removed; prod on the database drivers for ≥ 1
week; `php artisan down` tested on prod with the bypass secret.

| T | Step | Check |
|---|---|---|
| T-7 d | Bootstrap + `terraform apply` prod; `fill_ssm.sh prod` with **new** `APP_KEY`, `JWT_SECRET`, Reverb key/secret and DB password (the old ones lived on a box the agency had root on; the JWT change logs every user out once at cutover, announced in advance); push the image with `skip_migrate`; `db_move.sh prod` loads today's dump (rehearsal 1); deploy the services; `cutover_check.sh prod --direct` against the ALB (bypassing Cloudflare, with the edge header); bulk `media_sync.sh prod` (1.9 GB, live, repeatable). From now on every push to `main` deploys to **both** Hostinger and AWS so the two never drift; code freeze on `main` from T-1 d. | `cutover_check.sh` green on the raw ALB |
| T-1 d | Rehearsal 2: `db_move.sh prod` again (drop and reload), migrate task, smoke passes. Re-run `media_sync.sh` (delta). Lower the `ws.reacti.io` TTL to 60 s. | counts match |
| T-0 | Announce in the tester group. | |
| +0 | VPS: `php artisan down --secret=<uuid> --retry=120`; stop the VPS worker. | app shows the maintenance screen |
| +2 min | `db_move.sh prod`: dump (seconds), to S3, `dbload` task into RDS, compare row counts and `CHECKSUM TABLE` for all 28 tables. The dump carries the `cache` table and with it the "down" flag (maintenance driver = cache since 1.4), so AWS comes up in maintenance mode too, which is what we want until +18; `/up` is exempt, so the ALB keeps the tasks healthy. | all equal |
| +8 min | `media_sync.sh prod` final delta + `rclone check`; counts equal (718+). | equal |
| +12 min | Run the prod deploy workflow (migrate task is a no-op, services already up); `cutover_check.sh prod`. | green |
| +15 min | Cloudflare: `reacti.io` origin → prod ALB (proxied; no propagation) and the Transform Rule on. `ws.reacti.io` → ALB (DNS-only, 60 s TTL). `media.reacti.io` is already a Terraform-managed record. Backend `REVERB_HOST=ws.reacti.io` was already set in SSM. | `curl https://reacti.io/up` answers `x-reacti-origin: aws` (header added in 1.7) |
| +18 min | `php artisan up` on AWS (ECS Exec). Real device: login, send a photo, open it on a second device, reaction arrives live, push arrives. Insights site still updating (PostHog unaffected). | |
| +30 min | Publish the privacy policy text (4.1). Watch Sentry, ALB 5xx, CloudWatch for 30 minutes. | quiet |
| +60 min | **Decision point: keep or roll back** (section 7). | |
| +1 day | Remove the VPS from the staging/prod deploy workflows; the Hostinger workflows are deleted in the merge of `aws-migration`. | |

### Phase 7: afterwards
- Day 30: final Hostinger snapshot downloaded (DB dump + media tarball to S3
  Glacier in the prod account), delete the `media-migration` IAM user,
  cancel the VPS. The Reverb app key compiled into the app is rotated with
  the next app release after cutover, using two `apps` entries in
  `config/reverb.php` for one release cycle (the secret was already rotated
  at T-7 d).
- Follow-ups, each its own small plan: F1 Multi-AZ RDS when there is an
  uptime target; F2 signed media URLs (needs the app to refresh expired
  URLs); F3 SQS queue and Valkey cache when the database shows it; F4 a
  second Reverb task with `REVERB_SCALING_ENABLED` + Valkey past ~1,000
  concurrent connections; F5 private subnets + fck-nat when tasks must not
  have public IPs; F6 direct-to-S3 uploads from the phone (`temporaryUploadUrl`)
  to take video bytes off the API; F7 GuardDuty on staging if the prod
  number is small; F8 WAF on the ALB if abuse appears.

### Timeline (effort, not calendar)
Phase 0: 1 day. Phase 1: 5 days plus the App Store review for 1.8.0. Phase
2: 4 days. Phase 3: 7 days. Phase 4: 2 days. Total before day one: ~4 weeks
of Claude Code work, spread across however many calendar weeks Achia wants.
Day one: 1 day. Staging soak: 7 days. Production cutover: 1 evening. Old
server: 30 more days.

---

## 5. Day-one runbook (what Achia does, in order)

Console steps are the only ones Claude cannot run; everything else is a
script with `--dry-run` that was exercised in CI.

1. Create the management account with `aws-root@reacti.io` (a mailbox that
   forwards to Achia), a hardware or app MFA on root, a phone number, and
   alternate billing and security contacts. Never use this account for
   workloads.
2. Organizations → create `Workloads` OU → create `reacti-staging` and
   `reacti-prod` (each with its own `aws-<env>@reacti.io` alias). Enable
   centralized root access so member accounts have no root passwords.
3. IAM Identity Center → one user (Achia), `AdministratorAccess` permission
   set on all three accounts. Install the AWS CLI locally, `aws configure
   sso`. From here on Claude runs the scripts under this SSO session.
4. Run `infra/bootstrap` for staging, then prod (state bucket, OIDC
   provider, deploy roles, Budgets at $100 staging / $250 prod, CloudTrail).
5. GitHub: environments `staging` and `production` get the role ARNs as
   variables (not secrets; they are not secret).
6. Phase 5 steps 3 to 9.
7. Apply for AWS Activate.

---

## 6. Cutover runbook
Section 4, Phase 6, step by step with the scripts in `infra/scripts/`. The
full version with every command lives in `docs/ops/aws-cutover.md`
(written in Phase 4).

## 7. Rollback
- **Before the Cloudflare flip:** nothing has changed for users; stop.
- **Within the 60-minute decision window:** `rollback.sh`: Cloudflare
  origin back to the VPS and the Transform Rule off, `ws.reacti.io` back to
  the VPS Reverb, Cloudflare cache purge (the `/uploads/*` 301 is
  cacheable), `php artisan up` on the VPS. Seconds of impact. Any rows
  written on AWS in that window are dumped from RDS and loaded into the VPS
  (`db_move.sh --reverse`, skipping `cache`/`sessions`/`jobs`), media delta
  `rclone sync` back. Users who logged in during the window were issued
  tokens signed with the new JWT secret; they log in again.
- **After the window:** AWS is the system of record; a problem is fixed
  forward. The VPS stays frozen for 30 days as the last resort.
- **RDS mistakes:** PITR to any second within 14 days, into a new instance;
  the restore drill (4.4) was done on staging.

## 8. Known unknowns (closed on day one, each has a fallback)
| # | Unknown | Fallback |
|---|---|---|
| U1 | Flysystem always sends an ACL on PUT and ACL-disabled buckets reject anything but `bucket-owner-full-control`; the S3 emulator in CI does not enforce this, so the config (`options.ACL`) is set from the start and one real upload on day one confirms it, together with the KMS grants. | Known failure mode with a one-line config fix; if it still fails, the error names the ACL. |
| U2 | RDS MySQL 8.4 default parameter values (`time_zone`, `character_set_server`, `sql_mode`). | The custom parameter group pins all three; `describe-engine-default-parameters` on day one just confirms. |
| U3 | Whether AWS Activate credits and the new-account $100 to $200 credits stack in Organizations member accounts. | Cost without any credit is ~$205/mo; Budgets alert at 80%. |
| U4 | Cloudflare's idle websocket cut-off (~100 s, forum-sourced) if `ws.reacti.io` is ever proxied. | We keep it DNS-only; Reverb pings every 60 s anyway. |
| U5 | GuardDuty cost for two small accounts. | 30-day trial decides. |

## 9. Risks
- **Realtime for installs that never update** (pre-1.8.0 apps point at the
  agency box). Mitigated by the two-connection transition window in 1.3;
  after it ends, those installs still get push notifications and see new
  messages on open. With 38 users this is a message in the tester group.
- **The agency box disappears before 1.3 ships.** Realtime stops for
  everyone until 1.8.0. This risk exists today regardless of the plan; 1.3
  removes it, which is why Phase 1 starts now.
- **Fargate tasks have public IPs.** Only the ALB SG can reach them on
  8080; everything else is dropped. Listed follow-up F5 removes the IPs.
- **The ALB is reachable directly** (it must be, for the websocket host).
  API requests for `reacti.io` that do not carry the Cloudflare-added
  header are answered 403 by a listener rule, so the API stays behind
  Cloudflare; the websocket and media hosts are meant to be direct.
- **Single-AZ RDS**: a failed AZ means a restore from PITR (minutes to an
  hour). Acceptable at this stage; F1 when there is an SLO.
- **Cost surprise.** Budgets with forecast alerts in every account; the
  first month's bill is compared to section 10 and anything unexplained is
  chased before the production move.

## 10. Costs (eu-central-1 list prices from the AWS bulk price list, 730 h/month; Tel Aviv, the chosen region, is ~10% higher)
| Item | Prod | Staging |
|---|---|---|
| Fargate ARM: web 2 × (0.5 vCPU, 1 GB) / 1 × (0.25, 0.5) | $33.16 | $8.29 |
| Fargate ARM: reverb 1 × (0.25, 0.5) | $8.29 | $8.29 |
| Fargate ARM: worker 1 × (0.25, 0.5) | $8.29 | $8.29 |
| ALB (fixed + LCU) | ~$22 | ~$22 |
| Public IPv4 (ALB 2 + tasks 4 / 3) | $21.90 | $18.25 |
| RDS db.t4g.micro Single-AZ + 20 GB gp3 + backups | $16.61 | $16.61 |
| S3 (10 GB) + KMS key + CloudFront (free tier) | ~$2 | ~$2 |
| ECR, CloudWatch Logs, SSM, ALB logs | ~$4 | ~$3 |
| **Total** | **~$116** | **~$87** |

Both environments ≈ $205/month list in Frankfurt, ≈ **$225/month in Tel Aviv** (the chosen region, D1). Multi-AZ RDS
+$16; NAT gateway +$38 per environment; a second web task in staging +$8.
Credits: new accounts get $100 at signup and up to $200 over six months;
Activate Founders is $1,000 (up to $5,000) for self-funded startups,
Portfolio up to $200,000 with an accelerator/VC referral. Compare: Hostinger
KVM 4 is ~$25/month.

## 11. Sources (primary, read for this plan)
AWS: Fargate / ECS task definitions, networking, storage, Exec and the
Fargate regions page; ALB listeners, attributes and websocket support;
RDS MySQL version management, Extended Support charges, importing with
reduced downtime, external replication procedures, SSL, automated backups,
PITR, cross-region backup replication; S3 Block Public Access, Object
Ownership, presigned URLs; CloudFront OAC and signed URLs; AWS Service
Terms §1.14 (DPA); Organizations best practices and the multi-account
whitepaper; CloudTrail cost management; Budgets; GuardDuty pricing; the
regional services table (`api.regional-table.region-services.aws.a2z.com`)
and the bulk price lists for ECS, RDS, S3, ELB, EC2, VPC, CloudFront, DMS in
eu-central-1, eu-west-1, il-central-1; App Runner availability change; ECS
Express Mode docs; AWS Startups guide to Activate. GitHub: OIDC in AWS,
environments, `configure-aws-credentials` v6, `amazon-ecs-deploy-task-definition`
v2, `amazon-ecs-render-task-definition`. HashiCorp: S3 backend (native
locking), `terraform test` mocking, 1.11 upgrade guide. Laravel: Reverb,
broadcasting (`broadcastVia`, present in 11.53.1), filesystem, scheduling,
configuration (maintenance mode); Flysystem AWS S3 v3 adapter source.
LocalStack service tiers; RustFS; serversideup/php docs; Cloudflare TTL,
websockets and network-ports docs; Pusher pricing. Reverb-in-production
write-up (50k connections) for the ulimit/ext-uv notes.
