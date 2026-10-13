import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/services/security_service.dart';

/// PIN screen used for three flows:
///  - setup: create a new PIN (with confirm step)
///  - unlock: verify PIN on app launch / vault access
///  - change: verify old PIN then set a new one
class PinScreen extends StatefulWidget {
  const PinScreen({super.key, required this.mode, required this.onSuccess});

  final PinMode mode;
  final VoidCallback onSuccess;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

enum PinMode { setup, unlock, change }

class _PinScreenState extends State<PinScreen> {
  final _controller = TextEditingController();
  String? _firstPin;
  String? _error;
  bool _biometricTried = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == PinMode.unlock) {
      _tryBiometric();
    }
  }

  @override
  void didUpdateWidget(covariant PinScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The app gate can replace setup with unlock without replacing the
    // widget State. Never carry the setup/confirmation text into unlock.
    if (oldWidget.mode != widget.mode) {
      _controller.clear();
      _firstPin = null;
      _error = null;
      if (widget.mode == PinMode.unlock) {
        _tryBiometric();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (!SecurityService.biometricEnabled || _biometricTried || _busy) return;
    _biometricTried = true;
    setState(() => _busy = true);
    try {
      if (!await SecurityService.canUseBiometrics()) return;
      final ok = await SecurityService.authenticateBiometric();
      if (ok && mounted) {
        await SecurityService.resetPinFailures();
        widget.onSuccess();
      }
    } finally {
      _biometricTried = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title {
    switch (widget.mode) {
      case PinMode.setup:
        return _firstPin == null ? 'Create a PIN' : 'Confirm your PIN';
      case PinMode.unlock:
        return 'Enter your PIN';
      case PinMode.change:
        return _firstPin == null ? 'Enter current PIN' : 'Enter new PIN';
    }
  }

  String _formatLockout(Duration duration) {
    final seconds = duration.inSeconds;
    return seconds >= 60
        ? '${(seconds / 60).ceil()} minutes'
        : '$seconds seconds';
  }

  Future<bool> _verifyEnteredPin(String pin) async {
    final result = await SecurityService.verifyPinAttempt(pin);
    if (!mounted) return false;
    if (result.status == PinAttemptStatus.success) return true;
    setState(() {
      _error = result.status == PinAttemptStatus.locked
          ? 'Too many attempts. Try again in ${_formatLockout(result.retryAfter!)}.'
          : 'Incorrect PIN';
      _controller.clear();
    });
    return false;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final pin = _controller.text.trim();
    if (pin.length < 4) {
      setState(
        () => _error = 'Enter at least 4 digits. Current: ${pin.length}/4',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      switch (widget.mode) {
        case PinMode.setup:
          if (_firstPin == null) {
            setState(() {
              _firstPin = pin;
              _controller.clear();
              _error = null;
            });
          } else if (_firstPin == pin) {
            await SecurityService.setPin(pin);
            if (mounted) widget.onSuccess();
          } else {
            setState(() {
              _error = 'PINs do not match';
              _firstPin = null;
              _controller.clear();
            });
          }
        case PinMode.unlock:
          if (await _verifyEnteredPin(pin)) widget.onSuccess();
        case PinMode.change:
          if (_firstPin == null) {
            if (await _verifyEnteredPin(pin)) {
              setState(() {
                _firstPin = pin;
                _controller.clear();
                _error = null;
              });
            }
          } else {
            await SecurityService.setPin(pin);
            if (mounted) widget.onSuccess();
          }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update PIN. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('LifeHub Security'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: widget.mode != PinMode.unlock,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: LifeHubTheme.nearlyDarkBlue,
            ),
            const SizedBox(height: 24),
            Text(_title, style: LifeHubTheme.headline),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              enabled: !_busy,
              autofocus: true,
              obscureText: true,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              textInputAction: TextInputAction.done,
              maxLength: 8,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                counterText: '${_controller.text.length}/8 digits',
                hintText: 'Enter 4–8 digits',
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
                setState(() {});
              },
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
            if (widget.mode == PinMode.unlock &&
                SecurityService.biometricEnabled) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _tryBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Use fingerprint'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
