<!-- Conventional Commit prefix in the title (feat/fix/chore/docs/refactor/test). -->

## What and why

<!-- Short paragraph: what does this PR change, and why? Link an issue if any. -->

## Affects the patent flow?

- [ ] No
- [ ] Yes — and a regression test for the auto-record-reaction-on-message-open
      flow is added or updated. (See `app/lib/features/chat/presentation/widget/receiver_message_widget.dart`.)

## Screens / before-after

<!-- Screenshots, screen recordings, or curl examples. -->

## Migration / config impact

- [ ] No DB migration
- [ ] DB migration included; safe to deploy in any order
- [ ] DB migration that REQUIRES a deploy ordering — described below

## Checklist

- [ ] `dart format .` and `flutter analyze` pass (if app changed)
- [ ] `./vendor/bin/pint --test` passes (if backend changed)
- [ ] Tests added or updated and `flutter test` / `php artisan test` green locally
- [ ] No secrets, no `.env` values, no signing keys in the diff
- [ ] No `dd()`, `print()`, or `log()` left in non-debug paths
