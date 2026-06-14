# Plan — Reacti analytics & statistics platform (2026-06-14)

**Author:** Cowork (operator session) · **Executor:** Claude Code · **Owner:** Achia
**Decisions (Achia, 2026-06-14):** managed cloud on **free tiers** (migrate to
self-host later if wanted); build **product + performance together** as one
foundation.

Goal: a scalable analytics foundation that answers both "how is Reacti being used
and growing?" and "is it fast and healthy?" — covering everything from messages
sent (private vs group, media vs text), the reaction/patent flow, signups and
retention, to send/upload speed, app-open time, API latency, and crash rates —
wired to **production, staging, and the test suite**, and built so new metrics
are cheap to add now and at scale.

## Two non-negotiable guarantees (Achia, 2026-06-14)

1. **No user-facing behavior change — observation only.** Every existing screen
   and flow must behave **identically** with analytics present. Tracking calls are
   fire-and-forget (async, try/caught, sampled) and can fully fail without affecting
   the user. The **patent send→record→reaction path must be byte-for-byte
   unchanged** — run its regression harness on any PR touching the send/record path.
   The *only* user-visible addition permitted anywhere in this plan is the Phase 4
   analytics opt-out toggle.
2. **Staging-verified before anything reaches the real app or production.** All
   analytics work lands on `develop` → the **staging** backend + a **staging
   TestFlight build**, with events flowing only to the **staging** PostHog/Sentry
   projects. Achia verifies on staging (the app behaves normally **and** the stats
   appear correctly) **before** any `develop`→`main` promotion or production deploy.
   Never promote to `main`, deploy to prod, or point at the **prod** analytics
   project until Achia signs off on staging.

---

## Tool stack (managed, free-tier, EU data region)

| Layer | Tool | Why |
|---|---|---|
| Product / usage analytics | **PostHog Cloud (EU)** | Events, funnels, retention, cohorts, dashboards. Generous free tier (~1M events/mo). Flutter SDK + PHP. Open-source → **self-host later** with no rewrite. Privacy-friendly. |
| Errors + performance (app **and** backend) | **Sentry (SaaS, free/Developer)** | Crash-free %, error rates, and **performance tracing** ("why is sending slow") for both `sentry_flutter` and `sentry-laravel`. OpenTelemetry-compatible. |
| Backend ops quick-view | **Laravel Pulse** | Built-in, free, in-app: slow requests, slow/N+1 queries, queue depth, job failures. No external dependency. |
| Vendor-neutral plumbing | **OpenTelemetry** (design seam now, route later) | Future-proofing: instrument once, route to Sentry today, Grafana/warehouse tomorrow. |
| Unified "exec board" (Phase 5) | **Grafana or Metabase** + optional warehouse (ClickHouse/BigQuery) | Single pane pulling PostHog + Sentry + warehouse for arbitrary SQL once needs grow. |

Alternatives considered: Amplitude/Mixpanel (excellent product analytics, strong
free tiers) — kept as drop-in options behind the abstraction below; PostHog wins
here on privacy + self-host + all-in-one. Firebase Analytics is already in the app
and stays as a no-cost backup signal, but is too limited to be the primary board.

---

## Design principles (these are what make it scalable)

1. **Vendor-agnostic abstraction.** All events flow through one seam — an
   `AnalyticsService` interface in the app and a single `Analytics` emitter in the
   backend. Feature code calls `analytics.track(Event.messageSent, props)`, never a
   vendor SDK directly. Swapping/adding a vendor touches one file.
2. **One central event catalog.** Every event + its allowed properties is defined
   once in `docs/analytics/event-catalog.md` and as typed constants in code
   (`Events`, `Props`). No ad-hoc string events. This is what keeps "all the stats
   we can dream of" consistent and extensible.
3. **Privacy-first, enforced in code (non-negotiable — this is a recording app).**
   Never send message content, media, faces, names, emails, phone numbers, or
   tokens. Only **metadata**: counts, type (`text`/`media`/`reaction`), scope
   (`private`/`group`), durations (ms), size buckets, a **pseudonymous hashed user
   id**, timestamps. The abstraction enforces a **property allowlist** and drops
   anything else; a test fails the build if a disallowed property is emitted. EU
   data region. See the Privacy section.
4. **Measure on both ends.** Client-measured (real user experience: `send_ms`,
   `upload_ms`, `cold_start_ms`) **and** server-measured (`processing_ms`, API
   latency, throughput). Cross-checking the two is how you find where slowness
   lives.
5. **Analytics is fire-and-forget — it must never break or slow a send.** Every
   analytics/tracing call is async, wrapped in try/catch, sampled where needed, and
   can fully fail without affecting the user flow. **The patent send→record→reaction
   path must behave identically with analytics on or off** (covered by the existing
   patent-flow regression harness).
6. **Per-environment separation.** On the free tier, **one** PostHog project +
   key shared by prod and staging, separated by the `analytics_env` event property
   (and Sentry `environment`), selected by the existing `--dart-define` / `.env`
   config. (Upgrading to separate projects later is a key swap behind the
   abstraction — no code change.) In tests, analytics is a no-op fake — and
   instrumentation is *asserted*.

---

## What to measure — the metrics taxonomy

### Product & usage (PostHog)
- **Messaging volume:** messages sent — total, by **type** (text / media / reaction),
  by **scope** (private / group). Media uploads + size distribution.
- **Reaction / patent flow:** reaction recorded, reaction sent, reaction viewed;
  **capture success rate**; time from `mark-viewed` → reaction uploaded.
- **Users & growth:** DAU / WAU / MAU, new registrations, **signup funnel**
  (register → OTP verify → first message), **retention** curves (D1/D7/D30), churn.
- **Engagement:** sessions, session length, messages per active user, groups
  created/joined, group size distribution, friends added.
- **Social graph:** number of groups, group sizes, friend connections.

### Performance & speed (Sentry + custom timings)
- **Send latency:** tap-send → server-ack (client) and server processing (backend),
  p50/p95/p99.
- **Upload:** media upload duration + throughput (MB/s) by size bucket and network
  type; **failed-upload rate**.
- **App open:** cold-start time, time-to-interactive.
- **Realtime:** Pusher delivery latency (send → received on the other device).
- **API:** endpoint latency p50/p95/p99, error rate + status distribution by endpoint.
- **Reliability:** crash-free sessions %, jank/ANR, **failed-send rate**, error rate.

### Ops / infra (Pulse + hosting)
- Request rate, slow requests, slow/N+1 queries, queue depth, job failures, push
  (FCM) delivery success, CPU/mem (from Hostinger metrics).

### Business (derived; warehouse in Phase 5)
- Growth rate, virality (invites → signups), cohort retention, feature adoption.

---

## Architecture / data flow

```
 Flutter app ──► AnalyticsService (allowlist + hashing) ──► PostHog (usage)
      │                                              └────► Sentry (errors, perf spans)
      │   send_ms / upload_ms / cold_start_ms measured on-device
      ▼
 Laravel API ──► Analytics emitter ──► PostHog (server events)
      │     middleware: endpoint, latency, status ──► Sentry (traces) + Pulse
      │     domain events: message persisted {type, scope}
      ▼
 Dashboards: PostHog (usage) + Sentry (perf/errors) + Pulse (ops)
             └─ Phase 5: Grafana/Metabase single-pane + warehouse
```

---

## Environment wiring (prod / staging / testing)

> **Single PostHog project, tagged by environment (free-tier reality, Achia
> 2026-06-15).** PostHog's free tier is one project, so prod and staging share
> **one** PostHog project + key and are separated by the **`analytics_env`**
> event property (`staging` | `production`) and the Sentry `environment` tag —
> not separate projects/keys. Secrets: `POSTHOG_KEY` (single), `SENTRY_DSN_APP`,
> `SENTRY_DSN_BACKEND`. The env is selected per build via `--dart-define`/`.env`,
> so dashboards filter by `analytics_env` and the two never get confused.

- **Production:** `ANALYTICS_ENV=production`; Sentry `environment=production`.
  Real users, strict privacy + consent gating. **Enabled only after staging
  sign-off.**
- **Staging:** `ANALYTICS_ENV=staging`; Sentry `environment=staging`, selected via
  `--dart-define`/`.env`. Validate instrumentation here before prod; events are
  segmented from prod by `analytics_env`.
- **Testing / CI:** `AnalyticsService` is a **fake** (no network). Two kinds of test
  wiring:
  1. **Instrumentation tests** — assert that key flows emit the right event with the
     right allowlisted props (app widget/unit tests + backend feature tests), run in
     the existing **"Analyze & Test"** / **"PHP Tests"** checks.
  2. **Synthetic performance tests** — a scheduled job measures send/upload/app-open
     latency against **staging** and records it over time (this is the
     testing-plan's deferred **Layer 3h** perf check, now with a home). Trend feeds
     the performance board and can alert on regressions.

---

## Privacy, consent & governance (front and center)

Reacti records people's faces — analytics done carelessly here is a serious risk.
Rules, enforced in code and tests:

- **Never collected:** message text/media, camera frames, names, emails, phone
  numbers, precise location, auth tokens, raw user ids.
- **Collected:** event name + allowlisted metadata only; **user id is hashed**
  (pseudonymous), so behaviour can be analysed without identifying a person.
- **Allowlist guard:** the abstraction drops any property not in the catalog; a unit
  test **fails the build** if a disallowed key is emitted.
- **EU data region** for PostHog + Sentry; configure **data retention** limits; sign
  the vendors' DPAs.
- **Consent:** add an **analytics opt-out** and respect it; align with the DG1
  consent context (`docs/PLAN-dg1-consent-flow-2026-06-12.md`). For EU users this
  ties into the GDPR/DSA posture already in motion.
- A `docs/analytics/privacy.md` documents exactly what is and isn't collected,
  retention, and user rights.

---

## Phased build (for Claude Code)

Small PRs off `develop`; keep required checks green; app-first; privacy-first;
analytics non-blocking; never regress the patent flow (run its harness on any PR
touching the send/record path). Don't start a new phase without telling Achia.

### Phase 0 — Foundations
- **Achia (accounts):** create **PostHog (EU)** and **Sentry** accounts. On the
  free tier this is **one PostHog project** (prod + staging share it, separated by
  the `analytics_env` event property) and Sentry app + backend projects; grab the
  single PostHog key + the two Sentry DSNs.
- **Claude Code:** define `docs/analytics/event-catalog.md` (events + allowlisted
  props) and the privacy allowlist; add per-env config (`POSTHOG_KEY`,
  `POSTHOG_HOST`, `SENTRY_DSN`, `ANALYTICS_ENV`) via `--dart-define` (app) and
  `.env`/secrets (backend), mirroring the existing `BASE_URL` pattern. No secrets in
  the repo.

### Phase 1 — Instrumentation foundation (app + backend, product + performance)
- **App:** `AnalyticsService` abstraction + privacy/allowlist guard + hashed user id;
  init PostHog + `sentry_flutter`; instrument: `app_open` (+`cold_start_ms`),
  `screen_view`, `message_sent` ({type, scope, send_ms}), `media_uploaded`
  ({upload_ms, size_bucket, network}), the reaction flow, and errors. Wrap
  send/upload/app-open in **Sentry performance transactions/spans**. All calls
  fire-and-forget.
- **Backend:** `sentry-laravel` + **Pulse**; API-metrics middleware
  (endpoint, latency, status) → Sentry + Pulse; domain event on message persist
  ({type, scope}) → PostHog; structured logs with `trace_id`.
- **Tests:** fake AnalyticsService; assert events fire with correct allowlisted props.

### Phase 2 — Dashboards (the board)
- **PostHog dashboards:** messaging volume (type × scope), media, reaction-flow
  success, DAU/WAU/MAU, signup funnel, retention, engagement.
- **Sentry dashboards:** send/upload/app-open latency (p50/95/99), API latency,
  crash-free %, error/failed-send rates, realtime delivery.
- **Pulse** for ops. Ship `docs/analytics/README.md` mapping every metric → where to
  see it.

### Phase 3 — Testing wiring
- Land the instrumentation tests into CI; add the **synthetic performance test**
  against staging (scheduled) recording send/upload/app-open latency over time
  (the Layer 3h perf check) + a regression alert threshold.

### Phase 4 — Privacy, consent & governance
- Analytics **opt-out** wired to the consent context; EU region + retention set;
  `docs/analytics/privacy.md`; the allowlist-enforcement test; DPAs signed (Achia).

### Phase 5 — Unified board + scale (future, when needed)
- Single-pane **Grafana/Metabase** board pulling PostHog + Sentry (+ optional
  **ClickHouse/BigQuery** warehouse for arbitrary SQL); regression **alerting**;
  evaluate **self-hosting PostHog** for full data ownership at scale. The
  abstraction + OpenTelemetry seam make all of this additive, not a rewrite.

---

## What Achia provides (no coding)
- Create the PostHog (EU) + Sentry accounts and the prod/staging projects; hand the
  keys to Claude Code (via GitHub secrets / local files for `gh secret set` — never
  pasted in chat). Sign the vendor DPAs. Decide the analytics retention window.

## Definition of done (Phases 1–4)
- Every event flows through the abstraction with the allowlist enforced (disallowed
  props fail a test); user ids are hashed; no content/PII leaves the device or server.
- Both boards exist and populate from **staging** then **production**: usage
  (sends private/group/media/reaction, DAU, funnel, retention) and performance
  (send/upload/app-open/API latency, crash-free %).
- Instrumentation is asserted in CI; the synthetic perf test runs against staging.
- The patent flow is byte-for-byte unaffected with analytics on (harness green).
- `docs/analytics/{event-catalog,README,privacy}.md` exist and are accurate.

---

## Kickoff prompt for Claude Code

```text
Read .claude/skills/clean-code-standards/SKILL.md and
docs/PLAN-analytics-stats-2026-06-14.md. Build the analytics foundation — managed
cloud (PostHog EU + Sentry), free tiers, product + performance together.

Start with Phase 0, then Phase 1. Hard rules:
- NON-NEGOTIABLE #1 — NO user-facing behavior change. This is observation only;
  every existing screen and flow must behave IDENTICALLY. The only user-visible
  addition allowed anywhere in this plan is the Phase 4 opt-out toggle.
- NON-NEGOTIABLE #2 — STAGING-verified first. Everything lands on develop → the
  staging backend + a staging TestFlight build, with events going ONLY to the
  STAGING PostHog/Sentry projects. Achia verifies on staging before ANY develop→main
  promotion, prod deploy, or use of the PROD analytics project. Never touch
  main/prod/prod-analytics until she signs off on staging.
- ALL events go through one AnalyticsService abstraction (app) + one Analytics
  emitter (backend) — never call a vendor SDK from feature code.
- Privacy-first: enforce a property ALLOWLIST from docs/analytics/event-catalog.md,
  HASH user ids, and NEVER emit message content/media/PII/tokens. Add a test that
  FAILS the build if a disallowed property is emitted.
- Analytics is fire-and-forget: async, try/caught, sampled — it must NEVER slow or
  break a send/upload. The patent send→record→reaction path must behave identically
  with analytics on; run the patent-flow harness on any PR that touches it.
- Per-env keys via --dart-define (app) and .env/secrets (backend); no secrets in the
  repo. Separate PostHog projects + Sentry environments for prod vs staging.
- In tests, AnalyticsService is a fake; assert events fire with correct allowlisted
  props (into "Analyze & Test" / "PHP Tests").

Phase 0: write docs/analytics/event-catalog.md (events + allowlisted props) + the
per-env config scaffolding, and tell Achia exactly which PostHog/Sentry projects +
keys to create. Then Phase 1: the app + backend instrumentation (message_sent
{type,scope,send_ms}, media_uploaded {upload_ms,size_bucket}, app_open
{cold_start_ms}, reaction flow, screen_view, errors; backend API-metrics middleware
+ message-persist events + Sentry + Pulse). Small PRs off develop, keep checks
green, don't promote to main or deploy. Report after Phase 0 with the exact account/
project setup Achia must do, then pause for her to create them before Phase 1 keys.
```
