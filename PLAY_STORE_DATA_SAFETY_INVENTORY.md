# LifeHub Play Store Data Safety Inventory

**Internal review draft — verify against the final merged manifest before
submitting. The in-app policy lives at Settings → Privacy policy and a
hostable copy is in `PRIVACY_POLICY.md`.**

## Current data flows observed in source

| Data | Purpose | Storage/processing | User control |
|---|---|---|---|
| Transactions, budgets, savings goals | Personal finance tracking | Local Hive storage on the device; no synchronization exists | Export encrypted backup, export PDF report, or Clear all data |
| Tasks, reminders, notes, habits, habit logs | Personal organization | Local Hive storage; reminder delivery is scheduled locally by the OS | Edit/delete records, disable reminders, or Clear all data |
| Vault titles, usernames, websites, notes | Password-vault organization | Local Hive storage | Delete entries or Clear all data |
| Vault password values | Password-vault secrets | AES-256-GCM encrypted with a key held in platform secure storage | Delete entries or Clear all data; portable encrypted backup can carry the key under the backup passphrase |
| Local PIN | App unlock | Argon2id hash and salt stored in local Hive settings; raw PIN is not stored | Change through Settings → Change PIN; reset by Clear all data; not included in backups |
| Biometric authentication | Optional local unlock | Authentication is performed by the operating system; LifeHub stores only the enabled preference | Disable in Settings or change device biometrics |
| Name, email, bio, profile photo | Local profile display | Local Hive settings; a picked image is copied to app-private storage | Edit/remove profile data or Clear all data |
| Reminder schedule/time | Task and habit reminders | Local notification scheduler and OS facilities | Change/delete reminder or disable notifications in OS/app settings |
| Backup contents | User-initiated transfer/recovery | Encrypted locally with Argon2id + AES-256-GCM, then shared to a destination the user selects. The passphrase is not stored | User retains the passphrase and the exported file |
| PDF finance reports | User-initiated sharing | Rendered on-device, written to the app cache, shared through the system share sheet | User picks the destination; cached copies are cleared by the OS |

## Important security boundaries

- **There is no account system and no network code.** The app does not
  request the Internet permission and cannot transmit data.
- Vault password values are encrypted at application level. Other Hive
  records (finance, tasks, notes, profile fields, PIN metadata) do not
  have separate application-layer database encryption — do not claim all
  data is encrypted at rest.
- A backup passphrase is required to decrypt a backup. Losing it makes
  that backup, including its portable vault key, unrecoverable.
- Legacy version-1 JSON backups may be imported with a warning but are
  not encrypted and do not contain a portable vault key.

## Permission declarations (final merged manifest)

- `USE_BIOMETRIC` — optional fingerprint unlock (managed by Android; the
  app never sees fingerprint data)
- `POST_NOTIFICATIONS` — user-requested reminders (runtime permission)
- `RECEIVE_BOOT_COMPLETED` — re-register reminders after restart
- `VIBRATE` — added automatically by the notification plugin
- `USE_FINGERPRINT` — legacy API marker added by the local_auth plugin;
  deprecated and auto-granted, no policy impact

The app does **not** request: INTERNET, camera, storage, contacts,
location, microphone, SMS, or any sensitive-permission form that would
trigger additional Play declarations.

## Data Safety form answers (accurate for this build)

- **Does your app collect or share user data?** → **No**
- Everything else follows from that single answer. If asked to confirm:
  no data collected, no data shared, no third parties, data is encrypted
  in transit AND at rest where applicable (vault/backups use AES-256-GCM).

## Owner confirmations required before release

- Publish `PRIVACY_POLICY.md` at a public URL (GitHub Pages, a repo's
  rendered markdown link, or Google Sites all qualify) and enter that
  URL in Play Console → App content → Privacy policy.
- Fill the Data Safety form as above ("No data collected").
- Complete the content rating questionnaire (suggest: Productivity /
  Everyone — no objectionable content).
- Store listing assets: ≥2 screenshots, 512×512 hi-res icon, 1024×500
  feature graphic, short + full description.
- Enable Play App Signing (Google manages the app signing key; your
  existing `lifehub-release.jks` becomes the upload key — keep it safe).
- Obtain written clarification from the original template rights holder
  or legal counsel before adding ads, paid downloads, subscriptions, or
  in-app purchases; the retained template license has an additional
  commercial-use-sounding paragraph.
