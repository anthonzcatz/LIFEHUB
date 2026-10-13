import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:lifehub/core/services/aes_cipher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lifehub/core/constants/app_constants.dart';
import 'package:lifehub/core/services/backup_crypto.dart';
import 'package:lifehub/core/services/backup_service.dart';
import 'package:lifehub/core/services/local_db.dart';
import 'package:lifehub/core/services/security_service.dart';
import 'package:lifehub/features/finance/models/finance_models.dart';
import 'package:lifehub/features/vault/models/vault_entry.dart';

const _passphrase = 'correct horse battery staple';
final _backupVaultKey = base64Encode(List<int>.generate(32, (i) => i + 1));
final _oldVaultKey = base64Encode(List<int>.generate(32, (i) => 255 - i));

class _FakeBackupKeyStore implements BackupKeyStore {
  String? vaultKey;
  String? journalKey;
  final failVaultWrites = <String?>{};

  @override
  Future<String> ensureVaultKey() async => vaultKey ??= _backupVaultKey;

  @override
  Future<String?> readVaultKey() async => vaultKey;

  @override
  Future<void> writeVaultKey(String? key) async {
    if (failVaultWrites.remove(key)) {
      throw StateError('simulated secure storage failure');
    }
    vaultKey = key;
  }

  @override
  Future<String> createJournalKey() async =>
      journalKey = base64Encode(List<int>.generate(32, (i) => i + 100));

  @override
  Future<String?> readJournalKey() async => journalKey;

  @override
  Future<void> clearJournalKey() async => journalKey = null;
}

void main() {
  late Directory root;
  late Directory supportDirectory;
  late File backupFile;
  late _FakeBackupKeyStore keyStore;
  late Uint8List encryptedBytes;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('lifehub_backup_test');
    supportDirectory = Directory(
      '${root.path}${Platform.pathSeparator}support',
    );
    await supportDirectory.create();
    Hive.init('${root.path}${Platform.pathSeparator}hive');
    for (final name in [
      AppConstants.settingsBox,
      AppConstants.transactionsBox,
      AppConstants.transactionIndexBox,
      AppConstants.budgetsBox,
      AppConstants.savingsGoalsBox,
      AppConstants.notesBox,
      AppConstants.tasksBox,
      AppConstants.habitsBox,
      AppConstants.habitLogsBox,
      AppConstants.vaultBox,
    ]) {
      await Hive.openBox(name);
    }
    encryptedBytes = await BackupCrypto.encryptJson(
      await _payload(),
      _passphrase,
    );
  });

  setUp(() async {
    for (final name in [
      AppConstants.transactionsBox,
      AppConstants.transactionIndexBox,
      AppConstants.budgetsBox,
      AppConstants.savingsGoalsBox,
      AppConstants.notesBox,
      AppConstants.tasksBox,
      AppConstants.habitsBox,
      AppConstants.habitLogsBox,
      AppConstants.vaultBox,
    ]) {
      await LocalDb.box(name).clear();
    }
    await LocalDb.settings.clear();
    keyStore = _FakeBackupKeyStore();
    BackupService.configureForTesting(
      keyStore: keyStore,
      supportDirectory: () async => supportDirectory,
    );
    backupFile = File('${root.path}${Platform.pathSeparator}input.json');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('encrypted portable backup restores data and vault key', () async {
    await backupFile.writeAsBytes(encryptedBytes);
    await LocalDb.settings.put(AppConstants.keyAuthMode, 'pin');
    await LocalDb.settings.put(AppConstants.keyPinHash, 'device-local-hash');

    final source = await BackupService.readBackup(backupFile);
    expect(source.requiresPassphrase, isTrue);
    final prepared = await source.prepare(passphrase: _passphrase);
    expect(prepared.preview.encrypted, isTrue);
    expect(prepared.preview.portableVaultKey, isTrue);
    expect(prepared.preview.vaultMayBeUnavailable, isFalse);

    await BackupService.applyBackup(prepared);

    expect(keyStore.vaultKey, _backupVaultKey);
    expect(LocalDb.settings.get(AppConstants.keyAuthMode), 'pin');
    expect(LocalDb.settings.get(AppConstants.keyPinHash), 'device-local-hash');
    expect(LocalDb.settings.get(AppConstants.keyCurrency), '€');
    expect(LocalDb.box(AppConstants.transactionsBox).get('income'), isNotNull);
    final rawVault = LocalDb.box(AppConstants.vaultBox).get('email') as Map;
    final entry = VaultEntry.fromMap(rawVault);
    await SecurityService.verifyVaultCiphertextWithKey(
      entry.encryptedPassword,
      keyStore.vaultKey!,
    );
  });

  test('restore failure rolls every Hive box and the vault key back', () async {
    keyStore.vaultKey = _oldVaultKey;
    await LocalDb.settings.put(AppConstants.keyAuthMode, 'pin');
    await LocalDb.settings.put(AppConstants.keyCurrency, r'$');
    await LocalDb.box(AppConstants.transactionsBox).put(
      'old',
      TransactionModel(
        id: 'old',
        type: TransactionType.expense,
        amount: 10,
        category: 'Food',
        date: DateTime(2026, 1, 1),
      ).toMap(),
    );
    keyStore.failVaultWrites.add(_backupVaultKey);
    await backupFile.writeAsBytes(encryptedBytes);
    final prepared = await (await BackupService.readBackup(
      backupFile,
    )).prepare(passphrase: _passphrase);

    await expectLater(
      BackupService.applyBackup(prepared),
      throwsA(isA<StateError>()),
    );

    expect(LocalDb.box(AppConstants.transactionsBox).get('old'), isNotNull);
    expect(LocalDb.box(AppConstants.transactionsBox).get('income'), isNull);
    expect(LocalDb.settings.get(AppConstants.keyCurrency), r'$');
    expect(keyStore.vaultKey, _oldVaultKey);
    expect(await keyStore.readJournalKey(), isNull);
  });

  test(
    'pending restore journal recovers after rollback storage failure',
    () async {
      keyStore.vaultKey = _oldVaultKey;
      await LocalDb.settings.put(AppConstants.keyCurrency, r'$');
      await LocalDb.box(AppConstants.transactionsBox).put(
        'old',
        TransactionModel(
          id: 'old',
          type: TransactionType.expense,
          amount: 10,
          category: 'Food',
          date: DateTime(2026, 1, 1),
        ).toMap(),
      );
      keyStore.failVaultWrites.addAll([_backupVaultKey, _oldVaultKey]);
      await backupFile.writeAsBytes(encryptedBytes);
      final prepared = await (await BackupService.readBackup(
        backupFile,
      )).prepare(passphrase: _passphrase);

      await expectLater(
        BackupService.applyBackup(prepared),
        throwsA(isA<StateError>()),
      );
      expect(await keyStore.readJournalKey(), isNotNull);

      expect(await BackupService.recoverInterruptedRestore(), isTrue);

      expect(LocalDb.box(AppConstants.transactionsBox).get('old'), isNotNull);
      expect(LocalDb.box(AppConstants.transactionsBox).get('income'), isNull);
      expect(LocalDb.settings.get(AppConstants.keyCurrency), r'$');
      expect(keyStore.vaultKey, _oldVaultKey);
      expect(await keyStore.readJournalKey(), isNull);
    },
  );

  test(
    'pending restore journal recovers after rollback storage failure',
    () async {
      keyStore.vaultKey = _oldVaultKey;
      await LocalDb.settings.put(AppConstants.keyCurrency, r'$');
      await LocalDb.box(AppConstants.transactionsBox).put(
        'old',
        TransactionModel(
          id: 'old',
          type: TransactionType.expense,
          amount: 10,
          category: 'Food',
          date: DateTime(2026, 1, 1),
        ).toMap(),
      );
      keyStore.failVaultWrites.addAll([_backupVaultKey, _oldVaultKey]);
      await backupFile.writeAsBytes(encryptedBytes);
      final prepared = await (await BackupService.readBackup(
        backupFile,
      )).prepare(passphrase: _passphrase);

      await expectLater(
        BackupService.applyBackup(prepared),
        throwsA(isA<StateError>()),
      );
      expect(await keyStore.readJournalKey(), isNotNull);

      expect(await BackupService.recoverInterruptedRestore(), isTrue);

      expect(LocalDb.box(AppConstants.transactionsBox).get('old'), isNotNull);
      expect(LocalDb.box(AppConstants.transactionsBox).get('income'), isNull);
      expect(LocalDb.settings.get(AppConstants.keyCurrency), r'$');
      expect(keyStore.vaultKey, _oldVaultKey);
      expect(await keyStore.readJournalKey(), isNull);
    },
  );

  test('wrong passphrase is rejected before applying any data', () async {
    await backupFile.writeAsBytes(encryptedBytes);
    await LocalDb.box(AppConstants.transactionsBox).put('keep', {'id': 'keep'});
    final source = await BackupService.readBackup(backupFile);

    await expectLater(
      source.prepare(passphrase: 'wrong passphrase'),
      throwsA(isA<BackupCryptoException>()),
    );

    expect(LocalDb.box(AppConstants.transactionsBox).get('keep'), isNotNull);
  });

  test('tampered encrypted backup is rejected', () async {
    final envelope = jsonDecode(utf8.decode(encryptedBytes)) as Map;
    final cipher = Map<String, dynamic>.from(envelope['cipher'] as Map);
    final encodedCiphertext = cipher['ciphertext'] as String;
    cipher['ciphertext'] =
        '${encodedCiphertext[0] == 'A' ? 'B' : 'A'}${encodedCiphertext.substring(1)}';
    envelope['cipher'] = cipher;
    await backupFile.writeAsString(jsonEncode(envelope));

    final source = await BackupService.readBackup(backupFile);
    await expectLater(
      source.prepare(passphrase: _passphrase),
      throwsA(isA<BackupCryptoException>()),
    );
  });

  test(
    'invalid records are rejected before live collections are changed',
    () async {
      final invalid = await _payload();
      final transactions = Map<String, dynamic>.from(
        (invalid['data'] as Map)[AppConstants.transactionsBox] as Map,
      );
      final record = Map<String, dynamic>.from(transactions['income'] as Map)
        ..['amount'] = -5;
      transactions['income'] = record;
      (invalid['data'] as Map)[AppConstants.transactionsBox] = transactions;
      final bytes = await BackupCrypto.encryptJson(invalid, _passphrase);
      await backupFile.writeAsBytes(bytes);
      await LocalDb.box(
        AppConstants.transactionsBox,
      ).put('keep', {'id': 'keep'});

      final source = await BackupService.readBackup(backupFile);
      await expectLater(
        source.prepare(passphrase: _passphrase),
        throwsA(isA<FormatException>()),
      );

      expect(LocalDb.box(AppConstants.transactionsBox).get('keep'), isNotNull);
    },
  );

  test(
    'legacy plaintext backup is marked and lacks portable vault key',
    () async {
      final legacy = {
        'app': 'LifeHub',
        'version': 1,
        'exportedAt': DateTime(2026, 1, 1).toIso8601String(),
        'settings': {AppConstants.keyCurrency: '₱'},
        'data': (await _payload())['data'],
      };
      await backupFile.writeAsString(jsonEncode(legacy));

      final source = await BackupService.readBackup(backupFile);
      final prepared = await source.prepare();

      expect(prepared.preview.legacyUnencrypted, isTrue);
      expect(prepared.preview.portableVaultKey, isFalse);
      expect(prepared.preview.vaultMayBeUnavailable, isTrue);
    },
  );
}

Future<Map<String, dynamic>> _payload() async {
  const vaultId = 'email';
  final key = base64Decode(_backupVaultKey);
  final iv = AesCipher.randomIv();
  final encryptedPassword = await AesCipher.encryptGcm64(
    utf8.encode('secret-value'),
    key,
    iv,
  );
  final transaction = TransactionModel(
    id: 'income',
    type: TransactionType.income,
    amount: 1250.5,
    category: 'Salary',
    date: DateTime(2026, 1, 2),
  );
  final vault = VaultEntry(
    id: vaultId,
    title: 'Email',
    encryptedPassword: 'gcm:${base64Encode(iv)}:$encryptedPassword',
    updatedAt: DateTime(2026, 1, 2),
  );
  return {
    'schemaVersion': 1,
    'exportedAt': DateTime(2026, 1, 3).toIso8601String(),
    'settings': {AppConstants.keyCurrency: '€'},
    'data': {
      AppConstants.transactionsBox: {'income': transaction.toMap()},
      AppConstants.budgetsBox: <String, dynamic>{},
      AppConstants.savingsGoalsBox: <String, dynamic>{},
      AppConstants.notesBox: <String, dynamic>{},
      AppConstants.tasksBox: <String, dynamic>{},
      AppConstants.habitsBox: <String, dynamic>{},
      AppConstants.habitLogsBox: <String, dynamic>{},
      AppConstants.vaultBox: {vaultId: vault.toMap()},
    },
    'vaultKey': _backupVaultKey,
    'attachments': <String, dynamic>{},
  };
}
