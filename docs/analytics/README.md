# Reacti analytics — the board (where to see each metric)

Phase 2 of `docs/PLAN-analytics-stats-2026-06-14.md`. Maps every metric to the
event that powers it and **where to view it** (PostHog for product/usage,
Sentry for errors/performance). Events are defined in
`docs/analytics/event-catalog.md`; privacy in `docs/analytics/privacy.md`.

**Two tools, one identity.** App and backend events share one salted
`distinct_id` (same user = one person). Everything is tagged with
`analytics_env` (`staging` | `production`) — **always filter your insights/
dashboards by `analytics_env` = the env you mean** so staging and prod never mix.

> The dashboards themselves are built in the PostHog / Sentry UIs (an ingest key
> can't create them). This doc is the build sheet: each insight lists the event,
> the breakdown, and the steps. To script them instead, provide a PostHog
> **personal** API key via `gh secret set` and they can be created via the API.

---

## PostHog — product & usage

Create one **dashboard "Reacti — Product (staging)"** and add the insights below
(duplicate as "(production)" with the env filter flipped once prod is enabled).
Global filter on every insight: `analytics_env = staging`.

| Insight | Type | Event → breakdown |
|---|---|---|
| **Messages sent — type × scope** | Trends (bar, by day) | `message_sent`, breakdown by `message_type` then `scope` |
| **Media uploads + size mix** | Trends | `media_uploaded` count; second insight: breakdown by `size_bucket` |
| **Reaction capture success rate** | Formula | `reaction_recorded` where `result=success` ÷ total `reaction_recorded` |
| **Reaction sends** | Trends | `reaction_sent`, breakdown by `scope` |
| **Mark-viewed → reaction latency** | Trends (numeric) | `mark_viewed_to_reaction`, aggregate **p50/p90** of `elapsed_ms` |
| **DAU / WAU / MAU** | Trends (Unique users) | any event (e.g. `app_open`), unique `distinct_id`, rolling 1/7/30-day |
| **Signup funnel** | Funnel | `register_started` → `otp_verified` → `first_message_sent` |
| **Retention** | Retention | performed `app_open` → returned and performed `message_sent` (D1/D7/D30) |
| **Engagement — messages per active user** | Formula | total `message_sent` ÷ unique `distinct_id` |
| **Groups & friends** | Trends | `group_created`, `group_joined` (by bucket), `friend_added` |
| **Server vs client sends (sanity)** | Trends | overlay `message_sent` (app) vs `message_persisted` (backend) — should track |
| **API traffic & latency** | Trends (numeric) | `api_request`, breakdown by `endpoint`; aggregate p50/p90 of `latency_ms` |

Notes:
- **Latency percentiles** (`send_ms`, `upload_ms`, `cold_start_ms`, `elapsed_ms`,
  `latency_ms`) use PostHog's numeric **p50/p90/p95** aggregation on the property.
- **`endpoint`** is the route pattern (`api/auth/chat/send/{id}`), so per-endpoint
  views never explode by id.

---

## Sentry — errors & performance

One Sentry **project per side** (app, backend), each filtered by
`environment = staging`.

| View | Where in Sentry |
|---|---|
| **Crash-free sessions / users %** | Releases → Crash Free (app project) |
| **Error rate & top issues** | Issues, filtered `environment:staging` (both projects) |
| **API / transaction latency p50/p75/p95** | Performance → Transactions (auto HTTP + navigation spans) |
| **Slow endpoints (backend)** | Performance, backend project, sorted by p95 duration |
| **Throughput / failure rate by transaction** | Performance → Transactions |

What Sentry covers automatically (no extra code): unhandled errors/crashes,
HTTP request spans, navigation/cold-start (app), and backend request traces
(`sentry-laravel`). `send_default_pii = false`, so bodies/PII are never attached.

> **Client send/upload as explicit Sentry spans is a future refinement.** Today
> send/upload/app-open durations live as PostHog numeric props
> (`send_ms`/`upload_ms`/`cold_start_ms`) — use the PostHog latency insights
> above for those. Wrapping them in named Sentry transactions
> (`message.send`, `media.upload`, `app.cold_start`) can be added later if you
> want them on the Sentry performance board too.

---

## Ops (no Pulse)

Backend ops are covered by **Sentry** (slow endpoints p95, error rates,
throughput) plus the PostHog **API latency** insight (`api_request.latency_ms`
by `endpoint`) and the **synthetic perf trend** — a PostHog Trends insight on
`synthetic_perf`, p90 of `latency_ms` broken down by `flow` (the scheduled
`synthetic-perf.yml` check against staging; alerts via a failing run on egregious
latency). Laravel Pulse was intentionally **not** added (it would pull in
Livewire for an app that uses none). If a specific gap appears later — live
**queue depth** or **N+1 query** detection — add those as targeted metrics
through the existing `Analytics` emitter (a new allowlisted event) rather than a
new dashboard stack.

---

## Conventions when adding a board
- Always filter by `analytics_env`.
- Build on **staging** first; clone to production only after staging looks right
  and prod analytics is enabled (see `privacy.md` → Production activation).
- New metric ⇒ add the event to `event-catalog.md` + the `Events`/`Props`
  constants (app + backend) first; the allowlist tests enforce it.
