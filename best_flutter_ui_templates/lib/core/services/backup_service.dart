import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/id_utils.dart';

import '../../features/finance/data/finance_repository.dart';
import '../../features/finance/models/finance_models.dart';
import '../../features/habits/models/habit.dart';
import '../../features/notes_tasks/models/notes_tasks_models.dart';
import '../../features/vault/models/vault_entry.dart';
import '../constants/app_constants.dart';
import 'aes_cipher.dart';
import 'backup_crypto.dart';
import 'local_db.dart';
import 'notification_service.dart';
import 'platform_actions.dart';
import 'security_service.dart';

class BackupPreview {
  BackupPreview({
    required this.counts,
    required this.encrypted,
    required this.legacyUnencrypted,
    required this.portableVaultKey,
    required this.missingProfilePhoto,
    required this.vaultMayBeUnavailable,
    this.exportedAt,
  });

  final Map<String, int> counts;
  final bool encrypted;
  final bool legacyUnencrypted;
  final bool portableVaultKey;
  final bool missingProfilePhoto;
  final bool vaultMayBeUnavailable;
  final DateTime? exportedAt;

  int get total => counts.values.fold(0, (a, b) => a + b);
  int get vaultCount => counts[AppConstants.vaultBox] ?? 0;
}

class BackupPassphraseRequired implements Exception {
  const BackupPassphraseRequired();
}

class PreparedBackup {
  const PreparedBackup._({
    required this.preview,
    required this.collections,
    required this.settings,
    required this.vaultKey,
    required this.profilePhoto,
  });

  final BackupPreview preview;
  final Map<String, Map<String, dynamic>> collections;
  final Map<String, dynamic> settings;
  final String? vaultKey;
  final Uint8List? profilePhoto;
}

class BackupSource {
  const BackupSource._({
    required this.encoded,
    required this.encrypted,
    required this.decoded,
    required this.exportedAt,
  });

  final String encoded;
  final bool encrypted;
  final Map<String, dynamic> decoded;
  final DateTime? exportedAt;

  bool get requiresPassphrase => encrypted;

  Future<PreparedBackup> prepare({String? passphrase}) async {
    late final Map<String, dynamic> payload;
    if (encrypted) {
      if (passphrase == null || passphrase.isEmpty) {
        throw const BackupPassphraseRequired();
      }
      payload = await BackupCrypto.decryptJson(encoded, passphrase);
    } else {
      payload = decoded;
    }
    return BackupService._preparePayload(
      payload,
      encrypted: encrypted,
      exportedAt: exportedAt,
    );
  }
}

abstract interface class BackupKeyStore {
  Future<String> ensureVaultKey();
  Future<String?> readVaultKey();
  Future<void> writeVaultKey(String? key);
  Future<String> createJournalKey();
  Future<String?> readJournalKey();
  Future<void> clearJournalKey();
}

class _SecurityBackupKeyStore implements BackupKeyStore {
  @override
  Future<String> ensureVaultKey() => SecurityService.vaultKeyForBackup();

  @override
  Future<String?> readVaultKey() => SecurityService.existingVaultKey();

  @override
  Future<void> writeVaultKey(String? key) =>
      SecurityService.restoreVaultKey(key);

  @override
  Future<String> createJournalKey() =>
      SecurityService.createRestoreJournalKey();

  @override
  Future<String?> readJournalKey() => SecurityService.restoreJournalKey();

  @override
  Future<void> clearJournalKey() => SecurityService.clearRestoreJournalKey();
}

class BackupService {
  BackupService._();

  static const _schemaVersion = 1;
  static const _maxBackupBytes = 50 * 1024 * 1024;
  static const _maxProfilePhotoBytes = 4 * 1024 * 1024;
  static const _backupFileName = 'lifehub_backup.json';
  static const _journalFileName = 'lifehub_restore_journal.json.enc';
  static const _deviceLocalSettings = {
    AppConstants.keyPinHash,
    AppConstants.keyPinSalt,
    AppConstants.keyPinFailedAttempts,
    AppConstants.keyPinLockUntil,
    AppConstants.keyBiometricEnabled,
    AppConstants.keyAuthMode,
    AppConstants.keyOnboardingDone,
  };
  static const _userSettings = {
    AppConstants.keyUserName,
    AppConstants.keyUserEmail,
    AppConstants.keyUserPhoto,
    AppConstants.keyUserBio,
    AppConstants.keyCurrency,
    AppConstants.keyHabitReminderEnabled,
    AppConstants.keyHabitReminderTime,
    AppConstants.keyHideAmounts,
    'custom_expense_categories',
    'custom_income_categories',
  };
  static const _dataBoxes = [
    AppConstants.transactionsBox,
    AppConstants.budgetsBox,
    AppConstants.savingsGoalsBox,
    AppConstants.notesBox,
    AppConstants.tasksBox,
    AppConstants.habitsBox,
    AppConstants.habitLogsBox,
    AppConstants.vaultBox,
  ];

  static BackupKeyStore _keyStore = _SecurityBackupKeyStore();
  static Future<Directory> Function() _supportDirectory =
      getApplicationSupportDirectory;

  @visibleForTesting
  static void configureForTesting({
    BackupKeyStore? keyStore,
    Future<Directory> Function()? supportDirectory,
  }) {
    _keyStore = keyStore ?? _SecurityBackupKeyStore();
    _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;
  }

  static Future<File> exportToJson({required String passphrase}) async {
    final payload = await _createPayload();
    final encrypted = await BackupCrypto.encryptJson(payload, passphrase);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_backupFileName');
    if (await file.exists()) await file.delete();
    await file.writeAsBytes(encrypted, flush: true);
    return file;
  }

  static Future<void> shareBackup({required String passphrase}) async {
    final file = await exportToJson(passphrase: passphrase);
    await PlatformActions.shareFile(
      file.path,
      subject: 'LifeHub encrypted backup',
    );
  }

  static Future<void> removeLegacyPlaintextBackup() async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_backupFileName');
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map &&
          decoded['app'] == 'LifeHub' &&
          decoded['version'] == 1) {
        await file.delete();
      }
    } catch (_) {}
  }

  static Future<BackupSource> readBackup(File file) async {
    final size = await file.length();
    if (size <= 0 || size > _maxBackupBytes) {
      throw const FormatException('Backup file is empty or too large.');
    }
    final encoded = await file.readAsString();
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('This is not a LifeHub backup.');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (BackupCrypto.isEncryptedEnvelope(map)) {
      return BackupSource._(
        encoded: encoded,
        encrypted: true,
        decoded: map,
        exportedAt: null,
      );
    }
    if (map['app'] == 'LifeHub' && map['version'] == 1) {
      return BackupSource._(
        encoded: encoded,
        encrypted: false,
        decoded: map,
        exportedAt: DateTime.tryParse(map['exportedAt'] as String? ?? ''),
      );
    }
    throw const FormatException('Unsupported or invalid LifeHub backup.');
  }

  static Future<PreparedBackup> _preparePayload(
    Map<String, dynamic> payload, {
    required bool encrypted,
    required DateTime? exportedAt,
  }) async {
    final schemaVersion = encrypted ? payload['schemaVersion'] : 1;
    if (schemaVersion != _schemaVersion) {
      throw const FormatException('This backup schema is not supported.');
    }
    final rawData = payload['data'];
    final rawSettings = payload['settings'];
    if (rawData is! Map || rawSettings is! Map) {
      throw const FormatException('Backup data is incomplete.');
    }

    final collections = <String, Map<String, dynamic>>{};
    final counts = <String, int>{};
    for (final name in _dataBoxes) {
      final section = rawData[name];
      if (section is! Map) {
        throw FormatException('Missing or invalid "$name" data.');
      }
      final records = _validateCollection(name, section);
      collections[name] = records;
      counts[name] = records.length;
    }

    final settingsResult = _validateSettings(rawSettings);
    final rawAttachments = encrypted ? payload['attachments'] : null;
    if (encrypted && rawAttachments is! Map) {
      throw const FormatException('Backup attachments are invalid.');
    }
    final attachment = rawAttachments is Map
        ? rawAttachments['profilePhoto']
        : null;
    final photoResult = _readProfilePhoto(attachment);
    var missingProfilePhoto =
        photoResult.missing || payload['missingProfilePhoto'] == true;
    if (settingsResult.localPhotoPathFound) missingProfilePhoto = true;

    String? vaultKey;
    var vaultMayBeUnavailable = false;
    if (encrypted) {
      final rawVaultKey = payload['vaultKey'];
      if (rawVaultKey is! String) {
        throw const FormatException(
          'Backup is missing its portable vault key.',
        );
      }
      try {
        final bytes = base64Decode(rawVaultKey);
        if (bytes.length != 32) throw const FormatException();
        vaultKey = rawVaultKey;
        for (final raw in collections[AppConstants.vaultBox]!.values) {
          final entry = VaultEntry.fromMap(raw as Map);
          await SecurityService.verifyVaultCiphertextWithKey(
            entry.encryptedPassword,
            vaultKey,
          );
        }
      } catch (_) {
        throw const FormatException(
          'Vault data could not be verified with this backup key.',
        );
      }
    } else {
      vaultKey = await _keyStore.readVaultKey();
      if (counts[AppConstants.vaultBox]! > 0 && vaultKey == null) {
        vaultMayBeUnavailable = true;
      } else if (vaultKey != null) {
        try {
          for (final raw in collections[AppConstants.vaultBox]!.values) {
            final entry = VaultEntry.fromMap(raw as Map);
            await SecurityService.verifyVaultCiphertextWithKey(
              entry.encryptedPassword,
              vaultKey,
            );
          }
        } catch (_) {
          vaultMayBeUnavailable = true;
        }
      }
    }

    return PreparedBackup._(
      preview: BackupPreview(
        counts: counts,
        encrypted: encrypted,
        legacyUnencrypted: !encrypted,
        portableVaultKey: encrypted,
        missingProfilePhoto: missingProfilePhoto,
        vaultMayBeUnavailable: vaultMayBeUnavailable,
        exportedAt:
            exportedAt ??
            DateTime.tryParse(payload['exportedAt'] as String? ?? ''),
      ),
      collections: collections,
      settings: settingsResult.values,
      vaultKey: vaultKey,
      profilePhoto: photoResult.bytes,
    );
  }

  static Map<String, dynamic> _validateCollection(String name, Map source) {
    final result = <String, dynamic>{};
    for (final entry in source.entries) {
      if (entry.key is! String ||
          (entry.key as String).isEmpty ||
          entry.value is! Map) {
        throw FormatException('Corrupt record in "$name".');
      }
      final id = entry.key as String;
      final map = Map<String, dynamic>.from(entry.value as Map);
      try {
        switch (name) {
          case AppConstants.transactionsBox:
            final model = TransactionModel.fromMap(map);
            if (model.id != id ||
                !model.amount.isFinite ||
                model.amount <= 0 ||
                model.category.trim().isEmpty) {
              throw const FormatException();
            }
            result[id] = model.toMap();
          case AppConstants.budgetsBox:
            final model = BudgetModel.fromMap(map);
            if (model.id != id ||
                !model.monthlyLimit.isFinite ||
                model.monthlyLimit <= 0 ||
                model.category.trim().isEmpty) {
              throw const FormatException();
            }
            result[id] = model.toMap();
          case AppConstants.savingsGoalsBox:
            final model = SavingsGoalModel.fromMap(map);
            if (model.id != id ||
                !model.targetAmount.isFinite ||
                model.targetAmount <= 0 ||
                !model.savedAmount.isFinite ||
                model.savedAmount < 0 ||
                model.deposits.any(
                  (deposit) => !deposit.amount.isFinite || deposit.amount <= 0,
                )) {
              throw const FormatException();
            }
            result[id] = model.toMap();
          case AppConstants.notesBox:
            final model = NoteModel.fromMap(map);
            if (model.id != id) throw const FormatException();
            result[id] = model.toMap();
          case AppConstants.tasksBox:
            final model = TaskModel.fromMap(map);
            if (model.id != id ||
                !AppConstants.taskPriorities.contains(model.priority)) {
              throw const FormatException();
            }
            result[id] = model.toMap();
          case AppConstants.habitsBox:
            final model = HabitModel.fromMap(map);
            if (model.id != id) throw const FormatException();
            result[id] = model.toMap();
          case AppConstants.habitLogsBox:
            if (!_isJsonValue(map)) throw const FormatException();
            result[id] = map;
          case AppConstants.vaultBox:
            final model = VaultEntry.fromMap(map);
            if (model.id != id ||
                !_isVaultCiphertext(model.encryptedPassword)) {
              throw const FormatException();
            }
            result[id] = model.toMap();
          default:
            throw const FormatException();
        }
      } catch (_) {
        throw FormatException('Invalid record "$id" in "$name".');
      }
    }
    return result;
  }

  static ({Map<String, dynamic> values, bool localPhotoPathFound})
  _validateSettings(Map source) {
    final values = <String, dynamic>{};
    var localPhotoPathFound = false;
    for (final entry in source.entries) {
      if (entry.key is! String || _deviceLocalSettings.contains(entry.key)) {
        continue;
      }
      final key = entry.key as String;
      if (!_userSettings.contains(key)) continue;
      final value = entry.value;
      switch (key) {
        case AppConstants.keyUserName:
        case AppConstants.keyUserEmail:
        case AppConstants.keyUserBio:
          if (value is! String) {
            throw FormatException('Invalid setting "$key".');
          }
          values[key] = value;
        case AppConstants.keyUserPhoto:
          if (value is String && value.startsWith('https://')) {
            values[key] = value;
          } else if (value != null) {
            localPhotoPathFound = true;
          }
        case AppConstants.keyCurrency:
          if (value is! String || value.isEmpty || value.length > 3) {
            throw const FormatException('Invalid currency setting.');
          }
          values[key] = value;
        case AppConstants.keyHabitReminderEnabled:
        case AppConstants.keyHideAmounts:
          if (value is! bool) throw FormatException('Invalid setting "$key".');
          values[key] = value;
        case AppConstants.keyHabitReminderTime:
          if (value is! String ||
              !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
            throw const FormatException('Invalid habit reminder time.');
          }
          values[key] = value;
        case 'custom_expense_categories':
        case 'custom_income_categories':
          if (value is! List ||
              value.length > 100 ||
              value.any(
                (item) =>
                    item is! String || item.trim().isEmpty || item.length > 80,
              )) {
            throw FormatException('Invalid category setting "$key".');
          }
          values[key] = List<String>.from(value);
      }
    }
    return (values: values, localPhotoPathFound: localPhotoPathFound);
  }

  static ({Uint8List? bytes, bool missing}) _readProfilePhoto(Object? raw) {
    if (raw == null) return (bytes: null, missing: false);
    if (raw is! Map) {
      throw const FormatException('Profile photo attachment is invalid.');
    }
    final extension = raw['extension'];
    final encoded = raw['data'];
    if (extension is! String ||
        !const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
        encoded is! String) {
      throw const FormatException('Profile photo attachment is invalid.');
    }
    try {
      final bytes = Uint8List.fromList(base64Decode(encoded));
      if (bytes.isEmpty || bytes.length > _maxProfilePhotoBytes) {
        throw const FormatException();
      }
      return (bytes: bytes, missing: false);
    } catch (_) {
      throw const FormatException('Profile photo attachment is damaged.');
    }
  }

  static bool _isVaultCiphertext(String stored) {
    if (stored.isEmpty) return true;
    final parts = stored.split(':');
    if (parts.length == 3 && parts[0] == 'gcm') {
      try {
        return base64Decode(parts[1]).length == 12 &&
            base64Decode(parts[2]).length >= 16;
      } catch (_) {
        return false;
      }
    }
    if (parts.length == 2) {
      try {
        return base64Decode(parts[0]).length == 16 &&
            base64Decode(parts[1]).isNotEmpty;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  static bool _isJsonValue(Object? value) {
    if (value == null || value is String || value is bool || value is num) {
      return value is! double || value.isFinite;
    }
    if (value is List) return value.every(_isJsonValue);
    if (value is Map) {
      return value.entries.every(
        (entry) => entry.key is String && _isJsonValue(entry.value),
      );
    }
    return false;
  }

  static Future<Map<String, dynamic>> _createPayload() async {
    final settings = Map<String, dynamic>.from(LocalDb.settings.toMap())
      ..removeWhere(
        (key, value) =>
            _deviceLocalSettings.contains(key) || !_userSettings.contains(key),
      );
    final attachments = <String, dynamic>{};
    var missingProfilePhoto = false;
    final photoPath = settings[AppConstants.keyUserPhoto];
    if (photoPath is String && !photoPath.startsWith('https://')) {
      settings.remove(AppConstants.keyUserPhoto);
      final photo = File(photoPath);
      if (await photo.exists() &&
          await photo.length() <= _maxProfilePhotoBytes) {
        final filename = photo.uri.pathSegments.last;
        final extension = filename.contains('.')
            ? filename.split('.').last.toLowerCase()
            : 'jpg';
        if (const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
          attachments['profilePhoto'] = {
            'extension': extension,
            'data': base64Encode(await photo.readAsBytes()),
          };
        } else {
          missingProfilePhoto = true;
        }
      } else {
        missingProfilePhoto = true;
      }
    }

    return {
      'schemaVersion': _schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'data': {
        for (final name in _dataBoxes)
          name: {
            for (final entry in LocalDb.box(name).toMap().entries)
              entry.key.toString(): entry.value,
          },
      },
      'vaultKey': await _keyStore.ensureVaultKey(),
      'attachments': attachments,
      'missingProfilePhoto': missingProfilePhoto,
    };
  }

  static Future<BackupPreview> applyBackup(PreparedBackup prepared) async {
    final before = await _captureSnapshot();
    final rollbackFile = await _writeJournal(before);
    File? restoredPhoto;
    try {
      final settings = Map<String, dynamic>.from(prepared.settings);
      if (prepared.profilePhoto != null) {
        final dir = await _supportDirectory();
        final extension = _profilePhotoExtension(prepared.profilePhoto!);
        restoredPhoto = File(
          '${dir.path}${Platform.pathSeparator}lifehub_profile_restore_${newId()}.$extension',
        );
        await restoredPhoto.writeAsBytes(prepared.profilePhoto!, flush: true);
        settings[AppConstants.keyUserPhoto] = restoredPhoto.path;
      }

      await NotificationService.cancelAll();
      for (final name in _dataBoxes) {
        final box = LocalDb.box(name);
        await box.clear();
        await box.putAll(prepared.collections[name]!);
      }
      await FinanceRepository.rebuildTransactionIndex();

      final preservedSettings = <String, dynamic>{
        for (final entry in (before['settings'] as Map).entries)
          if (_deviceLocalSettings.contains(entry.key))
            entry.key.toString(): entry.value,
      };
      await LocalDb.settings.clear();
      await LocalDb.settings.putAll({...preservedSettings, ...settings});
      await _keyStore.writeVaultKey(
        prepared.vaultKey ?? before['vaultKey'] as String?,
      );
      await _rescheduleReminders();
      await _commitJournal(rollbackFile);
      return prepared.preview;
    } catch (_) {
      try {
        await _restoreSnapshot(before);
        await _commitJournal(rollbackFile);
      } catch (_) {
        if (restoredPhoto != null && await restoredPhoto.exists()) {
          await restoredPhoto.delete();
        }
        throw StateError(
          'Restore failed and recovery is pending. Restart LifeHub to recover the previous data.',
        );
      }
      if (restoredPhoto != null && await restoredPhoto.exists()) {
        await restoredPhoto.delete();
      }
      await NotificationService.cancelAll();
      await _rescheduleReminders();
      rethrow;
    }
  }

  static Future<bool> recoverInterruptedRestore() async {
    final journal = await _journalFile();
    final key = await _keyStore.readJournalKey();
    if (!await journal.exists()) {
      if (key != null) await _keyStore.clearJournalKey();
      return false;
    }
    if (key == null) {
      throw StateError(
        'Restore recovery key is missing; data was not modified.',
      );
    }
    final encoded = jsonDecode(await journal.readAsString());
    if (encoded is! Map ||
        encoded['iv'] is! String ||
        encoded['ciphertext'] is! String) {
      throw const FormatException('Restore recovery journal is damaged.');
    }
    final snapshotJson = await AesCipher.decryptGcm64(
      encoded['ciphertext'] as String,
      base64Decode(key),
      base64Decode(encoded['iv'] as String),
    );
    final snapshot = jsonDecode(snapshotJson);
    if (snapshot is! Map<String, dynamic>) {
      throw const FormatException('Restore recovery data is damaged.');
    }
    await _restoreSnapshot(snapshot);
    await _commitJournal(journal);
    return true;
  }

  static Future<Map<String, dynamic>> _captureSnapshot() async => {
    'boxes': {
      for (final name in _dataBoxes)
        name: {
          for (final entry in LocalDb.box(name).toMap().entries)
            entry.key.toString(): entry.value,
        },
    },
    'settings': LocalDb.settings.toMap(),
    'vaultKey': await _keyStore.readVaultKey(),
  };

  static Future<File> _writeJournal(Map<String, dynamic> snapshot) async {
    final dir = await _supportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_journalFileName');
    final key = await _keyStore.createJournalKey();
    final iv = AesCipher.randomIv();
    final data = await AesCipher.encryptGcm64(
      utf8.encode(jsonEncode(snapshot)),
      base64Decode(key),
      iv,
    );
    await file.writeAsString(
      jsonEncode({'iv': base64Encode(iv), 'ciphertext': data}),
      flush: true,
    );
    return file;
  }

  static Future<void> _restoreSnapshot(Map snapshot) async {
    final boxes = snapshot['boxes'];
    if (boxes is! Map) {
      throw const FormatException('Restore journal is damaged.');
    }
    for (final name in _dataBoxes) {
      final box = LocalDb.box(name);
      final records = boxes[name];
      if (records is! Map) {
        throw FormatException('Restore journal is missing "$name".');
      }
      await box.clear();
      await box.putAll(Map<dynamic, dynamic>.from(records));
    }
    await FinanceRepository.rebuildTransactionIndex();
    final settings = snapshot['settings'];
    if (settings is! Map) {
      throw const FormatException('Restore journal settings are damaged.');
    }
    await LocalDb.settings.clear();
    await LocalDb.settings.putAll(Map<dynamic, dynamic>.from(settings));
    await _keyStore.writeVaultKey(snapshot['vaultKey'] as String?);
  }

  static Future<void> _commitJournal(File file) async {
    if (await file.exists()) await file.delete();
    await _keyStore.clearJournalKey();
  }

  static Future<File> _journalFile() async {
    final dir = await _supportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_journalFileName');
  }

  static String _profilePhotoExtension(Uint8List bytes) {
    if (bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length > 12 &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    return 'jpg';
  }

  static Future<void> _rescheduleReminders() async {
    for (final raw in LocalDb.box(AppConstants.tasksBox).values) {
      if (raw is! Map || raw['isDone'] == true) continue;
      final reminderAt = raw['reminderAt'];
      if (reminderAt is! int) continue;
      final when = DateTime.fromMillisecondsSinceEpoch(reminderAt);
      if (!when.isAfter(DateTime.now())) continue;
      await NotificationService.scheduleReminder(
        id: 'task_${raw['id']}',
        title: 'Task Reminder',
        body: 'You have a task due.',
        when: when,
      );
    }

    final settings = LocalDb.settings;
    if (settings.get(AppConstants.keyHabitReminderEnabled) == true) {
      final parts =
          ((settings.get(AppConstants.keyHabitReminderTime) as String?) ??
                  '08:00')
              .split(':');
      await NotificationService.scheduleDailyReminder(
        id: 'habit_daily_reminder',
        title: 'Habit Reminder',
        body: "Time to check today's habits!",
        hour: int.tryParse(parts[0]) ?? 8,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
      );
    }
  }

  static Future<void> clearAllData() async {
    final photoPath = LocalDb.settings.get(AppConstants.keyUserPhoto);
    if (photoPath is String && !photoPath.startsWith('https://')) {
      final photo = File(photoPath);
      if (await photo.exists()) {
        await photo.delete();
      }
    }
    for (final name in _dataBoxes) {
      await LocalDb.box(name).clear();
    }
    await LocalDb.box(AppConstants.transactionIndexBox).clear();
    await LocalDb.settings.clear();
    await SecurityService.clearVaultKey();
    await NotificationService.cancelAll();
    final tempDir = await getTemporaryDirectory();
    final backup = File(
      '${tempDir.path}${Platform.pathSeparator}$_backupFileName',
    );
    if (await backup.exists()) {
      await backup.delete();
    }
    final journal = await _journalFile();
    if (await journal.exists()) await journal.delete();
    await _keyStore.clearJournalKey();
  }
}
