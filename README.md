# Reacti

Reacti is a messaging app whose patent-protected feature is automatic, silent
front-camera recording the moment a recipient opens a media message. The
captured reaction is sent back to the sender as a "reaction" message,
producing a closed loop: sender -> media -> auto reaction -> back to sender.

This monorepo holds both halves of the product so that any change spanning
the API and the client can be reviewed and merged atomically.

## Layout

```
reacti/
├── app/         # Flutter mobile client (iOS shipping; Android target supported)
├── backend/     # Laravel 11 REST API + Pusher/Reverb broadcasting
├── docs/
│   ├── vision/        # Original product vision PDFs
│   └── screenshots/   # iOS Simulator screenshots
├── archives/    # Original delivery archives kept as a fallback
└── README.md
```

`archives/` is intentionally checked-in-tree on disk but git-ignored. Keep it
locally; do not commit those zip/rar files.

## Stacks at a glance

| Layer       | Technology                                         |
|-------------|----------------------------------------------------|
| Mobile      | Flutter 3.7+, GetX, Dio, Firebase Messaging, Pusher Channels (`dart_pusher_channels`), camera, image_picker |
| Backend     | Laravel 11, PHP 8.2+, MySQL, JWT (`tymon/jwt-auth`), Pusher + Reverb broadcasting, AWS S3, Firebase Cloud Messaging |
| Realtime    | Pusher (prod) / Reverb (configurable)              |
| Push        | Firebase Cloud Messaging                           |
| Hosting     | Hostinger VPS (Laravel) + App Store (iOS)          |

API base URL: `https://reacti.io/api`
Mobile bundle: `com.reacti.app`
Firebase project: `reacti-app`

## Quick start

### Backend

```sh
cd backend
cp .env.example .env
composer install
php artisan key:generate
php artisan jwt:secret
php artisan migrate
php artisan serve
```

### App

```sh
cd app
flutter pub get
flutter run --dart-define=BASE_URL=http://10.0.2.2:8000/api --dart-define=APP_KEY_VALUE=<dev-app-key>
```

`10.0.2.2` is the Android emulator's alias for the host's `localhost`. iOS
Simulator can use `http://localhost:8000/api` directly.

## Branching

* `main` mirrors production. Protected; merges via PR only.
* `develop` is the integration branch.
* Feature work happens on `feature/<short-name>` cut from `develop`.

## The patent flow (do not regress)

The trigger lives in
`app/lib/features/chat/presentation/widget/receiver_message_widget.dart` in
`recordVideoSilently()`, called from `_buildBlurPlaceholder()` after a
successful `mark-viewed` API call. Any change to the viewing flow, the
blur/unblur transition, or the upload back must keep this loop intact.

## Conventions

* PHP: `composer pint` before pushing.
* Dart: `dart format . && flutter analyze` before pushing.
* Commit style: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
* PRs touching the patent flow must include a regression test.

This project enforces the `clean-code-standards` skill. Apply it to every
code change: docstrings on every function/class/module, comments that explain
*why*, small single-purpose functions, unit tests wired into CI, and OOP
only where it earns its keep. 
k
