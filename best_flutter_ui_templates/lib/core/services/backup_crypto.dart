import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart' show randomBytes;

class BackupCryptoException implements Exception {
  const BackupCryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupCrypto {
  BackupCrypto._();

  static const formatVersion = 2;
  static const minimumPassphraseLength = 12;
  static const _memoryKiB = 19456;
  static const _iterations = 2;
  static const _parallelism = 1;
  static const _hashLength = 32;
  static const _aad = 'LifeHub encrypted backup v2';
  static const _maxEncryptedFileBytes = 50 * 1024 * 1024;

  static bool isEncryptedEnvelope(Object? decoded) =>
      decoded is Map &&
      decoded['app'] == 'LifeHub' &&
      decoded['format'] == 'lifehub-encrypted-backup' &&
      decoded['version'] == formatVersion;

  static Future<Uint8List> encryptJson(
    Map<String, dynamic> payload,
    String passphrase,
  ) async {
    if (passphrase.length < minimumPassphraseLength) {
      throw const BackupCryptoException(
        'Use a backup passphrase with at least 12 characters.',
      );
    }

    final salt = randomBytes(16);
    final cipher = AesGcm.with256bits();
    final nonce = cipher.newNonce();
    final secretKey = await _deriveKey(passphrase, salt);
    final encrypted = await cipher.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode(_aad),
    );
    final envelope = <String, dynamic>{
      'app': 'LifeHub',
      'format': 'lifehub-encrypted-backup',
      'version': formatVersion,
      'kdf': {
        'algorithm': 'argon2id',
        'memoryKiB': _memoryKiB,
        'iterations': _iterations,
        'parallelism': _parallelism,
        'hashLength': _hashLength,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'algorithm': 'aes-256-gcm',
        'nonce': base64Encode(encrypted.nonce),
        'ciphertext': base64Encode(encrypted.cipherText),
        'mac': base64Encode(encrypted.mac.bytes),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  static Future<Map<String, dynamic>> decryptJson(
    String encodedEnvelope,
    String passphrase,
  ) async {
    try {
      if (utf8.encode(encodedEnvelope).length > _maxEncryptedFileBytes) {
        throw const BackupCryptoException('Backup file is too large.');
      }
      final decoded = jsonDecode(encodedEnvelope);
      if (!isEncryptedEnvelope(decoded)) {
        throw const BackupCryptoException(
          'This file is not a supported encrypted LifeHub backup.',
        );
      }
      final envelope = decoded as Map;
      final kdf = envelope['kdf'];
      final cipherMap = envelope['cipher'];
      if (kdf is! Map || cipherMap is! Map) {
        throw const BackupCryptoException('Backup file is damaged.');
      }
      if (kdf['algorithm'] != 'argon2id' ||
          kdf['memoryKiB'] != _memoryKiB ||
          kdf['iterations'] != _iterations ||
          kdf['parallelism'] != _parallelism ||
          kdf['hashLength'] != _hashLength ||
          cipherMap['algorithm'] != 'aes-256-gcm') {
        throw const BackupCryptoException(
          'This backup uses unsupported encryption settings.',
        );
      }

      final salt = _decodeBase64(kdf['salt']);
      final nonce = _decodeBase64(cipherMap['nonce']);
      final ciphertext = _decodeBase64(cipherMap['ciphertext']);
      final mac = _decodeBase64(cipherMap['mac']);
      if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
        throw const BackupCryptoException('Backup file is damaged.');
      }

      final secretKey = await _deriveKey(passphrase, salt);
      final cleartext = await AesGcm.with256bits().decrypt(
        SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
        aad: utf8.encode(_aad),
      );
      final payload = jsonDecode(utf8.decode(cleartext));
      if (payload is! Map<String, dynamic>) {
        throw const BackupCryptoException('Backup contents are damaged.');
      }
      return payload;
    } on BackupCryptoException {
      rethrow;
    } catch (_) {
      throw const BackupCryptoException(
        'Incorrect passphrase or damaged backup file.',
      );
    }
  }

  static Future<SecretKey> _deriveKey(String passphrase, List<int> salt) =>
      Argon2id(
        parallelism: _parallelism,
        memory: _memoryKiB,
        iterations: _iterations,
        hashLength: _hashLength,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt);

  static List<int> _decodeBase64(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const BackupCryptoException('Backup file is damaged.');
    }
    return base64Decode(value);
  }
}
