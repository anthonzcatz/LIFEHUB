# LifeHub Privacy Policy

**Last updated: October 2026**

LifeHub ("the app") is an all-in-one personal organizer for Android. This
policy explains, in plain terms, how the app handles your information.

## The short version

**LifeHub collects no data.** Everything you enter stays on your device.
There are no accounts, no servers, no analytics, no ads, and no tracking.
The app works fully offline and does not connect to the internet.

## What the app stores, and where

All of the following is stored only in the app's private storage on your
device:

- **Finance data** — transactions, budgets, savings goals
- **Tasks, notes, and habits** — including their reminder schedules
- **Vault entries** — passwords and notes encrypted with AES-256-GCM;
  the encryption key is held in Android's secure keystore, not on disk
  in plain text
- **Security settings** — your unlock PIN, stored only as an Argon2id
  hash, and your biometric-unlock preference
- **Backups** — optional, encrypted with AES-256-GCM using a passphrase
  you choose; the file is created only when you tap "Export backup" and
  goes only where you send it

## Permissions, and what they're for

| Permission | Purpose |
|---|---|
| `USE_BIOMETRIC` | Optional fingerprint unlock. Fingerprint data is managed entirely by Android; the app never sees or stores it. |
| `POST_NOTIFICATIONS` | Deliver the reminders you schedule for tasks and habits. |
| `RECEIVE_BOOT_COMPLETED` | Re-register your reminders after the device restarts. |

The app does **not** use the internet permission — it cannot send your
data anywhere, by design.

Photos and files are accessed only when you explicitly pick them
(profile photo, backup restore, PDF report sharing) through Android's
own picker or share sheet. Camera access is used only when you choose
"Take photo" for your profile picture.

## Data sharing

None. There is nothing to share — no data ever leaves your device
except files **you** export yourself (backups, PDF reports) through the
share targets **you** choose.

## Your control over your data

- **Export** — Settings → Backup → export creates an encrypted backup
  file you keep
- **Delete** — Settings → Clear all data erases everything on-device;
  uninstalling the app also removes all data
- **Backups you exported** are under your control — keep or delete the
  files as you like

## Security

- Vault and backup data are encrypted with AES-256-GCM
- Backup keys are derived from your passphrase with Argon2id
- PINs are hashed with Argon2id and never stored in plain text
- Vault keys live in Android's hardware-backed secure storage

## Children's privacy

The app is not directed at children and collects no personal
information from anyone, of any age.

## Changes to this policy

If this policy changes, the updated version will be posted at the same
location and the "Last updated" date will change.

## Contact

If you have questions about this policy, you can reach the developer
through the contact email listed on the app's Play Store page.
