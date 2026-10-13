import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_db.dart';
import '../../../core/services/security_service.dart';

/// Authentication service. Works in three modes:
///  - 'firebase' — signed in with Google / email via Firebase Auth
///  - 'pin'      — local-only account protected by PIN (+ optional biometric)
///  - 'none'     — no auth configured yet (first run)
///
/// Firebase features activate automatically once `google-services.json`
/// (and `firebase_options.dart`) are added to the project.
class AuthService {
  AuthService._();

  static bool _firebaseReady = false;
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

  /// Try to initialise Firebase. Safe to call without config files —
  /// returns false and the app falls back to local/PIN mode.
  static Future<bool> initFirebase() async {
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (_) {
      _firebaseReady = false;
    }
    return _firebaseReady;
  }

  static bool get firebaseReady => _firebaseReady;

  static String get authMode =>
      LocalDb.settings.get(AppConstants.keyAuthMode, defaultValue: 'none')
          as String? ??
      'none';

  static bool get isSignedIn =>
      authMode == 'pin' ||
      (authMode == 'firebase' &&
          _firebaseReady &&
          FirebaseAuth.instance.currentUser != null);

  static User? get firebaseUser =>
      _firebaseReady ? FirebaseAuth.instance.currentUser : null;

  // ---------- Google Sign-In ----------

  static Future<User?> signInWithGoogle() async {
    if (!_firebaseReady) return null;
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = result.user;
    if (user != null) {
      await Future.wait([
        LocalDb.settings.put(AppConstants.keyAuthMode, 'firebase'),
        LocalDb.settings.put(AppConstants.keyUserName, user.displayName ?? ''),
        LocalDb.settings.put(AppConstants.keyUserEmail, user.email ?? ''),
        if (user.photoURL != null)
          LocalDb.settings.put(AppConstants.keyUserPhoto, user.photoURL),
      ]);
      markSessionAuthenticated();
    }
    return user;
  }

  // ---------- Email / password ----------

  static Future<String?> signInWithEmail(
    String email,
    String password, {
    bool createAccount = false,
  }) async {
    if (!_firebaseReady) return 'Firebase is not configured';
    try {
      if (createAccount) {
        final result = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await result.user?.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        return 'Verification email sent. Check your inbox before signing in.';
      }

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        return 'Verify your email first. A new verification link has been sent.';
      }
      await LocalDb.settings.put(AppConstants.keyAuthMode, 'firebase');
      await LocalDb.settings.put(AppConstants.keyUserEmail, email);
      if (user?.displayName != null) {
        await LocalDb.settings.put(AppConstants.keyUserName, user!.displayName);
      }
      markSessionAuthenticated();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Authentication failed';
    }
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    if (!_firebaseReady) throw StateError('Firebase is not configured.');
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  static bool get emailPasswordUser =>
      firebaseUser?.providerData.any((info) => info.providerId == 'password') ==
      true;

  static Future<void> deleteFirebaseAccount({String? password}) async {
    if (!_firebaseReady) throw StateError('Firebase is not configured.');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('No Firebase account is signed in.');
    final providerIds = user.providerData
        .map((info) => info.providerId)
        .toSet();

    late final AuthCredential credential;
    if (providerIds.contains('password')) {
      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw StateError(
          'The account password is required to delete this account.',
        );
      }
      credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
    } else if (providerIds.contains('google.com')) {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        throw StateError('Google re-authentication was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
    } else {
      throw StateError(
        'This account provider cannot be re-authenticated here.',
      );
    }

    await user.reauthenticateWithCredential(credential);
    await user.delete();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    _sessionAuthenticated = false;
    await LocalDb.settings.put(AppConstants.keyAuthMode, 'none');
    _notifyAuthChanged();
  }

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
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    if (_firebaseReady) {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    _sessionAuthenticated = false;
    await LocalDb.settings.put(AppConstants.keyAuthMode, 'none');
    _notifyAuthChanged();
  }

  static bool get requiresPinOnLaunch =>
      authMode == 'pin' && SecurityService.hasPin;
}
