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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  bool _biometricAvailable = false;
  String? _error;
  String? _info;

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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  Future<void> _run(Future<dynamic> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (result is String) {
        if (result.startsWith('Verification email sent') ||
            result.startsWith('Verify your email first')) {
          setState(() => _info = result);
        } else {
          setState(() => _error = result);
        }
      } else if (result != null) {
        widget.onSignedIn();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.sendPasswordResetEmail(email);
      if (mounted) {
        setState(() => _info = 'Password reset email sent. Check your inbox.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                if (AuthService.firebaseReady) ...[
                  const Text(
                    'Firebase sign-in authenticates your account only. LifeHub data stays on this device and is not cloud-synced.',
                    textAlign: TextAlign.center,
                    style: LifeHubTheme.caption,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      onPressed: _busy
                          ? null
                          : () => _run(() => AuthService.signInWithGoogle()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              final error = await AuthService.signInWithEmail(
                                _emailController.text.trim(),
                                _passwordController.text,
                                createAccount: _createAccount,
                              );
                              return error ?? true;
                            }),
                      child: Text(
                        _createAccount ? 'Create Account' : 'Sign In',
                      ),
                    ),
                  ),
                  if (!_createAccount)
                    TextButton(
                      onPressed: _busy ? null : _sendPasswordReset,
                      child: const Text('Forgot password?'),
                    ),
                  TextButton(
                    onPressed: () => setState(() {
                      _createAccount = !_createAccount;
                      _info = null;
                      _error = null;
                    }),
                    child: Text(
                      _createAccount
                          ? 'Already have an account? Sign in'
                          : 'No account? Create one',
                    ),
                  ),
                  const Divider(height: 32),
                ] else ...[
                  const Text(
                    'Offline mode — your data stays on this device.',
                    style: LifeHubTheme.subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],
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
                if (_info != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _info!,
                    style: const TextStyle(color: LifeHubTheme.finance),
                    textAlign: TextAlign.center,
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
