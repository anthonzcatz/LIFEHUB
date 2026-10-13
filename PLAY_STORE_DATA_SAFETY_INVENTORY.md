# LifeHub Play Store Data Safety Inventory

**Internal review draft — not a published privacy policy or a completed Play Console declaration.** Verify the Firebase project configuration, platform-manifest merge, release SDK settings, retention requirements, and a public privacy-policy contact/URL before submission.

## Current data flows observed in source

| Data | Purpose | Storage/processing | User control |
|---|---|---|---|
| Transactions, budgets, savings goals | Personal finance tracking | Local Hive storage on the device; no cloud synchronization is implemented | Export encrypted backup, restore backup, or Clear all data |
| Tasks, reminders, notes, habits, habit logs | Personal organization | Local Hive storage; reminder delivery is scheduled locally by the OS | Edit/delete records, disable reminders, or Clear all data |
| Vault titles, usernames, websites, notes | Password-vault organization | Local Hive storage | Delete entries or Clear all data |
| Vault password values | Password-vault secrets | AES-GCM encrypted with a key held in platform secure storage | Delete entries or Clear all data; portable encrypted backup can carry the key under the backup passphrase |
| Local PIN | App unlock | Argon2id hash and salt stored in local Hive settings; raw PIN is not stored | Change through Settings → Change PIN; reset by Clear all data; not included in backups |
| Biometric authentication | Optional local unlock | Authentication is performed by the operating system; LifeHub stores only the enabled preference | Disable in settings or change device biometrics |
| Name, email, bio, profile-photo path/URL | Local profile display | Local Hive settings; a picked image is copied to app-private documents storage | Edit/remove profile data or Clear all data |
| Profile image | Profile display | Picked from the camera/gallery and stored locally; included as an attachment in a new encrypted backup when available | Remove photo or Clear all data |
| Firebase/Google account identifiers | Sign-in only, when Firebase is configured | Firebase Authentication and Google sign-in process the account; LifeHub stores basic display name/email/photo URL locally. Organizer records are not uploaded or synced | Sign out; Delete account also deletes local LifeHub data |
| Reminder schedule/time | Task and habit reminders | Local notification scheduler and OS alarm/notification facilities; task notification body is generic | Change/delete reminder or disable notifications in OS/app settings |
| Backup contents | User-initiated device transfer/recovery | New export is encrypted locally with Argon2id and AES-256-GCM, then shared to a destination selected by the user. The passphrase is not stored by LifeHub | User retains the passphrase; Clear all data deletes LifeHub's temporary export file, not copies already shared elsewhere |

## Important security boundaries

- Firebase is authentication-only at present. `SyncService` is a no-op; do not describe the app as cloud-backed or synced.
- Vault password values are encrypted at application level. Other Hive records (including finance, tasks, notes, profile fields, and PIN metadata) do not currently have separate application-layer database encryption; do not claim that all LifeHub data is encrypted at rest.
- A backup passphrase is required to decrypt a new backup. Losing it makes that backup, including its portable vault key, unrecoverable by LifeHub.
- Legacy version-1 JSON backups may be imported with a warning but are not encrypted and do not contain a portable vault key.
- Account deletion removes the Firebase Authentication account and the current device's LifeHub data. It cannot revoke copies of backups the user has already shared outside the app.

## Permission declarations to verify against the final merged manifests

- Android source requests Internet, biometric, notifications, boot-completed, and exact-alarm permissions.
- iOS source declares Face ID, camera, and photo-library usage descriptions.
- Notification permission and exact-alarm delivery are subject to user choice and OS policy; reminders do not bypass Do Not Disturb or guarantee alarm-clock behavior.

## Owner confirmations required before release

- Publish a public privacy policy with a valid contact address and enter its URL in Play Console; review this inventory against the production Firebase project and final merged Android manifest.
- Complete the Play Console Data Safety form based on the actual Firebase/Google provider configuration and any services enabled in the release build.
- Confirm whether account creation will remain enabled and provide the public account-deletion request URL required by Play Console.
- Obtain written clarification from the original template rights holder or legal counsel before adding ads, paid downloads, subscriptions, or in-app purchases; the retained template license has an additional commercial-use-sounding paragraph.
- Review profile-photo, financial, and backup retention language for the intended countries/age groups. No ads, analytics, or crash-reporting SDK is currently declared in the app's direct dependencies.
