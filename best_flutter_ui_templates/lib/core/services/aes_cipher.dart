import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart' show randomBytes;

/// AES-256 helpers matching the wire format previously produced by the
/// `encrypt` package: base64(iv) + base64(ciphertext || 16-byte GCM tag).
/// Keeps vault entries and restore journals written by older builds
/// decryptable after the package swap.
class AesCipher {
  AesCipher._();

  static final _gcm = AesGcm.with256bits();
  static final _cbc = AesCbc.with256bits(macAlgorithm: MacAlgorithm.empty);

  static List<int> randomKey() => randomBytes(32);
  static List<int> randomIv() => randomBytes(12);

  /// AES-256-GCM encrypt; returns base64(ciphertext || tag).
  static Future<String> encryptGcm64(
    List<int> plaintext,
    List<int> key,
    List<int> iv,
  ) async {
    final box = await _gcm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: iv,
    );
    return base64Encode([...box.cipherText, ...box.mac.bytes]);
  }

  /// AES-256-GCM decrypt of base64(ciphertext || tag).
  static Future<String> decryptGcm64(
    String data64,
    List<int> key,
    List<int> iv,
  ) async {
    final bytes = base64Decode(data64);
    final box = SecretBox(
      bytes.sublist(0, bytes.length - 16),
      nonce: iv,
      mac: Mac(bytes.sublist(bytes.length - 16)),
    );
    return utf8.decode(await _gcm.decrypt(box, secretKey: SecretKey(key)));
  }

  /// Legacy AES-256-CBC decrypt (PKCS7) for vault entries written by
  /// older builds. Never used for new data.
  static Future<String> decryptCbc64(
    String data64,
    List<int> key,
    List<int> iv,
  ) async {
    final box = SecretBox(base64Decode(data64), nonce: iv, mac: Mac.empty);
    return utf8.decode(await _cbc.decrypt(box, secretKey: SecretKey(key)));
  }
}
