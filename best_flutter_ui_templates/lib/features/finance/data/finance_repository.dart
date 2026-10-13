import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_db.dart';
import '../../../core/utils/formatters.dart';
import '../models/finance_models.dart';

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.matchingCount,
    required this.categories,
    required this.hasMore,
  });

  final List<TransactionModel> items;
  final int matchingCount;
  final Set<String> categories;
  final bool hasMore;
}

class FinanceReportTotals {
  const FinanceReportTotals({
    required this.income,
    required this.expense,
    required this.matchingCount,
    required this.incomeByCategory,
    required this.expenseByCategory,
  });

  final double income;
  final double expense;
  final int matchingCount;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expenseByCategory;
}

class FinanceReportSnapshot {
  const FinanceReportSnapshot({
    required this.categories,
    required this.overall,
    required this.byCategory,
  });

  final Set<String> categories;
  final FinanceReportTotals overall;
  final Map<String, FinanceReportTotals> byCategory;
}

class _ReportTotalsBuilder {
  double income = 0;
  double expense = 0;
  int matchingCount = 0;
  final incomeByCategory = <String, double>{};
  final expenseByCategory = <String, double>{};

  void add(TransactionModel transaction) {
    matchingCount++;
    if (transaction.type == TransactionType.income) {
      income += transaction.amount;
      incomeByCategory[transaction.category] =
          (incomeByCategory[transaction.category] ?? 0) + transaction.amount;
    } else {
      expense += transaction.amount;
      expenseByCategory[transaction.category] =
          (expenseByCategory[transaction.category] ?? 0) + transaction.amount;
    }
  }

  FinanceReportTotals build() => FinanceReportTotals(
    income: income,
    expense: expense,
    matchingCount: matchingCount,
    incomeByCategory: Map.unmodifiable(incomeByCategory),
    expenseByCategory: Map.unmodifiable(expenseByCategory),
  );
}

class FinanceRepository {
  static const _indexVersionKey = '__index_version';
  static const _indexDirtyKey = '__index_dirty';
  static const _indexVersion = 1;

  // ---------- Transactions ----------

  int get transactionCount => LocalDb.box(AppConstants.transactionsBox).length;

  List<TransactionModel> getTransactions() {
    return LocalDb.box(
        AppConstants.transactionsBox,
      ).values.map((m) => TransactionModel.fromMap(m as Map)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> ensureTransactionIndex() async {
    final index = LocalDb.box(AppConstants.transactionIndexBox);
    if (index.get(_indexVersionKey) == _indexVersion &&
        index.get(_indexDirtyKey) != true) {
      return;
    }
    await rebuildTransactionIndex();
  }

  static Future<void> rebuildTransactionIndex() async {
    final index = LocalDb.box(AppConstants.transactionIndexBox);
    final transactions = LocalDb.box(AppConstants.transactionsBox);
    await index.clear();
    await index.put(_indexDirtyKey, true);
    final byDay = <String, List<({String id, int date})>>{};
    for (final entry in transactions.toMap().entries) {
      final raw = entry.value;
      if (raw is! Map || raw['date'] is! num) continue;
      final date = (raw['date'] as num).toInt();
      final day = Formatters.dayKey(DateTime.fromMillisecondsSinceEpoch(date));
      byDay.putIfAbsent(day, () => []).add((
        id: entry.key.toString(),
        date: date,
      ));
    }
    final updates = <String, dynamic>{_indexVersionKey: _indexVersion};
    for (final entry in byDay.entries) {
      entry.value.sort((a, b) => b.date.compareTo(a.date));
      updates[entry.key] = entry.value.map((item) => item.id).toList();
    }
    await index.putAll(updates);
    await index.delete(_indexDirtyKey);
  }

  Future<void> saveTransaction(TransactionModel transaction) async {
    _validateTransaction(transaction);
    await ensureTransactionIndex();
    final index = LocalDb.box(AppConstants.transactionIndexBox);
    final transactions = LocalDb.box(AppConstants.transactionsBox);
    final previous = transactions.get(transaction.id) as Map?;
    await index.put(_indexDirtyKey, true);
    await transactions.put(transaction.id, transaction.toMap());
    if (previous != null && previous['date'] is num) {
      await _removeFromDayIndex(
        index,
        Formatters.dayKey(
          DateTime.fromMillisecondsSinceEpoch(
            (previous['date'] as num).toInt(),
          ),
        ),
        transaction.id,
      );
    }
    await _addToDayIndex(index, transactions, transaction);
    await index.delete(_indexDirtyKey);
  }

  Future<TransactionModel?> deleteTransaction(String id) async {
    await ensureTransactionIndex();
    final index = LocalDb.box(AppConstants.transactionIndexBox);
    final transactions = LocalDb.box(AppConstants.transactionsBox);
    final raw = transactions.get(id) as Map?;
    if (raw == null) return null;
    final transaction = TransactionModel.fromMap(raw);
    await index.put(_indexDirtyKey, true);
    await transactions.delete(id);
    await _removeFromDayIndex(index, Formatters.dayKey(transaction.date), id);
    await index.delete(_indexDirtyKey);
    return transaction;
  }

  TransactionPage queryTransactions({
    DateTime? start,
    DateTime? end,
    TransactionType? type,
    String? category,
    String query = '',
    int limit = 100,
    int offset = 0,
    bool countTotal = true,
  }) {
    if (limit < 0 || offset < 0) {
      throw ArgumentError('Pagination limit and offset must be non-negative.');
    }
    final normalizedQuery = query.trim().toLowerCase();
    final items = <TransactionModel>[];
    final categories = <String>{};
    var matchingCount = 0;
    for (final transaction in _iterateTransactions(start: start, end: end)) {
      if (type != null && transaction.type != type) continue;
      categories.add(transaction.category);
      if (category != null && transaction.category != category) continue;
      if (normalizedQuery.isNotEmpty &&
          !'${transaction.category} ${transaction.note}'.toLowerCase().contains(
            normalizedQuery,
          )) {
        continue;
      }
      if (matchingCount >= offset && items.length < limit) {
        items.add(transaction);
      }
      matchingCount++;
      if (!countTotal && items.length >= limit) break;
    }
    return TransactionPage(
      items: items,
      matchingCount: matchingCount,
      categories: categories,
      hasMore: matchingCount > offset + items.length,
    );
  }

  Future<TransactionPage> queryTransactionsPage({
    DateTime? start,
    DateTime? end,
    TransactionType? type,
    String? category,
    String query = '',
    int limit = 100,
    int offset = 0,
  }) async {
    if (limit <= 0 || offset < 0) {
      throw ArgumentError(
        'Page limit must be positive and offset non-negative.',
      );
    }
    final normalizedQuery = query.trim().toLowerCase();
    final items = <TransactionModel>[];
    final categories = <String>{};
    var matchingCount = 0;
    var scanned = 0;
    var hasMore = false;
    for (final transaction in _iterateTransactions(start: start, end: end)) {
      scanned++;
      if (type == null || transaction.type == type) {
        categories.add(transaction.category);
        final categoryMatches =
            category == null || transaction.category == category;
        final queryMatches =
            normalizedQuery.isEmpty ||
            '${transaction.category} ${transaction.note}'
                .toLowerCase()
                .contains(normalizedQuery);
        if (categoryMatches && queryMatches) {
          if (matchingCount >= offset && items.length < limit) {
            items.add(transaction);
          } else if (matchingCount >= offset) {
            hasMore = true;
            break;
          }
          matchingCount++;
        }
      }
      if (scanned % 512 == 0) await Future<void>.delayed(Duration.zero);
    }
    return TransactionPage(
      items: items,
      matchingCount: matchingCount,
      categories: categories,
      hasMore: hasMore,
    );
  }

  List<TransactionModel> transactionsForMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return _iterateTransactions(start: start, end: end).toList();
  }

  double totalForMonth(TransactionType type, int year, int month) {
    var total = 0.0;
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    for (final transaction in _iterateTransactions(start: start, end: end)) {
      if (transaction.type == type) total += transaction.amount;
    }
    return total;
  }

  Map<String, double> spentByCategoryForMonth(int year, int month) {
    final totals = <String, double>{};
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    for (final transaction in _iterateTransactions(start: start, end: end)) {
      if (transaction.type == TransactionType.expense) {
        totals[transaction.category] =
            (totals[transaction.category] ?? 0) + transaction.amount;
      }
    }
    return totals;
  }

  double spentForCategory(String category, int year, int month) =>
      spentByCategoryForMonth(year, month)[category] ?? 0;

  Future<FinanceReportSnapshot> reportForRangeAsync({
    required DateTime start,
    required DateTime end,
    TransactionType? type,
  }) async {
    final overall = _ReportTotalsBuilder();
    final byCategory = <String, _ReportTotalsBuilder>{};
    var scanned = 0;
    for (final transaction in _iterateTransactions(start: start, end: end)) {
      scanned++;
      if (type == null || transaction.type == type) {
        overall.add(transaction);
        byCategory
            .putIfAbsent(transaction.category, _ReportTotalsBuilder.new)
            .add(transaction);
      }
      if (scanned % 512 == 0) await Future<void>.delayed(Duration.zero);
    }
    return FinanceReportSnapshot(
      categories: byCategory.keys.toSet(),
      overall: overall.build(),
      byCategory: {
        for (final entry in byCategory.entries) entry.key: entry.value.build(),
      },
    );
  }

  List<TransactionModel> recentTransactions({
    TransactionType? type,
    int limit = 5,
  }) => queryTransactions(type: type, limit: limit, countTotal: false).items;

  Future<void> _addToDayIndex(
    dynamic index,
    dynamic transactions,
    TransactionModel transaction,
  ) async {
    final day = Formatters.dayKey(transaction.date);
    final ids = List<String>.from(index.get(day, defaultValue: <String>[]))
      ..remove(transaction.id)
      ..add(transaction.id);
    ids.sort((a, b) {
      final aRaw = transactions.get(a) as Map?;
      final bRaw = transactions.get(b) as Map?;
      final aDate = (aRaw?['date'] as num?)?.toInt() ?? 0;
      final bDate = (bRaw?['date'] as num?)?.toInt() ?? 0;
      return bDate.compareTo(aDate);
    });
    await index.put(day, ids);
  }

  Future<void> _removeFromDayIndex(dynamic index, String day, String id) async {
    final ids = List<String>.from(index.get(day, defaultValue: <String>[]))
      ..remove(id);
    if (ids.isEmpty) {
      await index.delete(day);
    } else {
      await index.put(day, ids);
    }
  }

  Iterable<TransactionModel> _iterateTransactions({
    DateTime? start,
    DateTime? end,
  }) sync* {
    final box = LocalDb.box(AppConstants.transactionsBox);
    final index = LocalDb.box(AppConstants.transactionIndexBox);
    final indexed =
        index.get(_indexVersionKey) == _indexVersion &&
        index.get(_indexDirtyKey) != true;
    if (!indexed) {
      final entries = box.toMap().entries.toList()
        ..sort((a, b) {
          final aDate = ((a.value as Map)['date'] as num?)?.toInt() ?? 0;
          final bDate = ((b.value as Map)['date'] as num?)?.toInt() ?? 0;
          return bDate.compareTo(aDate);
        });
      for (final entry in entries) {
        final transaction = TransactionModel.fromMap(entry.value as Map);
        if (_withinRange(transaction.date, start, end)) yield transaction;
      }
      return;
    }

    final firstDay = start == null ? null : Formatters.dayKey(start);
    final lastDay = end == null ? null : Formatters.dayKey(end);
    final days =
        index.keys
            .whereType<String>()
            .where(
              (day) =>
                  day != _indexVersionKey &&
                  day != _indexDirtyKey &&
                  (firstDay == null || day.compareTo(firstDay) >= 0) &&
                  (lastDay == null || day.compareTo(lastDay) <= 0),
            )
            .toList()
          ..sort((a, b) => b.compareTo(a));
    final seen = <String>{};
    for (final day in days) {
      final ids = index.get(day);
      if (ids is! List) continue;
      for (final id in ids.cast<String>()) {
        if (!seen.add(id)) continue;
        final raw = box.get(id);
        if (raw is! Map) continue;
        final transaction = TransactionModel.fromMap(raw);
        if (_withinRange(transaction.date, start, end)) yield transaction;
      }
    }
  }

  static bool _withinRange(DateTime value, DateTime? start, DateTime? end) =>
      (start == null || !value.isBefore(start)) &&
      (end == null || value.isBefore(end));

  static void _validateTransaction(TransactionModel transaction) {
    if (!transaction.amount.isFinite ||
        transaction.amount <= 0 ||
        transaction.category.trim().isEmpty) {
      throw ArgumentError('Transaction amount and category are invalid.');
    }
  }

  // ---------- Budgets ----------

  List<BudgetModel> getBudgets() => LocalDb.box(
    AppConstants.budgetsBox,
  ).values.map((m) => BudgetModel.fromMap(m as Map)).toList();

  Future<void> saveBudget(BudgetModel budget) {
    if (!budget.monthlyLimit.isFinite ||
        budget.monthlyLimit <= 0 ||
        budget.category.trim().isEmpty) {
      throw ArgumentError('Budget limit and category are invalid.');
    }
    return LocalDb.box(AppConstants.budgetsBox).put(budget.id, budget.toMap());
  }

  Future<void> deleteBudget(String id) =>
      LocalDb.box(AppConstants.budgetsBox).delete(id);

  // ---------- Savings goals ----------

  List<SavingsGoalModel> getSavingsGoals() => LocalDb.box(
    AppConstants.savingsGoalsBox,
  ).values.map((m) => SavingsGoalModel.fromMap(m as Map)).toList();

  Future<void> saveSavingsGoal(SavingsGoalModel goal) {
    if (!goal.targetAmount.isFinite ||
        goal.targetAmount <= 0 ||
        !goal.savedAmount.isFinite ||
        goal.savedAmount < 0 ||
        goal.name.trim().isEmpty ||
        goal.deposits.any(
          (deposit) => !deposit.amount.isFinite || deposit.amount <= 0,
        )) {
      throw ArgumentError('Savings goal data is invalid.');
    }
    return LocalDb.box(AppConstants.savingsGoalsBox).put(goal.id, goal.toMap());
  }

  Future<void> deleteSavingsGoal(String id) =>
      LocalDb.box(AppConstants.savingsGoalsBox).delete(id);
}
