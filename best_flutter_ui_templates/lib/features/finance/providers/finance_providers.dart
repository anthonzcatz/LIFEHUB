import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_utils.dart';

import '../data/finance_repository.dart';
import '../models/finance_models.dart';

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(),
);

class TransactionsNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void _changed() => state++;

  Future<void> add({
    required TransactionType type,
    required double amount,
    required String category,
    String note = '',
    required DateTime date,
  }) async {
    final transaction = TransactionModel(
      id: newId(),
      type: type,
      amount: amount,
      category: category,
      note: note,
      date: date,
    );
    await ref.read(financeRepositoryProvider).saveTransaction(transaction);
    _changed();
  }

  Future<void> update(TransactionModel transaction) async {
    await ref.read(financeRepositoryProvider).saveTransaction(transaction);
    _changed();
  }

  Future<TransactionModel?> remove(String id) async {
    final deleted = await ref
        .read(financeRepositoryProvider)
        .deleteTransaction(id);
    if (deleted != null) _changed();
    return deleted;
  }

  Future<void> restore(TransactionModel transaction) async {
    await ref.read(financeRepositoryProvider).saveTransaction(transaction);
    _changed();
  }
}

final transactionsProvider = NotifierProvider<TransactionsNotifier, int>(
  TransactionsNotifier.new,
);

typedef TransactionPageRequest = ({
  DateTime? start,
  DateTime? end,
  TransactionType? type,
  String? category,
  String query,
  int limit,
  int offset,
});

final transactionPageProvider =
    FutureProvider.family<TransactionPage, TransactionPageRequest>((
      ref,
      request,
    ) {
      ref.watch(transactionsProvider);
      return ref
          .read(financeRepositoryProvider)
          .queryTransactionsPage(
            start: request.start,
            end: request.end,
            type: request.type,
            category: request.category,
            query: request.query,
            limit: request.limit,
            offset: request.offset,
          );
    });

typedef FinanceReportRequest = ({
  DateTime start,
  DateTime end,
  TransactionType? type,
});

final financeReportProvider =
    FutureProvider.family<FinanceReportSnapshot, FinanceReportRequest>((
      ref,
      request,
    ) {
      ref.watch(transactionsProvider);
      return ref
          .read(financeRepositoryProvider)
          .reportForRangeAsync(
            start: request.start,
            end: request.end,
            type: request.type,
          );
    });

class BudgetsNotifier extends Notifier<List<BudgetModel>> {
  @override
  List<BudgetModel> build() => ref.read(financeRepositoryProvider).getBudgets();

  Future<void> save({
    String? id,
    required String category,
    required double limit,
  }) async {
    final normalizedCategory = category.trim();
    if (state.any(
      (budget) =>
          budget.id != id &&
          budget.category.toLowerCase() == normalizedCategory.toLowerCase(),
    )) {
      throw StateError('A budget already exists for this category.');
    }
    await ref
        .read(financeRepositoryProvider)
        .saveBudget(
          BudgetModel(
            id: id ?? newId(),
            category: normalizedCategory,
            monthlyLimit: limit,
          ),
        );
    state = ref.read(financeRepositoryProvider).getBudgets();
  }

  Future<void> remove(String id) async {
    await ref.read(financeRepositoryProvider).deleteBudget(id);
    state = ref.read(financeRepositoryProvider).getBudgets();
  }
}

final budgetsProvider = NotifierProvider<BudgetsNotifier, List<BudgetModel>>(
  BudgetsNotifier.new,
);

class SavingsNotifier extends Notifier<List<SavingsGoalModel>> {
  @override
  List<SavingsGoalModel> build() =>
      ref.read(financeRepositoryProvider).getSavingsGoals();

  Future<void> add({
    required String name,
    required double target,
    DateTime? deadline,
  }) async {
    await ref
        .read(financeRepositoryProvider)
        .saveSavingsGoal(
          SavingsGoalModel(
            id: newId(),
            name: name,
            targetAmount: target,
            deadline: deadline,
          ),
        );
    state = ref.read(financeRepositoryProvider).getSavingsGoals();
  }

  /// Record a deposit or withdrawal with date, note, and history.
  Future<void> addFunds(
    SavingsGoalModel goal,
    double amount, {
    DateTime? date,
    String note = '',
    bool isWithdrawal = false,
  }) async {
    final repository = ref.read(financeRepositoryProvider);
    final currentGoal = repository
        .getSavingsGoals()
        .where((item) => item.id == goal.id)
        .firstOrNull;
    if (currentGoal == null) throw StateError('Savings goal no longer exists.');
    if (!amount.isFinite ||
        amount <= 0 ||
        !currentGoal.savedAmount.isFinite ||
        currentGoal.savedAmount < 0) {
      throw ArgumentError('Savings amount is invalid.');
    }
    if (isWithdrawal && amount > currentGoal.savedAmount) {
      throw StateError('Cannot withdraw more than the amount saved.');
    }
    final ledgerBalance = currentGoal.deposits.fold(
      0.0,
      (sum, deposit) => sum + deposit.signedAmount,
    );
    if ((ledgerBalance - currentGoal.savedAmount).abs() > 0.005) {
      throw StateError('Savings history and current balance need review.');
    }
    final deposit = SavingsDepositModel(
      id: newId(),
      amount: amount,
      date: date ?? DateTime.now(),
      note: note,
      isWithdrawal: isWithdrawal,
    );
    final newSaved = currentGoal.savedAmount + deposit.signedAmount;
    if (!newSaved.isFinite || newSaved < 0) {
      throw StateError('Savings balance would become invalid.');
    }
    final newDeposits = [deposit, ...currentGoal.deposits];
    await repository.saveSavingsGoal(
      currentGoal.copyWith(savedAmount: newSaved, deposits: newDeposits),
    );
    state = repository.getSavingsGoals();
  }

  /// Remove a history entry and roll back its amount.
  Future<void> removeDeposit(SavingsGoalModel goal, String depositId) async {
    final repository = ref.read(financeRepositoryProvider);
    final currentGoal = repository
        .getSavingsGoals()
        .where((item) => item.id == goal.id)
        .firstOrNull;
    if (currentGoal == null) return;
    final newDeposits = currentGoal.deposits
        .where((deposit) => deposit.id != depositId)
        .toList();
    if (newDeposits.length == currentGoal.deposits.length) return;
    final newSaved = newDeposits.fold(
      0.0,
      (sum, deposit) => sum + deposit.signedAmount,
    );
    if (!newSaved.isFinite || newSaved < 0) {
      throw StateError('Savings history would produce an invalid balance.');
    }
    await repository.saveSavingsGoal(
      currentGoal.copyWith(savedAmount: newSaved, deposits: newDeposits),
    );
    state = repository.getSavingsGoals();
  }

  Future<void> remove(String id) async {
    await ref.read(financeRepositoryProvider).deleteSavingsGoal(id);
    state = ref.read(financeRepositoryProvider).getSavingsGoals();
  }
}

final savingsProvider =
    NotifierProvider<SavingsNotifier, List<SavingsGoalModel>>(
      SavingsNotifier.new,
    );

/// Current-month expense/income totals, recomputed when transactions change.
final monthlyTotalsProvider = Provider<({double income, double expense})>((
  ref,
) {
  ref.watch(transactionsProvider);
  final now = DateTime.now();
  final repository = ref.read(financeRepositoryProvider);
  return (
    income: repository.totalForMonth(
      TransactionType.income,
      now.year,
      now.month,
    ),
    expense: repository.totalForMonth(
      TransactionType.expense,
      now.year,
      now.month,
    ),
  );
});
