# Coding conventions

The single source of truth for *how the code looks* in this repo. The
choices below are the **dominant existing** patterns — adopted, not
invented — and they apply uniformly going forward. The big refactor
(`docs/refactor/big-refactor-plan.md`) converges existing code to
match.

When the rules and a real example disagree, the rules win and the
example is the next refactor target.

---

## Backend (Laravel / PHP 8.3+)

### Naming

- **Methods / functions / variables / properties** — `camelCase`.
  - Outliers being fixed: web-admin controllers
    `UpdateProfile` / `UpdatePassword` / `UpdateProfilePicture` (R4).
- **Classes / interfaces / traits / enums** — `UpperCamelCase`.
- **Constants** — `SCREAMING_SNAKE_CASE`.
- **PSR-4 file = class.** One class per file, file name matches class.
- **Spelling** is English-correct. The misspelled
  `UserController::userDetais` is renamed in R3a (DG-A gated).

### Directory layout (under `backend/app/`)

```
Console/
DTOs/                   (R9 — introduce when needed)
Enums/
Events/
Exceptions/
Helpers/                ← plural, matches Services/Models/etc. (R5a)
Http/
  Controllers/
  Middleware/
  Requests/             ← Form Requests live here (R7)
  Resources/            ← API Resources (R8d)
Jobs/
Mail/
Models/
Notifications/
Policies/
Providers/
Services/
Traits/
```

Plural directory names throughout. `App\Helper` (singular) was the
sole outlier and is renamed in R5a.

### Routes

- **URL paths** — kebab-case (`/forgot-password`, `/mark-viewed/{id}`,
  `/add-members`).
- **Route placeholders** — `{camelCase}` in the URL pattern, matching
  the controller's parameter name (`{groupId}`, `{userId}`,
  `{messageId}`). Avoid `{group_id}` / `{user}` / `{id}` mixing.
- **Verb / action mapping** —
  - `GET` for safe reads
  - `POST` for creates and non-idempotent actions
  - `PUT` / `PATCH` for updates
  - `DELETE` for deletes
  - `404` for missing resources (never a 200 envelope)
- **Route names** — `dot.case`, e.g. `chat.send`, `group.member.add`.

### Validation

- **Form Requests** under `App\Http\Requests\<Domain>\<Action>Request`
  for everything that's more than one trivial rule (R7).
- Inline `Validator::make` is only acceptable for one-line, throwaway
  validation.

### Response envelope (R7-gated)

Every endpoint returns the same shape:

```json
{
  "success": true,
  "message": "Optional human-readable message.",
  "data": { ... },
  "code": 200
}
```

Failures use the same key (`success: false`) — never the asymmetric
`status: false`. HTTP status code matches `code`.

### HTTP status codes

| Code | When |
|---|---|
| 200 | Success |
| 201 | Created |
| 204 | No content (deletes, etc.) |
| 400 | Malformed / business-rule rejection |
| 401 | Not authenticated |
| 403 | Authenticated but not authorised |
| 404 | Resource not found |
| 409 | Conflict (e.g. duplicate) |
| 422 | Validation error |
| 429 | Rate-limited |
| 500 | Unexpected server error |

No more 200-with-`success:false` for soft failures.

### Errors and exceptions

- Internal exceptions never leak to the client. `\$e->getMessage()`
  goes to `Log::error(...)`; the response message is a fixed string.
- `App\Exceptions\ApiException` is the typed domain error — its
  message *is* the user-facing message.

### PHPDoc

Every public class / method gets a docblock. Minimum:

```php
/**
 * One-line summary of what the method does.
 *
 * Longer explanation when "what" is non-obvious — why, edge cases,
 * invariants. Skip when the name is self-explanatory.
 *
 * @param  Foo  \$foo  What it is.
 * @return Bar         What is returned.
 *
 * @throws ApiException When the domain rule fires.
 */
```

PHP types are the source of truth for `@param` / `@return`; PHPDoc
adds the *narrative*. Skip `@return void`.

Don't ship emoji notes, "preserved verbatim", "must not be fixed" —
those are refactor-era residue.

### Formatting

`vendor/bin/pint` (PSR-12 defaults) — gated in CI by R1a.

### Static analysis

PHPStan / Larastan at level 5, with the existing baseline. New
violations fail CI; baseline is paid down opportunistically.

---

## App (Flutter / Dart 3.11+)

### Naming

- **Files** — `lower_snake_case.dart`.
- **Classes / extensions / typedefs / enums** — `UpperCamelCase`.
- **Functions / methods / variables / fields** — `lowerCamelCase`.
- **Constants / enum values** — `lowerCamelCase` (Dart idiom, not
  SCREAMING). Existing `kKey…` constants stay (well-established).
- **Private** — `_leadingUnderscore`.

### Spelling

English-correct. Outliers being fixed in R3b:
`ChnagePasswordApi` → `ChangePasswordApi`; `RECIEVE_TIMEOUT` →
`RECEIVE_TIMEOUT`; `Failure.resonseCode` → `responseCode`;
`avater` widget param → `avatar`;
`waitingForSucess` → `waitingForSuccess`.

### Package name (R6)

```yaml
# pubspec.yaml
name: reacti_app
```

Matches the Android `applicationId` `com.reacti.app`.

### Directory layout (under `app/lib/`)

```
common_widget/          ← shared widgets used across features
constants/
features/
  <feature>/
    data/               ← rx_* data sources + API wrappers
    logic/              ← pure business logic (testable without widgets)
    model/              ← typed response models
    presentation/
      <screen>.dart
      widget/           ← sub-widgets specific to this feature
gen/                    ← generated assets / colors
helpers/                ← cross-cutting helpers
networks/               ← Dio client, endpoints, interceptors
```

Tests mirror `lib/` under `app/test/`.

### Imports (Dart standard ordering)

1. `dart:` imports.
2. `package:` imports (external packages, then this package).
3. Relative imports (`../`, `./`).

Each group separated by a blank line, alphabetically within group.

### Widgets

- **`StatefulWidget` config fields are `final`.** State holds mutable
  state, not the widget. The current
  `ReceiverMessageWidget(isBlurred: bool)` mutable field is the
  outlier (R8-adjacent fix).
- Sub-widget extraction over fat `build()`. The threshold is when a
  reader can't see the whole tree without scrolling.
- Constructor params: `super.key` first, then `required` named
  params, then optional named params.

### State management

- **GetX** for navigation (`GetMaterialApp`, `Get.to(...)`) and toasts
  (`Get.snackbar`) — already the project's choice; do not introduce
  a second navigation lib.
- **`rx_*` BehaviorSubject** pattern for data sources (already
  established).
- **`get_it`** for DI of the data-source singletons.
- New `provider` registrations or new state-management packages are
  out of scope until the consolidation discussed in
  `enhancement-plan.md` §EP8 happens.

### Errors

`Failure` is the typed error from the network layer. UI screens must
have an explicit `hasError` branch on every `StreamBuilder` — the
silent `else → SizedBox.shrink()` pattern is being removed
(`enhancement-plan.md` §EP3 stragglers).

### Logging

`log()` from `dart:developer`, gated on `kDebugMode` for anything that
could leak request bodies / headers / tokens. `print()` is for
throwaway debugging — never commit it.

The Dio request/response logger redacts `Authorization`, `password`,
`otp`, `token`, `access_token`, `refresh_token` (see
`networks/dio/log.dart`).

### DartDoc

`///` on every public symbol. Reference others with `[Brackets]`.

### Formatting

`dart format` — gated in CI by R1b.

---

## Repo / project

- **Commit messages** — Conventional Commits.
  `<type>(<scope>): <summary>` (`feat(chat): ...`, `fix(security): ...`,
  `refactor(app): ...`, `ci: ...`, `docs: ...`, `chore: ...`).
  Body explains *why*. Footer for `Co-Authored-By` and refs.
- **Branches** — `<type>/<scope>-<topic>` off `develop`
  (`refactor/r1a-pint-format`, `fix/typing-event`,
  `enhance/ep1-throttle-auth`). One concern per PR.
- **PRs** — squash-merge into `develop`; `develop` → `main` for
  release.
- **Required checks** — `PHP Tests` and `Analyze & Test` are required;
  both always report on every PR (no path-filter skip).
- **Releases** — tagged on `main` (`v1.2.3`); `CHANGELOG.md` updated
  per release.
- **Docs** at repo root: `README.md`, `LICENSE`, `CONTRIBUTING.md`,
  `CHANGELOG.md`, `CLAUDE.md`. Subproject `README.md` per `app/` and
  `backend/`.

---

## How conventions enter or change

1. Open a PR proposing the change to `docs/conventions.md`.
2. Get explicit sign-off from the team.
3. Land the conventions PR, *then* land a follow-up PR that converges
   the existing code.

A convention that is documented but not enforced (no lint, no CI
gate) is a wish, not a rule.
