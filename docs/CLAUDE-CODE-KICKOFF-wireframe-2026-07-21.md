# Claude Code kickoff — Wireframe "8 Beta Deliveries"

Read `docs/PLAN-wireframe-deliveries-IMPLEMENTATION-2026-07-21.md` in full before writing any
code — it's the build spec (per-feature scope, file refs, tests, patent guardrails, verbatim
copy in Appendix A, onboarding-image shot list in Appendix B). `docs/PLAN-wireframe-deliveries-2026-07-21.md`
is the overview if you want context.

## How to work
- **One feature = one branch off `develop` = one PR.** Do NOT stack. Ship each to staging
  (TestFlight from `develop`) before starting the next.
- **Re-verify every file/line reference against `develop`** before editing (`git show
  develop:<path>` or open it) — the plan's line numbers may have drifted; grep for the quoted
  literal where no line is given.
- Follow the plan's **Global conventions** section (Conventional Commits, `dart format` +
  `flutter analyze` clean, `pint` for PHP, theme tokens, GetStorage keys, CI green, screenshot
  per app PR).
- Use **Appendix A verbatim copy** for all on-screen strings.
- **Patent guardrail:** any change near `send` / `mark-viewed` / blur flags /
  `recordVideoSilently` / reaction upload must re-run the patent regression suite and keep the
  success path identical (CLAUDE.md north-star). Applies to Features 2, 6, 8c, and the
  read-only Feature 3.

## Decisions are locked — do not re-litigate
- D1 = **build** group react-to-unlock (#6).
- D2 = **keep** the 4-tab nav; #8a People-tab is **on hold** — don't build it.
- D3 = **scripted** demo now; AI coach is future-only, don't build it.
- D4 = **plain invite link v1**, but build the opaque invite-code backend + a
  provider-agnostic `InviteService` seam so a paid deep-link drops in later with zero rework.
- D5 = **keep the carousel**, just swap its unrelated images for related ones.

## Build order
**Wave 0 (start here):**
1. `feat/chat-list-preview-labels` — replace "File attachment" with "New photo Reacti" /
   "New video Reacti · 0:24" / "Reaction received" (Feature 3). Start with this one.
2. `feat/profile-how-reacti-works` — Profile "How Reacti works" row reopening the current
   carousel (Feature 7). Works against today's carousel; inherits the image upgrade later.

**Then:** Wave 1 `feat/demo-reacti` (#2) → Wave 2 `feat/personal-invite` + `feat/invite-connect`
(#5) then `feat/analytics-activation-funnel` (#4) → Wave 3 `feat/group-react-to-unlock` (#6) →
Wave 4 `feat/composer-send-reacti-cta` (#8b) + `feat/jit-permissions` (#8c).

**⏸ LAST — `feat/onboarding-copy-refresh` (Feature 1):** DEFERRED to the end. It waits on
Achia's 3 related carousel images (Appendix B). Do **not** build a placeholder version now —
leave the carousel as-is and do copy + images together in one PR once the images land.

## First step
Read the plan, then open a short comment on the **Feature 3** section confirming the exact
subtitle widget/file you'll change (grep `"File attachment"`) and the `CombinedChatResource`
fields available, before you start the PR. Flag anything that contradicts the plan.
