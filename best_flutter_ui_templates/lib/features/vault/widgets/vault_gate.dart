import 'package:flutter/material.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/services/security_service.dart';
import '../../auth/screens/pin_screen.dart';

/// Requires biometric or PIN verification before showing [child].
class VaultGate extends StatefulWidget {
  const VaultGate({super.key, required this.child});

  final Widget child;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _checking = true;
  bool _canBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _unlocked) {
      setState(() => _unlocked = false);
    }
  }

  Future<void> _check() async {
    final canUse = await SecurityService.canUseBiometrics();
    final enrolled = canUse && await SecurityService.hasEnrolledBiometrics();
    if (!mounted) return;
    setState(() {
      _canBiometric = enrolled && SecurityService.biometricEnabled;
      _checking = false;
    });
    if (_canBiometric) {
      final ok = await SecurityService.authenticateBiometric();
      if (ok && mounted) {
        await SecurityService.resetPinFailures();
        if (mounted) setState(() => _unlocked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (SecurityService.hasPin) {
      return PinScreen(
        mode: PinMode.unlock,
        onSuccess: () => setState(() => _unlocked = true),
      );
    }
    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: LifeHubTheme.vault),
            const SizedBox(height: 16),
            const Text('Vault is locked', style: LifeHubTheme.headline),
            const SizedBox(height: 8),
            if (_canBiometric)
              FilledButton.icon(
                onPressed: () async {
                  final ok = await SecurityService.authenticateBiometric();
                  if (ok && mounted) {
                    await SecurityService.resetPinFailures();
                    if (mounted) setState(() => _unlocked = true);
                  }
                },
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock with fingerprint'),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Set a PIN in Settings to protect your vault.',
                  textAlign: TextAlign.center,
                  style: LifeHubTheme.subtitle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
