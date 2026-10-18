# LifeHub — Play Store Submission Guide

Complete checklist for the first upload. Code-side items are already
done; the steps below are the remaining Play Console work, in order.

---

## Phase 0 — Before you start

- [ ] **Google account** you want permanently tied to the app (cannot be
      changed later)
- [ ] **$25 one-time** developer registration fee + a payment card
- [ ] **Government-issued ID** — Google requires identity verification
      for new developer accounts (can take a few days)

## Phase 1 — Developer account

1. Go to <https://play.google.com/console> and register.
2. Choose **Personal** account (unless registering as a company).
3. Complete identity verification immediately — do not wait; it can
   block everything else.

> **Important for new personal accounts (created after Nov 2023):**
> Play requires a **closed test with at least 12 testers opted in for
> the last 14 days** before you may apply for production access. Plan
> for roughly two weeks of testing before the public launch. Recruit
> friends/family early — see Phase 4.

## Phase 2 — Privacy policy hosting (required field)

The policy file is ready — you only need a public URL. Pick ONE:

**Option A — GitHub Pages (recommended)**
1. Push this repo to a **public** GitHub repository.
2. Repo → **Settings → Pages** → Source: `main` branch, folder: `/docs`.
3. URL becomes `https://<username>.github.io/LIFEHUB/privacy-policy.html`.

**Option B — Netlify Drop (fastest, no repo needed)**
1. Go to <https://app.netlify.com/drop>.
2. Drag the `docs/` folder from this repo.
3. URL becomes `https://<name>.netlify.app/privacy-policy.html`.

Keep the URL alive permanently — removing it later is a policy issue.

## Phase 3 — Create the app in Play Console

| Field | Answer |
|---|---|
| App name | LifeHub (search Play first for name conflicts) |
| Default language | English (US) |
| App or game | App |
| Free or paid | Free |

### App content declarations

| Form | Answer |
|---|---|
| **Privacy policy** | Paste the hosted URL from Phase 2 |
| **Ads** | No — the app contains no ads |
| **Data safety** | **No data collected, no data shared** — answer No to collection. The app has no internet permission and collects nothing. |
| **Target audience** | 18+ (the app is not directed at children) |
| **Content ratings** | Fill the questionnaire honestly → expect Everyone |
| **News apps** | No |
| **COVID-19 contact tracing** | No |
| **App access** | "All functionality is available without special access" — there is no login wall; the PIN is local-only, so no demo credentials exist or are needed |
| **Advertising ID** | Not used |
| **App category** | Productivity |
| **Encryption declaration** | **Yes** → exempt: uses only publicly available standard encryption (AES-GCM, Argon2id) for data protection and authentication |

### Store listing copy (draft — edit as you like)

**Short description (80 chars max):**
```
Finance, tasks, notes, habits & encrypted vault — 100% offline private
```

**Full description:**
```
LifeHub is an all-in-one personal organizer that keeps your data on
your device — no accounts, no cloud, no tracking.

FINANCE
• Track income and expenses with custom categories
• Monthly budgets and savings goals with progress tracking
• Filterable reports with charts — export polished PDF reports

TASKS, NOTES & HABITS
• Tasks with priorities, due dates and reminders
• Quick notes with search
• Habit streaks and a completion calendar

SECURE VAULT
• Passwords and notes encrypted with AES-256-GCM
• Fingerprint or PIN unlock with automatic re-locking
• Built-in password generator

PRIVATE BY DESIGN
• No internet permission — data never leaves your device
• Encrypted backups you control (AES-256-GCM + Argon2id)
• Auto-clearing clipboard for copied passwords
```

> **Do NOT write:** banking, investment, loan, trading, cloud sync —
> none of those exist in the app and financial-services claims trigger
> extra policy requirements.

### Graphic assets

| Asset | Spec | Source |
|---|---|---|
| App icon | 512×512 PNG, no transparency | Export `docs/store-assets/icon-512.svg` (below) at 512px |
| Feature graphic | 1024×500 PNG/JPEG | Export `docs/store-assets/feature-graphic.svg` |
| Screenshots | ≥2, phone or 7"/10" tablet | Capture from the running app: Dashboard, Finance report, Vault |

## Phase 4 — Closed test (required for new accounts)

1. **Release → Testing → Closed testing → New track.**
2. Upload `app-release.aab` from
   `best_flutter_ui_templates/build/app/outputs/bundle/release/`.
3. Enable **Play App Signing** when offered — keep
   `android/lifehub-release.jks` backed up; it becomes the upload key.
4. Fill release name `1.0.0` + release notes:
   ```
   Initial release — offline personal organizer with finance tracking,
   tasks, notes, habits, and an encrypted vault.
   ```
5. Add testers: email list or share the opt-in link — need **≥12
   testers who stay opted in for 14 days**.
6. Optional but recommended: upload
   `build/app/outputs/mapping/release/mapping.txt` under
   **Deobfuscation files** so crash reports are readable.
7. During the test, fix any reported crash and bump `version:` in
   `pubspec.yaml` (e.g. `1.0.1+2`) before re-uploading — each upload
   needs a higher versionCode.

## Phase 5 — Production

1. After the 14-day requirement completes: **Production → New release →
   promote from closed test** (or upload the same AAB).
2. Choose rollout — 100% is fine, or staged (e.g. 20%) to catch issues.
3. Submit for review. First review typically takes **3–7 days**.

## If rejected

- Read the exact policy cited — fix that item only, then resubmit.
- Common first-rejection causes are missing/empty listing fields or a
  privacy policy URL that doesn't load — all covered above.
- You may appeal via the policy status page if the flag is wrong.

## After launch

- [ ] Keep `lifehub-release.jks` + passwords backed up in at least two
      safe places — losing the upload key means recovery paperwork.
- [ ] Monitor **Pre-launch report** and **Android Vitals** in console.
- [ ] Reply to early user reviews — boosts ranking and trust.
