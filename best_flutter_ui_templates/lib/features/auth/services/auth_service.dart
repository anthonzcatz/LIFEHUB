import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_db.dart';
import '../../../core/services/security_service.dart';

/// Authentication service. LifeHub is local-first:
///  - 'pin'  — local account protected by PIN (+ optional biometric)
///  - 'none' — no auth configured yet (first run)
///
/// A stored 'firebase' mode is treated as signed out — remote auth
/// support was removed; the app is fully offline.
class AuthService {
  AuthService._();

  static bool _sessionAuthenticated = false;

  static final authRevision = ValueNotifier<int>(0);

  static bool get sessionAuthenticated => _sessionAuthenticated;

  static void _notifyAuthChanged() => authRevision.value++;

  static void markSessionAuthenticated() {
    _sessionAuthenticated = true;
    _notifyAuthChanged();
  }

  static void lockSession() {
    if (!_sessionAuthenticated) return;
    _sessionAuthenticated = false;
    _notifyAuthChanged();
  }

  static String get authMode =>
      LocalDb.settings.get(AppConstants.keyAuthMode, defaultValue: 'none')
          as String? ??
      'none';

  static bool get isSignedIn => authMode == 'pin';

  // ---------- Local PIN mode ----------

  static Future<void> signInLocal() async {
    _sessionAuthenticated = false;
    await LocalDb.settings.put(AppConstants.keyAuthMode, 'pin');
    _notifyAuthChanged();
  }

  static Future<bool> signInWithBiometric() async {
    if (!SecurityService.hasPin ||
        !SecurityService.biometricEnabled ||
        !await SecurityService.hasEnrolledBiometrics()) {
      return false;
    }
    final authenticated = await SecurityService.authenticateBiometric();
    if (!authenticated) return false;
    await SecurityService.resetPinFailures();
    await LocalDb.settings.put(AppConstants.keyAuthMode, 'pin');
    markSessionAuthenticated();
    return true;
  }

  static Future<void> signOut() async {
    _sessionAuthenticated = false;
    await LocalDb.settings.put(AppConstants.keyAuthMode, 'none');
    _notifyAuthChanged();
  }

  static bool get requiresPinOnLaunch =>
      authMode == 'pin' && SecurityService.hasPin;
}
