import 'package:flutter/material.dart';

import '../../app/lifehub_theme.dart';

/// In-app privacy policy — required by Play policy and honest anyway:
/// LifeHub is fully local-first, so the policy is short and readable.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    (
      'The short version',
      'LifeHub collects no data. Everything you enter stays on your '
          'device. There are no accounts, no servers, no analytics, no '
          'ads, and no tracking. The app works fully offline and does '
          'not connect to the internet.',
    ),
    (
      'What the app stores, and where',
      'All of the following is stored only in the app\'s private storage '
          'on your device:\n\n'
          '• Finance data — transactions, budgets, savings goals\n'
          '• Tasks, notes, and habits — including their reminder schedules\n'
          '• Vault entries — passwords and notes encrypted with '
          'AES-256-GCM; the encryption key is held in Android\'s secure '
          'keystore, not on disk in plain text\n'
          '• Security settings — your unlock PIN, stored only as an '
          'Argon2id hash, and your biometric-unlock preference\n'
          '• Backups — optional, encrypted with AES-256-GCM using a '
          'passphrase you choose; created only when you export one',
    ),
    (
      'Permissions, and what they\'re for',
      '• Biometrics — optional fingerprint unlock. Fingerprint data is '
          'managed entirely by Android; the app never sees or stores it.\n'
          '• Notifications — deliver the reminders you schedule.\n'
          '• Boot completed — re-register your reminders after a restart.\n\n'
          'The app does not use the internet permission — it cannot send '
          'your data anywhere, by design.\n\n'
          'Photos and files are accessed only when you explicitly pick '
          'them (profile photo, backup restore, PDF report sharing). '
          'Camera access is used only when you choose "Take photo".',
    ),
    (
      'Data sharing',
      'None. There is nothing to share — no data ever leaves your '
          'device except files you export yourself (backups, PDF '
          'reports) through the share targets you choose.',
    ),
    (
      'Your control over your data',
      '• Export — Settings → Backup creates an encrypted backup file you keep\n'
          '• Delete — Settings → Clear all data erases everything '
          'on-device; uninstalling the app also removes all data',
    ),
    (
      'Security',
      '• Vault and backup data are encrypted with AES-256-GCM\n'
          '• Backup keys are derived from your passphrase with Argon2id\n'
          '• PINs are hashed with Argon2id and never stored in plain text\n'
          '• Vault keys live in Android\'s hardware-backed secure storage',
    ),
    (
      'Children\'s privacy',
      'The app is not directed at children and collects no personal '
          'information from anyone, of any age.',
    ),
    (
      'Contact',
      'Questions about this policy? Reach the developer through the '
          'contact email listed on the app\'s Play Store page.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Privacy policy'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Container(
            decoration: LifeHubTheme.cardDecoration,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LifeHub Privacy Policy',
                  style: LifeHubTheme.title.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Last updated: October 2026',
                  style: LifeHubTheme.caption,
                ),
                const SizedBox(height: 16),
                for (final (title, body) in _sections) ...[
                  Text(title, style: LifeHubTheme.title),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: LifeHubTheme.body1.copyWith(
                      color: LifeHubTheme.lightText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
