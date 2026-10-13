import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/lifehub_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers/privacy_providers.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/backup_crypto.dart';
import '../../core/services/local_db.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/security_service.dart';
import '../../core/widgets/restore_recovery_screen.dart';
import '../auth/screens/pin_screen.dart';
import '../auth/services/auth_service.dart';
import '../finance/providers/finance_providers.dart';
import '../habits/providers/habits_providers.dart';
import '../notes_tasks/providers/notes_tasks_providers.dart';
import '../profile/providers/profile_provider.dart';
import '../vault/providers/vault_providers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _biometric = SecurityService.biometricEnabled;
  bool _canBiometric = false;
  bool _biometricEnrolled = false;
  bool _backupBusy = false;
  String _appVersion = '…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshBiometricStatus();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      if (mounted) setState(() => _appVersion = 'unknown');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBiometricStatus();
    }
  }

  Future<void> _refreshBiometricStatus() async {
    final canUse = await SecurityService.canUseBiometrics();
    final enrolled = canUse && await SecurityService.hasEnrolledBiometrics();
    if (!mounted) return;
    setState(() {
      _canBiometric = canUse;
      _biometricEnrolled = enrolled;
      _biometric = enrolled && SecurityService.biometricEnabled;
    });
  }

  Future<void> _registerFingerprint() async {
    await SecurityService.openBiometricEnrollment();
    await _refreshBiometricStatus();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        LocalDb.settings.get(AppConstants.keyCurrency, defaultValue: '₱')
            as String;

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const _Header('Security'),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: const Text('Change PIN'),
            subtitle: Text(
              SecurityService.hasPin ? 'PIN is set' : 'No PIN set',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PinScreen(
                  mode: SecurityService.hasPin ? PinMode.change : PinMode.setup,
                  onSuccess: () {
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(
              _biometricEnrolled
                  ? 'Device fingerprint registered'
                  : 'Register fingerprint in Android Settings',
            ),
            subtitle: Text(
              !_canBiometric
                  ? 'No biometric hardware available'
                  : _biometricEnrolled
                  ? 'Your device fingerprint is ready to use'
                  : 'Register a fingerprint in Android Settings',
            ),
            trailing: _canBiometric && !_biometricEnrolled
                ? const Icon(Icons.open_in_new)
                : Icon(
                    _biometricEnrolled
                        ? Icons.check_circle
                        : Icons.fingerprint_outlined,
                  ),
            onTap: _canBiometric && !_biometricEnrolled
                ? _registerFingerprint
                : null,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock_open_outlined),
            title: const Text('Fingerprint unlock'),
            subtitle: Text(
              _biometricEnrolled
                  ? 'Use fingerprint to unlock LifeHub'
                  : 'Register a fingerprint first',
            ),
            value: _biometric,
            onChanged: _biometricEnrolled
                ? (v) {
                    SecurityService.biometricEnabled = v;
                    setState(() => _biometric = v);
                  }
                : null,
          ),
          const _Header('Preferences'),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Currency symbol'),
            subtitle: Text('Current: $currency'),
            onTap: () => _editCurrency(currency),
          ),
          const _HideAmountsTile(),
          const _HabitReminderTile(),
          ListTile(
            leading: const Icon(Icons.notification_add_outlined),
            title: const Text('Send test notification'),
            subtitle: const Text('Verify reminders can reach your device'),
            onTap: () async {
              final ok = await NotificationService.showTestNotification();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Test notification sent — check your status bar'
                        : 'Could not send. Enable notifications for LifeHub in Android Settings.',
                  ),
                ),
              );
            },
          ),
          const _Header('Data'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export encrypted backup'),
            subtitle: const Text(
              'Create a passphrase-protected portable backup',
            ),
            trailing: _backupBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _backupBusy ? null : _exportBackup,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restore backup'),
            subtitle: const Text(
              'Restore a passphrase-protected backup from any device',
            ),
            onTap: _backupBusy ? null : _restoreBackup,
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.red,
            ),
            title: const Text(
              'Clear all data',
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Deletes everything — cannot be undone'),
            onTap: () => _confirmClearData(context),
          ),
          const _Header('Account'),
          if (AuthService.firebaseReady &&
              AuthService.firebaseUser != null) ...[
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: Text(AuthService.firebaseUser!.email ?? 'Signed in'),
              subtitle: const Text(
                'Authentication only — your data is not cloud-synced.',
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.person_remove_outlined,
                color: Colors.red,
              ),
              title: const Text(
                'Delete account',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text(
                'Delete the Firebase account and all local LifeHub data',
              ),
              onTap: _deleteFirebaseAccount,
            ),
          ],
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          const _Header('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('LifeHub'),
            subtitle: Text(
              'Version $_appVersion — All-in-One Personal Organizer',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open source licenses'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'LifeHub',
              applicationVersion: _appVersion,
              applicationLegalese:
                  'LifeHub includes MIT-licensed source from the original template project and open-source fonts and packages.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFirebaseAccount() async {
    final passwordController = TextEditingController();
    final requiresPassword = AuthService.emailPasswordUser;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account and local data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This permanently deletes the Firebase account and removes all LifeHub data stored on this device. Export an encrypted backup first if you need to keep it.',
            ),
            if (requiresPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm account password',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    final password = passwordController.text;
    passwordController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await AuthService.deleteFirebaseAccount(
        password: requiresPassword ? password : null,
      );
      await BackupService.clearAllData();
      await AuthService.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Account deletion failed: $e')));
      }
    }
  }

  Future<String?> _requestBackupPassphrase({required bool confirm}) async {
    final passphraseController = TextEditingController();
    final confirmationController = TextEditingController();
    String? error;
    final result =
        await showDialog<String>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              void submit() {
                final passphrase = passphraseController.text;
                if (passphrase.isEmpty ||
                    (confirm &&
                        passphrase.length <
                            BackupCrypto.minimumPassphraseLength)) {
                  setDialogState(
                    () => error = confirm
                        ? 'Use at least 12 characters.'
                        : 'Enter the backup passphrase.',
                  );
                  return;
                }
                if (confirm && passphrase != confirmationController.text) {
                  setDialogState(() => error = 'Passphrases do not match.');
                  return;
                }
                Navigator.pop(ctx, passphrase);
              }

              return AlertDialog(
                title: Text(confirm ? 'Protect backup' : 'Unlock backup'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (confirm)
                      const Text(
                        'This passphrase is not stored. You will need it to restore this backup on any device.',
                        style: LifeHubTheme.caption,
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passphraseController,
                      obscureText: true,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Passphrase',
                      ),
                      textInputAction: confirm
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: confirm ? null : (_) => submit(),
                    ),
                    if (confirm) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmationController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm passphrase',
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: submit,
                    child: Text(confirm ? 'Create backup' : 'Continue'),
                  ),
                ],
              );
            },
          ),
        ).whenComplete(() {
          passphraseController.dispose();
          confirmationController.dispose();
        });
    return result;
  }

  Future<void> _exportBackup() async {
    final passphrase = await _requestBackupPassphrase(confirm: true);
    if (passphrase == null || !mounted) return;
    setState(() => _backupBusy = true);
    try {
      await BackupService.shareBackup(passphrase: passphrase);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked.isEmpty ? null : picked.single.path;
    if (path == null || !mounted) return;

    setState(() => _backupBusy = true);
    try {
      final source = await BackupService.readBackup(File(path));
      final passphrase = source.requiresPassphrase
          ? await _requestBackupPassphrase(confirm: false)
          : null;
      if (source.requiresPassphrase && passphrase == null || !mounted) return;
      final prepared = await source.prepare(passphrase: passphrase);
      if (!mounted) return;
      final preview = prepared.preview;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore backup?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.exportedAt != null)
                  Text(
                    'Backup from ${preview.exportedAt!.toLocal()}',
                    style: LifeHubTheme.caption,
                  ),
                const SizedBox(height: 8),
                for (final e in preview.counts.entries)
                  Text('${e.key.replaceAll('_', ' ')}: ${e.value}'),
                const SizedBox(height: 12),
                const Text(
                  'This replaces all current data on this device.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                if (preview.legacyUnencrypted) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'This older backup is not encrypted. Anyone with the file may be able to read its contents.',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
                if (preview.vaultMayBeUnavailable) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'This backup has no portable vault key. Vault passwords may not be available on this device.',
                    style: LifeHubTheme.caption,
                  ),
                ],
                if (preview.missingProfilePhoto) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'The original profile photo was not included or could not be restored.',
                    style: LifeHubTheme.caption,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await BackupService.applyBackup(prepared);
      _refreshProviders();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backup restored')));
    } on BackupCryptoException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on StateError catch (e) {
      if (e.toString().contains('recovery is pending') && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => RestoreRecoveryScreen(
              onRecovered: () {
                if (!mounted) return;
                _refreshProviders();
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  void _refreshProviders() {
    final container = ProviderScope.containerOf(context, listen: false);
    container
      ..invalidate(hideAmountsProvider)
      ..invalidate(profileProvider)
      ..invalidate(transactionsProvider)
      ..invalidate(budgetsProvider)
      ..invalidate(savingsProvider)
      ..invalidate(notesProvider)
      ..invalidate(tasksProvider)
      ..invalidate(habitsProvider)
      ..invalidate(vaultProvider);
  }

  void _confirmClearData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes all transactions, budgets, savings, notes, tasks, habits, and vault entries. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await BackupService.clearAllData();
              await AuthService.signOut();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
  }

  void _editCurrency(String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Currency symbol'),
        content: TextField(
          controller: controller,
          maxLength: 3,
          decoration: const InputDecoration(hintText: 'e.g. ₱, \$, €'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) {
                LocalDb.settings.put(AppConstants.keyCurrency, v);
                setState(() {});
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _HideAmountsTile extends ConsumerWidget {
  const _HideAmountsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(hideAmountsProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.visibility_off_outlined),
      title: const Text('Hide amounts'),
      subtitle: const Text('Mask balances and totals across the app'),
      value: hidden,
      onChanged: (v) => ref.read(hideAmountsProvider.notifier).set(v),
    );
  }
}

class _HabitReminderTile extends StatefulWidget {
  const _HabitReminderTile();

  @override
  State<_HabitReminderTile> createState() => _HabitReminderTileState();
}

class _HabitReminderTileState extends State<_HabitReminderTile> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    final s = LocalDb.settings;
    _enabled =
        s.get(AppConstants.keyHabitReminderEnabled, defaultValue: false) ==
        true;
    final t =
        s.get(AppConstants.keyHabitReminderTime, defaultValue: '08:00')
            as String;
    final parts = t.split(':');
    _time = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _save() async {
    final s = LocalDb.settings;
    await s.put(AppConstants.keyHabitReminderEnabled, _enabled);
    await s.put(
      AppConstants.keyHabitReminderTime,
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
    );
    if (_enabled) {
      final result = await NotificationService.scheduleDailyReminder(
        id: 'habit_daily_reminder',
        title: 'Habit Reminder',
        body: 'Take a moment to check your habits.',
        hour: _time.hour,
        minute: _time.minute,
      );
      if (!result.scheduled) {
        await s.put(AppConstants.keyHabitReminderEnabled, false);
        if (!mounted) return;
        setState(() => _enabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Habit reminder not enabled. Allow notifications for LifeHub and try again.',
            ),
          ),
        );
      } else if (result.status == ReminderScheduleStatus.inexact && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reminder is enabled, but Android may deliver it a little later.',
            ),
          ),
        );
      }
    } else {
      await NotificationService.cancel('habit_daily_reminder');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.alarm),
      title: const Text('Daily habit reminder'),
      subtitle: Text(
        _enabled
            ? 'Every day at ${_time.format(context)}'
            : 'Get a daily nudge to complete your habits',
      ),
      value: _enabled,
      onChanged: (v) async {
        if (v) {
          final picked = await showTimePicker(
            context: context,
            initialTime: _time,
          );
          if (picked == null) return;
          _time = picked;
        }
        if (!mounted) return;
        setState(() => _enabled = v);
        await _save();
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: LifeHubTheme.caption.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: LifeHubTheme.nearlyDarkBlue,
        ),
      ),
    );
  }
}
