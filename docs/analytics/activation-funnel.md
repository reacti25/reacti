# Beta activation funnel (Feature 4)

The wireframe's activation measurement, built in PostHog on top of the existing
event catalog (`event-catalog.md`).

## North-star metric

**% of new users who send OR receive their first reaction within 24h of signup.**

Chosen 2026-07-25 (Achia): broad, captures both sides of the loop, fast to read.
Revisit once real new-user data has accrued (does the definition still fit?).

## Dashboard

**Beta Activation Funnel** — PostHog project `202061` (EU):
<https://eu.posthog.com/project/202061/dashboard/848115>

| Insight | What it measures |
|---|---|
| ★ North-star: first reaction within 24h | signup_completed → "First reaction" within 24h |
| First-loop funnel | Signup → Demo done → Invite sent → Reacti sent → Delivered (7-day window) |
| New signups | daily `signup_completed` |
| Time to first loop (median) | signup_completed → first `reaction_sent` |
| Retention: 2nd Reacti within 7d | of users who sent a Reacti, how many send another |

"First reaction" is a PostHog **action** (`reaction_sent` OR
`message_received` with `message_type=reaction`) so the north-star counts both
sending and receiving.

## Events feeding it (all live, media-free)

| Funnel step | Event | Source |
|---|---|---|
| Signup | `signup_completed` | rx_signup_verify (Feature 4) |
| Demo done | `demo_reaction_completed` | demo Reacti (Feature 2) |
| Invite sent | `invite_shared` | invite (Feature 5) |
| Reacti sent | `message_sent` (`message_type=media`) | chat send |
| Delivered | `reaction_sent` | patent reaction upload |
| Received | `message_received` (`message_type=reaction`) | realtime delivery |

## Notes

- The funnel/north-star show empty at the top until `signup_completed` data
  flows (it was added in Feature 4; needs a build + real signups).
- Dashboards are managed via the PostHog API with a write-scoped personal key;
  the build scripts are ad-hoc (not in CI).
