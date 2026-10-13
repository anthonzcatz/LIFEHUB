import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:lifehub/core/constants/app_constants.dart';
import 'package:lifehub/core/services/local_db.dart';
import 'package:lifehub/core/services/security_service.dart';
import 'package:lifehub/core/utils/formatters.dart';
import 'package:lifehub/features/finance/models/finance_models.dart';
import 'package:lifehub/features/habits/models/habit.dart';
import 'package:lifehub/features/notes_tasks/models/notes_tasks_models.dart';
import 'package:lifehub/features/vault/widgets/password_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  test('PIN survives async persistence and verifies after reload', () async {
    final dir = await Directory.systemTemp.createTemp('lifehub_pin_test');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.settingsBox);

    await SecurityService.setPin('4826');
    expect(SecurityService.hasPin, isTrue);
    expect(await SecurityService.verifyPin('4826'), isTrue);
    expect(await SecurityService.verifyPin('4827'), isFalse);

    final settings = LocalDb.settings;
    expect(settings.get(AppConstants.keyPinHash), startsWith('argon2id:v1:'));
    expect(settings.get(AppConstants.keyPinSalt), isNull);

    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('legacy PIN hash migrates and lockout survives Hive reopen', () async {
    final dir = await Directory.systemTemp.createTemp('lifehub_pin_migration');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.settingsBox);
    final salt = 'legacy-salt';
    await LocalDb.settings.put(AppConstants.keyPinSalt, salt);
    await LocalDb.settings.put(
      AppConstants.keyPinHash,
      (await Sha256().hash(
        utf8.encode('$salt::4826'),
      )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );

    expect(await SecurityService.verifyPin('4826'), isTrue);
    expect(
      LocalDb.settings.get(AppConstants.keyPinHash),
      startsWith('argon2id:v1:'),
    );
    expect(LocalDb.settings.get(AppConstants.keyPinSalt), isNull);

    for (var i = 0; i < 4; i++) {
      expect(
        (await SecurityService.verifyPinAttempt('0000')).status,
        PinAttemptStatus.rejected,
      );
    }
    final fifthAttempt = await SecurityService.verifyPinAttempt('0000');
    expect(fifthAttempt.status, PinAttemptStatus.locked);
    expect(fifthAttempt.retryAfter, isNotNull);

    await Hive.close();
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.settingsBox);
    expect(await SecurityService.pinLockoutRemaining(), isNotNull);
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('Model map round-trips', () {
    test('TransactionModel', () {
      final t = TransactionModel(
        id: 'a',
        type: TransactionType.expense,
        amount: 99.5,
        category: 'Food',
        note: 'lunch',
        date: DateTime(2026, 9, 7),
      );
      final back = TransactionModel.fromMap(t.toMap());
      expect(back.id, t.id);
      expect(back.type, TransactionType.expense);
      expect(back.amount, 99.5);
      expect(back.category, 'Food');
      expect(back.date, DateTime(2026, 9, 7));
    });

    test('TaskModel', () {
      final t = TaskModel(
        id: 'x',
        title: 'Do it',
        priority: 'High',
        dueDate: DateTime(2026, 9, 8),
        createdAt: DateTime(2026, 9, 7),
      );
      final back = TaskModel.fromMap(t.toMap());
      expect(back.title, 'Do it');
      expect(back.priority, 'High');
      expect(back.isDone, false);
      expect(back.copyWith(isDone: true).isDone, true);
    });

    test('HabitModel', () {
      final h = HabitModel(
        id: 'h',
        name: 'Read',
        createdAt: DateTime(2026, 9, 1),
        completedDays: ['2026-09-01'],
      );
      final back = HabitModel.fromMap(h.toMap());
      expect(back.completedDays, ['2026-09-01']);
      expect(back.name, 'Read');
    });
  });

  group('Habit streak', () {
    test('counts consecutive days ending today', () {
      final now = DateTime.now();
      final days = List.generate(
        5,
        (i) => _dayKey(now.subtract(Duration(days: i))),
      );
      final h = HabitModel(
        id: 'h',
        name: 'x',
        createdAt: now,
        completedDays: days,
      );
      expect(h.streak, 5);
      expect(h.isDoneToday, true);
    });

    test('streak keeps yesterday chain when today not done', () {
      final now = DateTime.now();
      final days = [
        _dayKey(now.subtract(const Duration(days: 1))),
        _dayKey(now.subtract(const Duration(days: 2))),
      ];
      final h = HabitModel(
        id: 'h',
        name: 'x',
        createdAt: now,
        completedDays: days,
      );
      expect(h.streak, 2);
      expect(h.isDoneToday, false);
    });

    test('streak is 0 with a gap', () {
      final now = DateTime.now();
      final h = HabitModel(
        id: 'h',
        name: 'x',
        createdAt: now,
        completedDays: [_dayKey(now.subtract(const Duration(days: 3)))],
      );
      expect(h.streak, 0);
    });
  });

  group('PasswordGenerator', () {
    test('generates requested length', () {
      expect(PasswordGenerator.generate(length: 24).length, 24);
    });

    test('respects character pools', () {
      final p = PasswordGenerator.generate(
        length: 64,
        upper: false,
        lower: false,
        symbols: false,
      );
      expect(RegExp(r'^[0-9]+$').hasMatch(p), true);
    });

    test('produces different passwords', () {
      expect(PasswordGenerator.generate(), isNot(PasswordGenerator.generate()));
    });
  });

  group('Formatters', () {
    test('dayKey pads correctly', () {
      expect(Formatters.dayKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });
}
