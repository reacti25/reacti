# Reacti — Tester Feedback Triage

_Compiled 2026-07-14. Status verified against `develop`, feature branches, and `main` (prod = 1.3.1+15)._

## How to read this

- **Status** — where the work actually stands:
  - ✅ **Shipped-prod** — live in the App Store build.
  - 🟢 **On develop** — merged, will ride the next staging/TestFlight build → next release.
  - 🟡 **Branch-only** — built but not merged to develop yet.
  - 🟠 **Partial / different** — something shipped but not exactly what the tester asked.
  - 📋 **Planned only** — a brief/plan exists, nothing built.
  - 🔴 **Open** — no plan, nothing built.
- **Rec** — my recommendation: **Do now**, **Do next**, **Decide**, **Skip**.
- **Effort** — S (hours–1 day), M (2–4 days), L (a week+).

There is no `staging` git branch — "staging" = TestFlight builds cut from `develop`. So 🟢 On develop = queued for staging.

---

## 1. Already handled — confirm and move on

These map to feedback and are done. Nothing to decide except "verify on device."

| # | Feedback (tester) | Status | Evidence |
|---|---|---|---|
| 1 | Show **where the OTP was sent** on the verify screen (Tamar) | 🟢 On develop | PR #251, masked email shown on signup + forgot-password screens |
| 2 | **Skip** option on the "add contacts" prompt (Tamar) | 🟢 On develop | PR #250 — "Not now" soft-ask in `find_screen.dart` |
| 3 | Group-creation "+" too small / wrong hero button (Tamar, Tomer) | 🟠 Partial | PR #252/#253 moved create-group to a Chats header "+" and off the bottom bar. Re-homed, but see §4 for Jon's fuller nav idea |
| 4 | Notification opens app **but not the chat** (Shai) | 🟢 On develop | PR #326 deep-link to the correct chat |
| 5 | **Unseen badge** on the app icon (Shai) | 🟢 On develop | PR #328 unread app-icon badge (conversation count) |
| 6 | Light/dark **background by choice** (Gon) | ✅ Shipped-prod | Full System/Light/Dark theme + first-run appearance picker, in 1.3.1 |
| 7 | Read receipts (implied across notes) | 🟢 On develop | PR #254 + many follow-ups |
| 8 | Make media/reactions **smoother/faster** (Gon) | ✅ Mostly prod | Trigger-on-paint, prefetch, native-HTTP, compression; more perf work on develop for 1.3.2 |
| 9 | Simpler **media picker** (related to Tomer's "clearer creation") | ✅ Shipped-prod | 2-option Gallery/Camera picker, PR #270/#277 |

---

## 2. Built but not released — just needs merge/ship

| # | Feedback | Status | Note |
|---|---|---|---|
| 10 | **Edit sent text** (Ives) | 🟡 Branch-only | PR #330, 10-minute edit window, on `feature/message-menu-edit`. Not on develop — decide whether to land it in the message-menu batch |
| 11 | Message actions (forward, delete-for-me, exact delivered/read times) | 🟡 Branch-only | PR #331/#332. Adjacent to #10; ship together |

**Rec:** review and merge the message-menu batch (#329 Phase 1 is already on develop; #330–#332 are waiting). This clears Ives's edit request with no new work.

---

## 3. Quick wins — open, small, high polish-per-hour

All confirmed absent in code, no blocker, low risk. I'd batch these into one "tester polish" sprint.

| # | Feedback | Status | Rec | Effort | How |
|---|---|---|---|---|---|
| 12 | **Grey out the friend-request button** after sending, so you can't spam (Tamar) | 🔴 Open | Do now | S | Infra already tracks sent requests (`rx_get_sent_request`). Disable/relabel the button to "Requested" when a pending request exists |
| 13 | Search shows **everyone** — should match **username only** (Tomer) | 🔴 Open | Do now | S | Backend `UserService::userList` returns all users on empty query and matches name/phone/username. Change: require a query, match `username` (and maybe exact phone) only |
| 14 | Can't go **back to the intro/explainer** from login (Kobi) | 🔴 Open | Do now | S | `on_board_screen.dart` does a stack `replace` to login. Add a "Learn more / how it works" link on the login screen back into the carousel |
| 15 | **Tap to enlarge profile photo**; edit own (Shai) | 🟠 Partial | Do now | S | Editing your own avatar already exists. Missing: tap-to-enlarge. Wire the existing `FullScreenImageViewer` (used in chat) to the avatar |
| 16 | **Contacts privacy note** — reassure we don't store contacts (Kobi, Tomer) | 🟠 Partial | Do now | S | Soft-ask exists but says nothing about storage. Add one line ("We use contacts only to find friends and never store them" — _confirm the backend actually doesn't before writing this_) |
| 17 | **Flash control** from the camera (Shai) | 🔴 Open | Do next | S | No flash/torch anywhere. Add a flash toggle to `camera_capture_screen.dart` |
| 18 | Cancel photo → returns to **chat**; should return to **camera** (Shai) | 🔴 Open | Do next | S | By design today: discard unwinds to the composer. Change discard on the preview to re-open the camera instead of popping to chat |
| 19 | **Sounds + haptics** for in-app events (Shai) | 🔴 Open | Do next | S–M | None exist. Add `HapticFeedback` on send/receive/reaction and a couple of subtle sounds. Keep it tasteful and default-on-but-toggleable |

---

## 4. Bigger features — worth doing, need a decision

| # | Feedback | Status | Rec | Effort | My take |
|---|---|---|---|---|---|
| 20 | **Onboarding / first-run tutorial** — main screen is empty, no guidance; "product education"; AI-style coach that has you send a photo and reacts back (Gon, Kobi, Jon) | 📋 Planned only | **Do next — highest leverage** | M–L | This is the loudest, most-repeated theme (4 testers). Research brief exists but nothing is built. The empty-home + "I don't know what to do" problem is your biggest activation risk. Start with a coach-mark first-message flow + a scripted "demo bot" that reacts back — that teaches the core loop better than any carousel. The full AI chat can come later; a scripted bot gets 90% of the value at a fraction of the cost |
| 21 | Bottom bar = **Chats / People / Profile**, combine Friends+Requests, obvious **"Send reacti"** button (Jon) | 🟠 Partial | **Decide** | M | We shipped a 4-tab bar (Chat/Friends/Request/Profile). Jon wants 3 tabs + merged Friends/Requests + a hero "Send reacti" CTA. I agree with the direction — a clear primary action beats a hidden "+". Worth an A/B or a design pass before rebuilding the nav again |
| 22 | **Passwordless / Sign in with Google / Instagram** (Shai, Kobi) | 🔴 Open | **Do next** | M–L | Real signup-conversion win and repeatedly requested. Note: Apple **requires Sign in with Apple** if you offer any other social login, so start there — it's also the most native iOS fit. Backend has dormant Google scaffolding to reuse. Instagram login is not worth it (deprecated/awkward); do Apple, then maybe Google |
| 23 | **Send text AS a "reacti"** — mark a text so you capture the recipient's reaction ("I'm pregnant") (Jon) | 🔴 Open | **Decide — I like it** | M | Today reaction-capture is media-only. This extends the core mechanic to text, which is a genuinely novel use of the patent and very shareable. Needs a "send as reacti" toggle in the composer and a text-blur reveal path. Good candidate for a flagship 1.4 feature |
| 24 | Group: **react first to unlock** everyone else's reactions (🔒 "3 reactions waiting"); sender still sees each as it arrives (Jon) — plus Shai's "see all reactions **side by side**" | 🔴 Open | **Decide — I like it** | M | Strong engagement mechanic and it directly resolves Jon's other note that you can currently see others' reactions before sending your own. The "locked until you react" gate creates FOMO that drives opens — very on-brand. Combine with Shai's side-by-side grid for the reveal. My one caution: test that it doesn't frustrate people who just want to watch |
| 25 | **Disappearing mode** — both media and reaction deleted after viewing (Tomer) | 🔴 Open | **Decide** | M | Fits the ephemeral/privacy ethos well and testers expect it. Note the message-menu batch adds manual delete-for-everyone, which is different from auto-delete-after-view. Scope it as a per-message "vanish" toggle |

---

## 5. Recommend against / handle carefully

| # | Feedback | Status | Rec | My reasoning |
|---|---|---|---|---|
| 26 | Let users **choose the reaction video length** in seconds (Shai) | 🔴 Open (conflicts) | **Skip** | The fixed 4s silent-capture window is part of the patented core and is hard-frozen in the plans. Variable duration weakens the "everyone reacts the same way" symmetry and complicates the capture guarantee. Keep 4s |
| 27 | **Save / download photos** (Tomer) | 🔴 Open | **Decide — lean no** | Directly conflicts with the ephemeral, reaction-first ethos and with Tomer's own "delete after view" ask. If you add it at all, gate it behind sender permission per-message. Otherwise skip |
| 28 | **Screenshot / screen-record blocking** (Tomer, Jon) | 🔴 Open | **Do partial** | iOS **cannot** truly block screenshots — you can only (a) detect them and notify the sender (`UIApplication.userDidTakeScreenshotNotification`), and (b) render sensitive views black **during screen recording** via a secure layer. Do both for the blurred-media/reaction view; don't promise "unscreenshottable" |

---

## 6. Infra / ops — mostly blocked on you or on legal

| # | Feedback | Status | Rec | Note |
|---|---|---|---|---|
| 29 | **Branded sender email** with our name (Gon) | 📋 Planned | Do — needs your input | Brief written; blocked only on two facts you supply (domain/DNS access) + SPF/DKIM/DMARC. Distinct from the OTP-destination masking that already shipped |
| 30 | **Try the DNS** (Gon) | 📋 Planned | Do — needs your input | A free-Cloudflare CDN runbook is written (staging-first, develop-only). Prod DNS work is parked behind the media privacy/DPA gate. Pairs with #29 |
| 31 | **AWS: full server + app-architecture inventory** to replicate (Gon) | 🔴 Not in docs | Do — I can draft | You already have a "prod hosting reality" memo and a migration PDF. I can turn those into a clean architecture + server-inventory doc for the AWS move whenever you want |
| 32 | **Shareable invite / viral demo link** (Gon, Jon) | 📋 Planned, blocked | Defer | Blocked on a legal go/no-go (recording a non-user's camera) + an iOS-Safari-via-WhatsApp feasibility spike. Don't build until legal clears it |

---

## Suggested order of operations

1. **Ship what's done** — merge the message-menu batch (#10/#11) and cut the next staging build; verify §1 items on device.
2. **Quick-wins sprint** (§3) — items 12–19, roughly a week, big perceived-quality bump.
3. **Onboarding** (#20) — the single highest-impact item; start the coach-mark + demo-bot.
4. **Decide the flagship** for 1.4 among #22 (Apple/Google login), #23 (text-as-reacti), #24 (group react-to-unlock). My vote: **#24 + #23** as the "wow" pair, with **#22** in parallel for conversion.
5. **Infra** (#29–#31) whenever you can hand me the domain/DNS facts.
6. **Skip / gate:** #26 (reaction length), #27 (save photos), and set expectations on #28 (screenshots).

_Open questions for you: (a) does the backend actually store phone contacts? (needed for #16 copy), (b) go/no-go on the group "react-to-unlock" behavior change, (c) which flagship feature anchors 1.4._
