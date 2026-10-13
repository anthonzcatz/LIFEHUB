import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart'
    show constantTimeBytesEquality, randomBytes;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../constants/app_constants.dart';
import 'aes_cipher.dart';
import 'local_db.dart';

enum PinAttemptStatus { success, rejected, locked }

class PinAttemptResult {
  const PinAttemptResult(this.status, {this.retryAfter});

  final PinAttemptStatus status;
  final Duration? retryAfter;
}

/// Handles PIN hashing/verification, biometric auth and AES encryption
/// for the password vault.
class SecurityService {
  SecurityService._();

  static const _secureStorage = FlutterSecureStorage();
  static const _vaultKeyStorageKey = 'lifehub_vault_aes_key';
  static const _restoreJournalStorageKey = 'lifehub_restore_journal_key';
  static final _localAuth = LocalAuthentication();

  // ---------- PIN ----------

  static const _pinHashPrefix = 'argon2id:v1:';
  static const _pinLockoutThreshold = 5;
  static const _pinLockoutBaseSeconds = 30;
  static const _pinLockoutMaxSeconds = 900;

  static bool get hasPin =>
      LocalDb.settings.get(AppConstants.keyPinHash) != null;

  static Future<String> _hashPin(String pin, String salt) async {
    final digest = await Sha256().hash(utf8.encode('$salt::$pin'));
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<List<int>> _derivePinHash(String pin, List<int> salt) async =>
      (await Argon2id(
        parallelism: 1,
        memory: 19456,
        iterations: 2,
        hashLength: 32,
      ).deriveKeyFromPassword(password: pin, nonce: salt)).extractBytes();

  static Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw ArgumentError.value(pin.length, 'pin', 'Must be 4 to 8 digits.');
    }
    final salt = randomBytes(16);
    final hash = await _derivePinHash(pin, salt);
    await LocalDb.settings.put(
      AppConstants.keyPinHash,
      '$_pinHashPrefix${base64Encode(salt)}:${base64Encode(hash)}',
    );
    await LocalDb.settings.delete(AppConstants.keyPinSalt);
    await _clearPinFailures();
  }

  static Future<bool> verifyPin(String pin) async =>
      (await verifyPinAttempt(pin)).status == PinAttemptStatus.success;

  static Future<PinAttemptResult> verifyPinAttempt(String pin) async {
    final lockout = await pinLockoutRemaining();
    if (lockout != null) {
      return PinAttemptResult(PinAttemptStatus.locked, retryAfter: lockout);
    }

    final hash = LocalDb.settings.get(AppConstants.keyPinHash) as String?;
    if (hash == null) return _recordPinFailure();
    var verified = false;
    var migrateLegacy = false;
    if (hash.startsWith(_pinHashPrefix)) {
      final parts = hash.split(':');
      if (parts.length == 4 && parts[0] == 'argon2id' && parts[1] == 'v1') {
        try {
          final salt = base64Decode(parts[2]);
          final expected = base64Decode(parts[3]);
          if (salt.length == 16 && expected.length == 32) {
            final actual = await _derivePinHash(pin, salt);
            verified = constantTimeBytesEquality.equals(actual, expected);
          }
        } catch (_) {}
      }
    } else {
      final salt = LocalDb.settings.get(AppConstants.keyPinSalt) as String?;
      if (salt != null) {
        final actual = ascii.encode(await _hashPin(pin, salt));
        final expected = ascii.encode(hash);
        verified = constantTimeBytesEquality.equals(actual, expected);
        migrateLegacy = verified;
      }
    }

    if (!verified) return _recordPinFailure();
    if (migrateLegacy) {
      await setPin(pin);
    } else {
      await _clearPinFailures();
    }
    return const PinAttemptResult(PinAttemptStatus.success);
  }

  static Future<Duration?> pinLockoutRemaining() async {
    final raw = LocalDb.settings.get(AppConstants.keyPinLockUntil);
    if (raw is! int) return null;
    final remaining = raw - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) {
      await LocalDb.settings.delete(AppConstants.keyPinLockUntil);
      return null;
    }
    return Duration(milliseconds: remaining);
  }

  static Future<PinAttemptResult> _recordPinFailure() async {
    final raw = LocalDb.settings.get(
      AppConstants.keyPinFailedAttempts,
      defaultValue: 0,
    );
    final attempts = (raw is int ? raw : 0) + 1;
    await LocalDb.settings.put(AppConstants.keyPinFailedAttempts, attempts);
    if (attempts < _pinLockoutThreshold) {
      return const PinAttemptResult(PinAttemptStatus.rejected);
    }
    final exponent = (attempts - _pinLockoutThreshold).clamp(0, 5);
    final seconds = (_pinLockoutBaseSeconds * (1 << exponent)).clamp(
      _pinLockoutBaseSeconds,
      _pinLockoutMaxSeconds,
    );
    await LocalDb.settings.put(
      AppConstants.keyPinLockUntil,
      DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch,
    );
    return PinAttemptResult(
      PinAttemptStatus.locked,
      retryAfter: Duration(seconds: seconds),
    );
  }

  static Future<void> _clearPinFailures() async {
    await Future.wait([
      LocalDb.settings.delete(AppConstants.keyPinFailedAttempts),
      LocalDb.settings.delete(AppConstants.keyPinLockUntil),
    ]);
  }

  static Future<void> resetPinFailures() => _clearPinFailures();

  static Future<void> clearPin() async {
    await Future.wait([
      LocalDb.settings.delete(AppConstants.keyPinHash),
      LocalDb.settings.delete(AppConstants.keyPinSalt),
      LocalDb.settings.delete(AppConstants.keyPinFailedAttempts),
      LocalDb.settings.delete(AppConstants.keyPinLockUntil),
    ]);
  }

  static Future<void> clearVaultKey() async {
    await _secureStorage.delete(key: _vaultKeyStorageKey);
  }

  static Future<String> vaultKeyForBackup() async =>
      base64Encode(await _vaultKey());

  static Future<String?> existingVaultKey() =>
      _secureStorage.read(key: _vaultKeyStorageKey);

  static Future<void> restoreVaultKey(String? encodedKey) async {
    if (encodedKey == null) {
      await clearVaultKey();
      return;
    }
    final key = base64Decode(encodedKey);
    if (key.length != 32) throw const FormatException('Invalid vault key');
    await _secureStorage.write(
      key: _vaultKeyStorageKey,
      value: base64Encode(key),
    );
  }

  static Future<void> verifyVaultCiphertextWithKey(
    String stored,
    String encodedKey,
  ) async {
    if (stored.isEmpty) return;
    final parts = stored.split(':');
    if (parts.length != 3 || parts[0] != 'gcm') return;
    await AesCipher.decryptGcm64(
      parts[2],
      base64Decode(encodedKey),
      base64Decode(parts[1]),
    );
  }

  static Future<String> createRestoreJournalKey() async {
    final key = base64Encode(AesCipher.randomKey());
    await _secureStorage.write(key: _restoreJournalStorageKey, value: key);
    return key;
  }

  static Future<String?> restoreJournalKey() =>
      _secureStorage.read(key: _restoreJournalStorageKey);

  static Future<void> clearRestoreJournalKey() =>
      _secureStorage.delete(key: _restoreJournalStorageKey);

  // ---------- Biometrics ----------

  static bool get biometricEnabled =>
      LocalDb.settings.get(
        AppConstants.keyBiometricEnabled,
        defaultValue: false,
      ) ==
      true;

  static set biometricEnabled(bool value) =>
      LocalDb.settings.put(AppConstants.keyBiometricEnabled, value);

  static Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasEnrolledBiometrics() async {
    // local_auth's getAvailableBiometrics() can report an empty list on
    // MIUI/HyperOS even when fingerprints are enrolled. The native
    // BiometricManager.canAuthenticate check is authoritative on Android.
    try {
      final enrolled = await const MethodChannel(
        'lifehub/security',
      ).invokeMethod<bool>('canAuthenticateBiometric');
      if (enrolled != null) return enrolled;
    } on PlatformException {
      // Channel unavailable (e.g. non-Android host) — fall through.
    }
    try {
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openBiometricEnrollment() async {
    try {
      return await const MethodChannel(
            'lifehub/security',
          ).invokeMethod<bool>('openBiometricEnrollment') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Unlock LifeHub',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ---------- Vault encryption ----------

  static Future<List<int>> _vaultKey() async {
    var stored = await _secureStorage.read(key: _vaultKeyStorageKey);
    if (stored == null) {
      final key = AesCipher.randomKey();
      stored = base64Encode(key);
      await _secureStorage.write(key: _vaultKeyStorageKey, value: stored);
    }
    return base64Decode(stored);
  }

  static Future<String> encryptText(String plainText) async {
    final key = await _vaultKey();
    final iv = AesCipher.randomIv();
    final data = await AesCipher.encryptGcm64(utf8.encode(plainText), key, iv);
    return 'gcm:${base64Encode(iv)}:$data';
  }

  /// Returns null when the value cannot be decrypted — e.g. a backup
  /// restored on a different device, which lacks the original vault key.
  static Future<String?> decryptText(String stored) async {
    try {
      final parts = stored.split(':');
      final key = await _vaultKey();
      if (parts.length == 3 && parts[0] == 'gcm') {
        return AesCipher.decryptGcm64(parts[2], key, base64Decode(parts[1]));
      }
      if (parts.length == 2) {
        return AesCipher.decryptCbc64(parts[1], key, base64Decode(parts[0]));
      }
    } catch (_) {
      // Wrong key or corrupt ciphertext.
    }
    return null;
  }

  // ---------- Helpers ----------
}
