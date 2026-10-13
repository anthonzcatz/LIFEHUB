# LifeHub

LifeHub is a local-first personal organizer built with Flutter. It combines
finance tracking, budgets, savings goals, tasks, notes, habits, reminders, and
a protected password vault in one focused mobile experience.

## Architecture

- `lib/app` contains the app shell, navigation, theme, and auth gate.
- `lib/core` contains shared constants, persistence, security, notifications,
  and backup services.
- `lib/features` keeps each product area isolated with screens, models,
  repositories, and Riverpod providers.
- Hive is the local persistence layer; Firebase is optional for cloud auth.

Vault password values are encrypted on-device; other Hive records are not
separately encrypted by LifeHub. Firebase, when configured, provides sign-in only
and does not sync organizer data. New backup exports are passphrase-encrypted and
omit PIN hashes, salts, and biometric-device state.

## Development

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
flutter build appbundle --release
```

The Android release build currently uses the local `android/key.properties`
keystore when present. Configure a real release keystore before publishing to
an app store; do not distribute a debug-signed release artifact.

See [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) for the current
font, dependency, and asset attribution review.
