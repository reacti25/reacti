# Backend refactor plan

Behavior-preserving refactor of the Laravel backend (`backend/`).
Authorized 2026-05-17. This file is the single source of truth — read
the **§ Checkpoint log** before resuming.

## Goal

The backend is a fat-controller app: business logic, validation, DB
access, file handling, and broadcasting all live inside controller
methods. `SingleChatController` is 1139 lines / 35 methods,
`ChatController` 724 / 29, and there are only two service classes.

Refactor to a **thin-controller + service-layer** architecture:

* Controllers validate input (via Form Requests) and delegate to a
  service, then return a response (via the `ApiResponse` trait).
* Business logic moves into `app/Services/*` — one service per feature
  area, a method per operation.
* `app/Http/Requests/*` gains a Form Request for every endpoint with
  non-trivial validation.

No new architectural patterns: `app/Services/` already exists
(`ChatFileService`, `CmsService`); this expands it. No Actions, no
Repository layer.

## The one hard rule

**No functionality change.** Every step is behavior-preserving:
identical responses, status codes, DB writes, broadcasts, side
effects. Pre-existing bugs (inventory.md §8, the `dd("jalis")` in
`Helper`, the `bio`→`dob` mapping, etc.) are **preserved, not fixed** —
a faithful refactor keeps them.

## Safety method

Local `php` is not on PATH; the only way to run tests is GitHub
Actions (`PHP Tests`, ~35 s). Per checkpoint:

1. **Protect** — confirm every endpoint in scope has a Feature test
   asserting its observable behavior (status, JSON, DB, events). If
   there are gaps, open a *test-only* PR that adds them; merge it
   green first (proves the tests pass against the **current** code).
2. **Refactor** — extract services + Form Requests, slim the
   controllers. Open the refactor PR.
3. **Verify** — CI green on the refactor PR proves behavior preserved.
   Merge (`gh pr merge --admin`; backend-only PRs leave
   `Analyze & Test` unreported).
4. Record the result in the checkpoint log below, then continue.

Branch naming: `refactor/backend-cpN-<area>` and
`test/backend-cpN-<area>` for the protective test PRs.

## Checkpoints

Ordered small / well-tested first, the monster last.

| CP | Area | Controllers | Target services |
|----|------|-------------|-----------------|
| 1 | Auth | AuthenticationController, ResetPasswordController, SocialLoginController, UserProfileController | AuthService, PasswordResetService, SocialAuthService, ProfileService |
| 2 | Friends | FindFriendController, FriendRequestController, FriendsController, ReportUserController | FriendService, FriendRequestService, ModerationService |
| 3 | User / misc | UserController, UserBlockController, FirebaseTokenController, NotificationController, PrivacyController | UserService, BlockService, FirebaseTokenService, NotificationService |
| 4 | Chat | ChatController (724 L) | ChatService (file handling already in ChatFileService) |
| 5 | Groups | GroupCreateController, GroupManageMemberController, GroupMessageController | GroupService, GroupMemberService, GroupMessageService |
| 6 | Chat V2 | SingleChatController (1139 L / 35 m) | ChatV2Service (+ split as needed) |

## Checkpoint log

_(append results here as each checkpoint lands)_

* **CP1 — Auth — DONE.** Protective tests PR #14 (LogoutTest, login
  edge cases, deleteProfile). Refactor PR #15: added
  `App\Exceptions\ApiException` and four services (`AuthService`,
  `PasswordResetService`, `SocialAuthService`, `ProfileService`); the
  four Auth controllers are now thin. Validation left in place
  (inline + existing Form Requests) to keep 422 bodies identical.
  Established the pattern for CP2-6: service throws `ApiException`
  (message + status) for business-rule failures; controller catches
  `ApiException` → `error(status)` and generic `Exception` →
  method-specific 500. CI green.
* **CP2 — Friends — DONE.** No protective-test PR needed: all 12
  endpoints were already covered by merged tests (FindContacts,
  FriendRequest, FriendRequestEndpoints, Friends, ReportUser).
  Refactor PR #16: added `FriendService`, `FriendRequestService`,
  `ModerationService`; the four Friend controllers are thin. DB
  transactions moved into services and re-thrown. Methods that had no
  500 catch keep that shape. CI green.
* **CP3 — User/misc — DONE.** Protective test PR #17 (firebase/test).
  Refactor PR #18: added `UserService`, `BlockService`,
  `FirebaseTokenService`, `NotificationService`, `PrivacyService`.
  Quirks preserved: userDetais 200-on-not-found; FirebaseTokens
  always-true `if` + dead 404 branch; bespoke response()->json
  envelopes. NotificationController is unrouted dead code (moved
  verbatim). CI green.
* **CP4 — ChatController — DONE.** Route check: `auth/chat/*` (v1) →
  `ChatController` (this CP); `v2/auth/chat/*` → `SingleChatController`
  (CP6). Both live. Covered by ChatControllerTest + patent tests — no
  test PR needed. Refactor PR #19: added `ChatService` (10 methods);
  patent-flow paths (send, markAsViewed) moved verbatim. CI green.
* **CP5 — Groups — DONE.** Protective test PR #20 (updateGroup,
  updateAvatar, messageMedia — the 3 uncovered endpoints). Refactor
  PR #21: added `GroupService`, `GroupMemberService`,
  `GroupMessageService`; the 3 group controllers are thin. Caught and
  fixed a refactor regression pre-merge — `groupDetails` had
  collapsed the non-member 403 into a 404; restored via
  `ApiException`. Patent-flow group paths (sendMessage, markAsViewed)
  moved verbatim. CI green.
* **CP6 — SingleChatController (V2) — DONE.** Protective test PR #22
  added `SingleChatControllerTest` — 63 feature tests covering the
  previously-untested `v2/auth/chat/*` surface (3 were re-pinned to
  real behaviour after the first CI run, incl. the `typingStatus`
  500-on-every-call bug from a wrong `UserTypingEvent` reference).
  Refactor PR #23: added `SingleChatService` (controller 1139 → 500
  lines); patent-flow paths moved verbatim; the `typingStatus` bug,
  `forwardMessage` dead 404 branch, and dead thumbnail helpers
  preserved. CI green.

## Outcome — API controllers (CP1-6)

API refactor **complete** (2026-05-17). All six checkpoints landed
across PRs #14-#23 — every API controller (Auth, Friends, User/misc,
Chat, Groups, Chat V2) is now thin; business logic lives in
`app/Services/*`, with `App\Exceptions\ApiException` carrying
business-rule status codes. No functionality changed: each checkpoint
was test-protected first and verified by a green `PHP Tests` suite.
Pre-existing bugs were deliberately preserved, not fixed — they remain
a separate decision (catalogued in `docs/code-quality-backlog.md`).

## Phase 2 — Web/admin controllers

Continuing the same thin-controller + service-layer refactor into the
admin panel.

* **CP7 — Web/Backend admin controllers — DONE.** Refactor PR #26:
  the 8 routed admin controllers (`DashboardController`,
  `ChatManageController`, `AdminGroupChatController`, and
  `Settings/{DynamicPage, Firebase, Profile, Setting, Social}
  Controller`) are now thin, backed by 8 new services
  (`AdminDashboardService`, `AdminChatService`, `AdminGroupChatService`,
  `DynamicPageService`, `FirebaseSettingService`, `SocialSettingService`,
  `GeneralSettingService`, `AdminProfileService`). Web controllers
  keep view/redirect/flash construction; services return data.
  Quirks preserved. Covered by the Tier-5 admin suites. CI green.

## Where the controller refactor ends

With CP7 every **routed application controller** — API and admin — is
thin. What remains in `Http/Controllers/` is deliberately left as-is:

* `Web/Auth/*` (9 controllers) + the root `ProfileController` are
  stock Laravel Breeze scaffolding — already idiomatic and thin; a
  service layer there would be over-engineering.
* The 5 unrouted dead `Web/Backend` controllers — to be deleted, not
  refactored (a functionality change; see the backlog).

Further structural work (decomposing the large services, the `Helper`
class, model scopes) is catalogued in `docs/code-quality-backlog.md`
and is a separate effort from the controller→service refactor.
