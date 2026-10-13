# LifeHub

LifeHub is a local-first Flutter personal organizer for finance, habits,
tasks, notes, savings goals, reminders, and secure password storage.

## Project layout

The Flutter application lives in `best_flutter_ui_templates/`.

- `lib/app` — application shell, navigation, theme, and auth gate
- `lib/core` — persistence, security, notifications, backup, and shared utils
- `lib/features` — isolated feature modules with repositories and Riverpod state
- `test` — unit and widget regression tests

## Run and verify

From `best_flutter_ui_templates/`:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
flutter build appbundle --release
```

LifeHub is local-first. Firebase, when configured, provides sign-in only; personal
organizer data is not cloud-synced. Vault password values are encrypted on-device,
but other Hive records are not separately encrypted by LifeHub. New backups are
passphrase-encrypted and exclude PIN hashes, salts, and biometric-device state.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) before publishing or
redistributing the project.
