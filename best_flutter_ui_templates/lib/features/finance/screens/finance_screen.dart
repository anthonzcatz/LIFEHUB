import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/providers/privacy_providers.dart';
import '../../../core/services/category_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../models/finance_models.dart';
import '../providers/finance_providers.dart';
import 'add_transaction_sheet.dart';
import 'budget_screen.dart';
import 'report_screen.dart';
import 'savings_screen.dart';

enum FinanceListTypeFilter { all, income, expenses }

enum _DateFilter { thisWeek, thisMonth, thisYear, day, range, allTime }

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  static const _allCategories = 'All categories';
  static const _maxDisplayedTransactions = 100;

  String _query = '';
  String? _category;
  FinanceListTypeFilter _type = FinanceListTypeFilter.all;
  _DateFilter _dateFilter = _DateFilter.thisMonth;
  DateTime? _specificDay;
  DateTimeRange? _customRange;

  bool get _hasActiveFilter =>
      _query.trim().isNotEmpty ||
      _dateFilter != _DateFilter.thisMonth ||
      _type != FinanceListTypeFilter.all ||
      _category != null;

  void _clearFilters() {
    setState(() {
      _query = '';
      _category = null;
      _type = FinanceListTypeFilter.all;
      _dateFilter = _DateFilter.thisMonth;
      _specificDay = null;
      _customRange = null;
    });
  }

  Future<void> _pickSpecificDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDay ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Filter transactions on this day',
    );
    if (picked == null) return;
    setState(() {
      _specificDay = picked;
      _dateFilter = _DateFilter.day;
      _category = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _customRange,
      helpText: 'Filter transactions by date range',
    );
    if (picked == null) return;
    setState(() {
      _customRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
      _dateFilter = _DateFilter.range;
      _category = null;
    });
  }

  TransactionType? get _selectedType => switch (_type) {
    FinanceListTypeFilter.all => null,
    FinanceListTypeFilter.income => TransactionType.income,
    FinanceListTypeFilter.expenses => TransactionType.expense,
  };

  @override
  Widget build(BuildContext context) {
    ref.watch(hideAmountsProvider);
    final repository = ref.read(financeRepositoryProvider);
    final totals = ref.watch(monthlyTotalsProvider);
    final goals = ref.watch(savingsProvider);
    final now = DateTime.now();
    final (DateTime? start, DateTime? end) = switch (_dateFilter) {
      _DateFilter.thisWeek => (
        DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1)),
        DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1))
            .add(const Duration(days: 7)),
      ),
      _DateFilter.thisMonth => (
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ),
      _DateFilter.day =>
        _specificDay == null
            ? (null, null)
            : (
                DateTime(
                  _specificDay!.year,
                  _specificDay!.month,
                  _specificDay!.day,
                ),
                DateTime(
                  _specificDay!.year,
                  _specificDay!.month,
                  _specificDay!.day + 1,
                ),
              ),
      _DateFilter.range => (
        _customRange?.start,
        _customRange?.end.add(const Duration(days: 1)),
      ),
      _DateFilter.thisYear => (DateTime(now.year), DateTime(now.year + 1)),
      _DateFilter.allTime => (null, null),
    };
    final selectedType = _selectedType;
    final availableCategories = switch (_type) {
      FinanceListTypeFilter.income => CategoryService.incomeCategories(),
      FinanceListTypeFilter.expenses => CategoryService.expenseCategories(),
      FinanceListTypeFilter.all => {
        ...CategoryService.incomeCategories(),
        ...CategoryService.expenseCategories(),
      }.toList()..sort(),
    };
    final activeCategory = availableCategories.contains(_category)
        ? _category
        : null;
    final pageAsync = ref.watch(
      transactionPageProvider((
        start: start,
        end: end,
        type: selectedType,
        category: activeCategory,
        query: _query,
        limit: _maxDisplayedTransactions,
        offset: 0,
      )),
    );

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Finance'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Monthly report',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.savings_outlined),
            tooltip: 'Savings goals',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Budgets',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LifeHubTheme.finance,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add', style: TextStyle(color: Colors.white)),
        onPressed: () => showAddTransactionSheet(context),
      ),
      body: Column(
        children: [
          // Month summary header
          FadeSlideIn.item(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: LifeHubTheme.cardDecoration,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      Formatters.monthYear(DateTime.now()),
                      style: LifeHubTheme.subtitle,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryTile(
                          label: 'Income',
                          amount: totals.income,
                          color: LifeHubTheme.finance,
                          icon: Icons.arrow_downward,
                        ),
                        _SummaryTile(
                          label: 'Expense',
                          amount: totals.expense,
                          color: LifeHubTheme.tasks,
                          icon: Icons.arrow_upward,
                        ),
                        _SummaryTile(
                          label: 'Balance',
                          amount: totals.income - totals.expense,
                          color: LifeHubTheme.nearlyDarkBlue,
                          icon: Icons.account_balance_wallet,
                        ),
                      ],
                    ),
                    if (goals.isNotEmpty) ...[
                      const Divider(height: 24),
                      Row(
                        children: [
                          const Icon(
                            Icons.savings,
                            size: 18,
                            color: LifeHubTheme.finance,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Savings: ${Formatters.money(goals.fold(0.0, (s, g) => s + g.savedAmount))} of ${Formatters.money(goals.fold(0.0, (s, g) => s + g.targetAmount))}',
                              style: LifeHubTheme.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: 'Search category or note',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _query = ''),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('This week'),
                        selected: _dateFilter == _DateFilter.thisWeek,
                        onSelected: (selected) => setState(() {
                          _dateFilter = selected
                              ? _DateFilter.thisWeek
                              : _DateFilter.allTime;
                          _category = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('This month'),
                        selected: _dateFilter == _DateFilter.thisMonth,
                        onSelected: (selected) => setState(() {
                          _dateFilter = selected
                              ? _DateFilter.thisMonth
                              : _DateFilter.allTime;
                          _category = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('This year'),
                        selected: _dateFilter == _DateFilter.thisYear,
                        onSelected: (selected) => setState(() {
                          _dateFilter = selected
                              ? _DateFilter.thisYear
                              : _DateFilter.allTime;
                          _category = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          _dateFilter == _DateFilter.day && _specificDay != null
                              ? Formatters.shortDate(_specificDay!)
                              : 'Day',
                        ),
                        selected: _dateFilter == _DateFilter.day,
                        onSelected: (_) => _pickSpecificDay(),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          _dateFilter == _DateFilter.range &&
                                  _customRange != null
                              ? '${Formatters.shortDate(_customRange!.start)} – ${Formatters.shortDate(_customRange!.end)}'
                              : 'Range',
                        ),
                        selected: _dateFilter == _DateFilter.range,
                        onSelected: (_) => _pickCustomRange(),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All time'),
                        selected: _dateFilter == _DateFilter.allTime,
                        onSelected: (_) => setState(() {
                          _dateFilter = _DateFilter.allTime;
                          _category = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _type == FinanceListTypeFilter.all,
                        onSelected: (_) => setState(() {
                          _type = FinanceListTypeFilter.all;
                          _category = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Income'),
                        selected: _type == FinanceListTypeFilter.income,
                        onSelected: (_) => setState(() {
                          _type = FinanceListTypeFilter.income;
                          _category = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Expenses'),
                        selected: _type == FinanceListTypeFilter.expenses,
                        onSelected: (_) => setState(() {
                          _type = FinanceListTypeFilter.expenses;
                          _category = null;
                        }),
                      ),
                    ],
                  ),
                ),
                if (availableCategories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: activeCategory ?? _allCategories,
                    decoration: const InputDecoration(
                      labelText: 'Category filter',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: _allCategories,
                        child: Text(_allCategories),
                      ),
                      ...availableCategories.map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(
                      () => _category = value == _allCategories ? null : value,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pageAsync.when(
                          data: (page) =>
                              '${page.matchingCount}${page.hasMore ? '+' : ''} matching transaction${page.matchingCount == 1 && !page.hasMore ? '' : 's'}',
                          loading: () => 'Loading transactions…',
                          error: (_, _) => 'Could not load transactions',
                        ),
                        style: LifeHubTheme.caption,
                      ),
                    ),
                    if (_hasActiveFilter)
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: repository.transactionCount == 0
                ? const EmptyState(
                    message:
                        'No transactions yet.\nTap "Add" to log your first expense or income.',
                    icon: Icons.payments_outlined,
                  )
                : pageAsync.when(
                    data: (page) {
                      if (page.items.isEmpty) {
                        return const EmptyState(
                          message: 'No transactions match these filters.',
                          icon: Icons.filter_alt_off_outlined,
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: page.items.length + (page.hasMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= page.items.length) {
                            return const Padding(
                              padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                              child: Text(
                                'Showing the first 100 matching transactions. Refine the filters to view a smaller result set.',
                                textAlign: TextAlign.center,
                                style: LifeHubTheme.caption,
                              ),
                            );
                          }
                          final t = page.items[i];
                          final isExpense = t.type == TransactionType.expense;
                          return FadeSlideIn.item(
                            index: i + 1,
                            child: Dismissible(
                              key: Key(t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: LifeHubTheme.dismissibleBackground,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) async {
                                final messenger = ScaffoldMessenger.of(context);
                                final notifier = ref.read(
                                  transactionsProvider.notifier,
                                );
                                final removed = await notifier.remove(t.id);
                                if (removed == null) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text('Transaction deleted.'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () =>
                                          notifier.restore(removed),
                                    ),
                                  ),
                                );
                              },
                              child: ListTile(
                                onTap: () => showAddTransactionSheet(
                                  context,
                                  transaction: t,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      (isExpense
                                              ? LifeHubTheme.tasks
                                              : LifeHubTheme.finance)
                                          .withValues(alpha: 0.12),
                                  child: Icon(
                                    CategoryService.iconFor(t.category),
                                    color: isExpense
                                        ? LifeHubTheme.tasks
                                        : LifeHubTheme.finance,
                                    size: 20,
                                  ),
                                ),
                                title: Text(t.category),
                                subtitle: Text(
                                  '${Formatters.date(t.date)}${t.note.isNotEmpty ? ' • ${t.note}' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  '${isExpense ? '-' : '+'}${Formatters.money(t.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isExpense
                                        ? LifeHubTheme.tasks
                                        : LifeHubTheme.finance,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const EmptyState(
                      message: 'Could not load transactions. Try again.',
                      icon: Icons.error_outline,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: LifeHubTheme.caption),
        Text(
          Formatters.money(amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
