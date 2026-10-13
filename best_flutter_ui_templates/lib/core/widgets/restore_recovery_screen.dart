import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../../features/finance/data/finance_repository.dart';
import '../../features/auth/services/auth_service.dart';

class RestoreRecoveryScreen extends StatefulWidget {
  const RestoreRecoveryScreen({super.key, required this.onRecovered});

  final VoidCallback onRecovered;

  @override
  State<RestoreRecoveryScreen> createState() => _RestoreRecoveryScreenState();
}

class _RestoreRecoveryScreenState extends State<RestoreRecoveryScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await BackupService.recoverInterruptedRestore();
      try {
        await FinanceRepository.ensureTransactionIndex();
      } catch (_) {}
      try {
        await BackupService.removeLegacyPlaintextBackup();
      } catch (_) {}
      try {
        await NotificationService.init();
      } catch (_) {}
      try {
        await AuthService.initFirebase();
      } catch (_) {}
      if (mounted) widget.onRecovered();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Recovery could not finish. Keep LifeHub installed and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restore, size: 48),
              const SizedBox(height: 16),
              const Text(
                'LifeHub needs to recover the previous data before it can open.',
                textAlign: TextAlign.center,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _retry,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Retry recovery'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
