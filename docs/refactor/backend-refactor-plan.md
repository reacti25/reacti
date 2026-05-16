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

* CP1 — in progress.
