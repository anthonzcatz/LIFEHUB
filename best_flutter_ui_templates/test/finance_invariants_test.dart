import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lifehub/core/constants/app_constants.dart';
import 'package:lifehub/core/services/local_db.dart';
import 'package:lifehub/features/finance/data/finance_repository.dart';
import 'package:lifehub/features/finance/models/finance_models.dart';
import 'package:lifehub/features/finance/providers/finance_providers.dart';

void main() {
  late Directory directory;
  late ProviderContainer container;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('lifehub_finance_test');
    Hive.init(directory.path);
    for (final name in [
      AppConstants.settingsBox,
      AppConstants.transactionsBox,
      AppConstants.transactionIndexBox,
      AppConstants.budgetsBox,
      AppConstants.savingsGoalsBox,
    ]) {
      await Hive.openBox(name);
    }
  });

  setUp(() async {
    await LocalDb.box(AppConstants.transactionsBox).clear();
    await LocalDb.box(AppConstants.transactionIndexBox).clear();
    await LocalDb.box(AppConstants.budgetsBox).clear();
    await LocalDb.box(AppConstants.savingsGoalsBox).clear();
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  tearDownAll(() async {
    await Hive.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('repository benchmark covers 100000 transactions', () async {
    final records = <String, Map<String, dynamic>>{};
    final start = DateTime(2020);
    for (var i = 0; i < 100000; i++) {
      final transaction = TransactionModel(
        id: 'bench_$i',
        type: TransactionType.expense,
        amount: 1 + (i % 100),
        category: 'Food',
        date: start.add(Duration(minutes: i)),
      );
      records[transaction.id] = transaction.toMap();
    }
    await LocalDb.box(AppConstants.transactionsBox).putAll(records);
    final repository = FinanceRepository();

    final indexTimer = Stopwatch()..start();
    await FinanceRepository.rebuildTransactionIndex();
    indexTimer.stop();
    final end = start.add(const Duration(minutes: 100001));
    final pageTimer = Stopwatch()..start();
    final page = await repository.queryTransactionsPage(
      start: start,
      end: end,
      limit: 100,
    );
    pageTimer.stop();
    final aggregateTimer = Stopwatch()..start();
    final aggregate = await repository.reportForRangeAsync(
      start: start,
      end: end,
    );
    aggregateTimer.stop();
    debugPrint(
      '100k Hive records: index ${indexTimer.elapsedMilliseconds} ms, first page ${pageTimer.elapsedMilliseconds} ms, aggregate ${aggregateTimer.elapsedMilliseconds} ms.',
    );
    expect(page.items, hasLength(100));
    expect(aggregate.overall.matchingCount, 100000);
  });

  test('repository rejects non-finite or non-positive finance values', () {
    final repository = FinanceRepository();
    expect(
      () => repository.saveTransaction(
        TransactionModel(
          id: 'bad',
          type: TransactionType.expense,
          amount: double.nan,
          category: 'Food',
          date: DateTime(2026),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.saveBudget(
        BudgetModel(id: 'bad', category: 'Food', monthlyLimit: double.infinity),
      ),
      throwsArgumentError,
    );
    expect(
      () => repository.saveSavingsGoal(
        SavingsGoalModel(id: 'bad', name: 'Goal', targetAmount: 0),
      ),
      throwsArgumentError,
    );
  });

  test('transactions can be edited, deleted, and restored for undo', () async {
    final original = TransactionModel(
      id: 'tx',
      type: TransactionType.expense,
      amount: 12,
      category: 'Food',
      date: DateTime(2026, 2, 1),
    );
    await LocalDb.box(AppConstants.transactionsBox).put('tx', original.toMap());
    container.read(transactionsProvider);
    final notifier = container.read(transactionsProvider.notifier);
    final repository = container.read(financeRepositoryProvider);

    final edited = TransactionModel(
      id: 'tx',
      type: TransactionType.expense,
      amount: 18,
      category: 'Food',
      note: 'Updated note',
      date: DateTime(2026, 2, 2),
    );
    await notifier.update(edited);
    expect(repository.getTransactions().single.amount, 18);
    expect(repository.getTransactions().single.note, 'Updated note');
    expect(
      repository
          .queryTransactions(start: DateTime(2026, 2), end: DateTime(2026, 3))
          .items
          .single
          .id,
      'tx',
    );

    final removed = await notifier.remove('tx');
    expect(removed?.amount, edited.amount);
    expect(removed?.note, edited.note);
    expect(repository.getTransactions(), isEmpty);
    await notifier.restore(removed!);
    expect(repository.getTransactions().single.id, 'tx');
  });

  test(
    'savings withdrawals cannot overdraw and ledger matches balance',
    () async {
      final goal = SavingsGoalModel(
        id: 'goal',
        name: 'Emergency fund',
        targetAmount: 200,
        savedAmount: 40,
        deposits: [
          SavingsDepositModel(
            id: 'seed',
            amount: 40,
            date: DateTime(2026, 1, 1),
          ),
        ],
      );
      await LocalDb.box(
        AppConstants.savingsGoalsBox,
      ).put(goal.id, goal.toMap());
      container.read(savingsProvider);
      final notifier = container.read(savingsProvider.notifier);

      await expectLater(
        notifier.addFunds(goal, 41, isWithdrawal: true),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        notifier.addFunds(goal, double.infinity),
        throwsArgumentError,
      );
      expect(
        SavingsGoalModel.fromMap(
          LocalDb.box(AppConstants.savingsGoalsBox).get('goal') as Map,
        ).savedAmount,
        40,
      );

      await notifier.addFunds(goal, 15);
      final updated = SavingsGoalModel.fromMap(
        LocalDb.box(AppConstants.savingsGoalsBox).get('goal') as Map,
      );
      expect(updated.savedAmount, 55);
      expect(
        updated.deposits.fold(
          0.0,
          (sum, deposit) => sum + deposit.signedAmount,
        ),
        updated.savedAmount,
      );
    },
  );
}
