import 'package:flutter/material.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/services/security_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSignedIn,
    this.onBiometricSignedIn,
  });

  final VoidCallback onSignedIn;
  final VoidCallback? onBiometricSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  bool _biometricAvailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final available =
        SecurityService.hasPin &&
        SecurityService.biometricEnabled &&
        await SecurityService.hasEnrolledBiometrics();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  Future<void> _useBiometric() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AuthService.signInWithBiometric();
    if (!mounted) return;
    if (ok) {
      (widget.onBiometricSignedIn ?? widget.onSignedIn)();
    } else {
      setState(
        () => _error = 'Fingerprint authentication was cancelled or failed',
      );
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: LifeHubTheme.nearlyDarkBlue,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('LifeHub', style: LifeHubTheme.display1),
                const SizedBox(height: 4),
                const Text(
                  'All-in-One Personal Organizer',
                  style: LifeHubTheme.subtitle,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Offline mode — your data stays on this device.',
                  style: LifeHubTheme.subtitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.pin_outlined),
                    label: const Text('Continue with PIN'),
                    onPressed: _busy
                        ? null
                        : () async {
                            await AuthService.signInLocal();
                            if (mounted) widget.onSignedIn();
                          },
                  ),
                ),
                if (_biometricAvailable) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _busy ? null : _useBiometric,
                    icon: const Icon(
                      Icons.fingerprint,
                      color: LifeHubTheme.nearlyDarkBlue,
                    ),
                    label: const Text(
                      'Use fingerprint',
                      style: TextStyle(color: LifeHubTheme.nearlyDarkBlue),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
