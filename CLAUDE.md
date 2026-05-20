# Reacti — guidance for Claude Code

This file is the first thing you should read when working in this repo.
Anything in `app/CLAUDE.md` or `backend/CLAUDE.md` overrides what is here for
that subtree.

## What this repo is

A monorepo holding the Reacti messaging app. `app/` is the Flutter client,
`backend/` is the Laravel 11 API. They are versioned together.

## North-star feature (do not break)

The patent-protected flow is *automatic, silent front-camera recording when a
recipient opens a media message*. The implementation lives in
`app/lib/features/chat/presentation/widget/receiver_message_widget.dart`,
specifically `recordVideoSilently()` invoked from `_buildBlurPlaceholder()`
after the `mark-viewed` API call succeeds. The reaction is uploaded as a
`type: "reaction"` message via `sendMessageRx` / `sendGroupMessageRx`.

The corresponding backend endpoints are `POST /auth/chat/mark-viewed/{id}`
and the message-send endpoints, with broadcasting via Pusher channels.

When you change anything that touches:

* the blur/unblur transition,
* the recording trigger,
* the upload path of reaction messages,
* the `mark-viewed` API,
* or the broadcasted events for these,

write or update a regression test that exercises the full loop end-to-end.

## How to run things

Backend:

```sh
cd backend
composer install && php artisan migrate && php artisan serve
```

App:

```sh
cd app
flutter pub get
flutter run --dart-define=BASE_URL=http://localhost:8000/api --dart-define=APP_KEY_VALUE=<dev-key>
```

## Conventions

The full conventions document is **`docs/conventions.md`** — read it
before touching code. Highlights:

* Conventional Commits: `feat(scope): ...`, `fix(scope): ...`, `chore: ...`.
* PHP: `camelCase` methods; format with `./vendor/bin/pint`; no inline
  `dd()` left behind; one envelope `{success, message, data, code}` on
  every endpoint; real HTTP status codes (no 200-with-`success:false`).
* Dart: `lower_snake_case.dart` files, `UpperCamelCase` classes,
  `lowerCamelCase` methods/vars; `dart format .` and `flutter analyze`
  must pass; `StatefulWidget` config fields are `final`.
* Never commit a file under `.local-secrets/`, `.env` (without `.example`), or
  any `*.json` that contains a service-account key.
* Never weaken TLS (`HttpOverrides`, `verify=False`, `--insecure`) without an
  explicit, time-boxed reason recorded in the PR description.

The big refactor (`docs/refactor/big-refactor-plan.md`) converges the
existing code to these conventions in phases R0-R10.

## Things to be careful with

* `app/lib/networks/endpoints.dart` is the single source of truth for the API
  base URL. The fallback constant is `https://reacti.io/api` (production). To
  switch envs use `--dart-define=BASE_URL=...` rather than editing the file.
* `app/lib/main.dart` currently overrides the certificate validator
  (`MyHttpOverrides`) which weakens TLS in production. This is on the cleanup
  list; do not extend it.
* `backend/.env` is *not* in the repo. Use `backend/.env.example` to learn
  which keys are expected. Real values come from Hostinger or your local dev.
* `backend/composer.json` was reconstructed from `composer.lock` because the
  delivery archive omitted it. If the dev team sends the original, replace
  it and run `composer install` to confirm parity.

## Helpful entry points when looking around

* `app/lib/main.dart` — bootstraps Firebase, GetStorage, DI, theme.
* `app/lib/networks/dio/dio.dart` — HTTP clients (auth, public, multipart).
* `app/lib/features/chat/` — chat list, inbox, group inbox, reactions.
* `backend/routes/api.php` — public + authenticated REST endpoints.
* `backend/app/Events/` — Pusher broadcasting events.
* `backend/app/Http/Controllers/Api/Chat/` — chat + reaction handlers.
