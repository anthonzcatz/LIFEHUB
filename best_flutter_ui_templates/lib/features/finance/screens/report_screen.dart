import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/providers/privacy_providers.dart';
import '../../../core/services/platform_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../data/finance_report_pdf.dart';
import '../data/finance_repository.dart';
import '../models/finance_models.dart';
import '../providers/finance_providers.dart';

enum ReportTypeFilter { all, income, expenses }

enum ReportRange { week, month, quarter, year, custom }

/// Filterable report — pie chart of spending by category + income vs
/// expense bar + breakdown list, over a selectable date range.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const _allCategories = 'All categories';
  static const _maxBreakdownItems = 8;
  static const _palette = [
    Color(0xFFFA7D34),
    Color(0xFF00B6F0),
    Color(0xFF7B61FF),
    Color(0xFF00B686),
    Color(0xFFF0A500),
    Color(0xFFE91E63),
    Color(0xFF607D8B),
    Color(0xFF8D6E63),
  ];

  DateTime _anchor = DateTime.now();
  ReportRange _range = ReportRange.month;
  DateTimeRange? _customRange;
  ReportTypeFilter _type = ReportTypeFilter.all;
  String? _category;
  bool _exporting = false;

  DateTimeRange get _monthRange => DateTimeRange(
    start: DateTime(_anchor.year, _anchor.month),
    end: DateTime(_anchor.year, _anchor.month + 1, 0, 23, 59, 59),
  );

  DateTimeRange get _activeRange {
    switch (_range) {
      case ReportRange.month:
        return _monthRange;
      case ReportRange.week:
        final monday = DateTime(
          _anchor.year,
          _anchor.month,
          _anchor.day,
        ).subtract(Duration(days: _anchor.weekday - 1));
        return DateTimeRange(
          start: monday,
          end: monday.add(
            const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
          ),
        );
      case ReportRange.quarter:
        final firstMonth = ((_anchor.month - 1) ~/ 3) * 3 + 1;
        return DateTimeRange(
          start: DateTime(_anchor.year, firstMonth),
          end: DateTime(_anchor.year, firstMonth + 3, 0, 23, 59, 59),
        );
      case ReportRange.year:
        return DateTimeRange(
          start: DateTime(_anchor.year),
          end: DateTime(_anchor.year, 12, 31, 23, 59, 59),
        );
      case ReportRange.custom:
        return _customRange ?? _monthRange;
    }
  }

  bool get _isDefaultView {
    final now = DateTime.now();
    return _range == ReportRange.month &&
        _anchor.year == now.year &&
        _anchor.month == now.month;
  }

  bool get _hasActiveFilter =>
      !_isDefaultView || _type != ReportTypeFilter.all || _category != null;

  String get _rangeLabel {
    final r = _activeRange;
    switch (_range) {
      case ReportRange.month:
        return Formatters.monthYear(_anchor);
      case ReportRange.week:
      case ReportRange.custom:
        return '${Formatters.shortDate(r.start)} – ${Formatters.date(r.end)}';
      case ReportRange.quarter:
        return 'Q${((_anchor.month - 1) ~/ 3) + 1} ${_anchor.year}';
      case ReportRange.year:
        return '${_anchor.year}';
    }
  }

  String _rangeName(ReportRange r) => switch (r) {
    ReportRange.week => 'Week',
    ReportRange.month => 'Month',
    ReportRange.quarter => 'Quarter',
    ReportRange.year => 'Year',
    ReportRange.custom => 'Custom',
  };

  void _shift(int dir) {
    setState(() {
      switch (_range) {
        case ReportRange.month:
          _anchor = DateTime(_anchor.year, _anchor.month + dir);
        case ReportRange.week:
          _anchor = _anchor.add(Duration(days: 7 * dir));
        case ReportRange.quarter:
          _anchor = DateTime(_anchor.year, _anchor.month + 3 * dir);
        case ReportRange.year:
          _anchor = DateTime(_anchor.year + dir);
        case ReportRange.custom:
          final r = _customRange;
          if (r != null) {
            final span = r.end.difference(r.start).inDays + 1;
            _customRange = DateTimeRange(
              start: r.start.add(Duration(days: span * dir)),
              end: r.end.add(Duration(days: span * dir)),
            );
          }
      }
      _category = null;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    if (_range == ReportRange.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: now,
        initialDateRange: _customRange,
        helpText: 'Choose report range',
      );
      if (picked != null) {
        setState(() {
          _customRange = DateTimeRange(
            start: DateTime(
              picked.start.year,
              picked.start.month,
              picked.start.day,
            ),
            end: DateTime(
              picked.end.year,
              picked.end.month,
              picked.end.day,
              23,
              59,
              59,
            ),
          );
          _category = null;
        });
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor.isAfter(now) ? now : _anchor,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'Choose a date inside the ${_rangeName(_range).toLowerCase()}',
    );
    if (picked != null) {
      setState(() {
        _anchor = picked;
        _category = null;
      });
    }
  }

  Future<void> _selectRange(ReportRange r) async {
    if (r == ReportRange.custom && _customRange == null) {
      await _pickRange();
      if (_customRange == null) return;
    }
    setState(() {
      _range = r;
      _category = null;
    });
  }

  void _clearFilters() {
    setState(() {
      _anchor = DateTime.now();
      _range = ReportRange.month;
      _customRange = null;
      _type = ReportTypeFilter.all;
      _category = null;
    });
  }

  /// Exports the currently filtered report as a formatted PDF and opens
  /// the share sheet so it can go to Gmail, Messenger, Drive, etc.
  Future<void> _exportPdf(
    FinanceReportSnapshot report,
    TransactionType? selectedType,
    String? activeCategory,
    Map<String, double> byCategory,
    TransactionType? breakdownType,
    FinanceReportTotals aggregate,
  ) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final repository = ref.read(financeRepositoryProvider);
      final range = _activeRange;
      final transactions = <TransactionModel>[];
      var offset = 0;
      // Page through the matching transactions; bounded so a huge
      // history can't stall the UI — the PDF table caps itself anyway.
      while (transactions.length < 600) {
        final page = await repository.queryTransactionsPage(
          start: range.start,
          end: range.end,
          type: selectedType,
          category: activeCategory,
          limit: 200,
          offset: offset,
        );
        transactions.addAll(page.items);
        if (!page.hasMore || page.items.isEmpty) break;
        offset += page.items.length;
      }
      final path = await FinanceReportPdf.writeToCache(
        rangeLabel: _rangeLabel,
        totals: aggregate,
        breakdown: byCategory,
        breakdownType: breakdownType,
        transactions: transactions,
        totalMatching: aggregate.matchingCount,
        currencySymbol: Formatters.currencySymbol,
      );
      await PlatformActions.shareFile(
        path,
        mimeType: 'application/pdf',
        subject: 'LifeHub financial report — $_rangeLabel',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export the PDF report')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<MapEntry<String, double>> _visibleBreakdown(
    List<MapEntry<String, double>> sorted,
  ) {
    if (sorted.length <= _maxBreakdownItems) return sorted;
    final visibleCount = _maxBreakdownItems - 1;
    final otherTotal = sorted
        .skip(visibleCount)
        .fold(0.0, (sum, entry) => sum + entry.value);
    return [
      ...sorted.take(visibleCount),
      MapEntry('Other categories', otherTotal),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hideAmounts = ref.watch(hideAmountsProvider);
    final range = _activeRange;
    final selectedType = switch (_type) {
      ReportTypeFilter.all => null,
      ReportTypeFilter.income => TransactionType.income,
      ReportTypeFilter.expenses => TransactionType.expense,
    };
    final reportState = ref.watch(
      financeReportProvider((
        start: range.start,
        end: range.end,
        type: selectedType,
      )),
    );
    final report = reportState.asData?.value;
    final availableCategories = report?.categories.toList() ?? <String>[]
      ..sort();
    final activeCategory = availableCategories.contains(_category)
        ? _category
        : null;
    final aggregate = activeCategory == null
        ? report?.overall
        : report?.byCategory[activeCategory];
    final income = aggregate?.income ?? 0;
    final expenseTotal = aggregate?.expense ?? 0;
    final breakdownType = _type == ReportTypeFilter.all
        ? TransactionType.expense
        : selectedType;
    final breakdownTotal = breakdownType == TransactionType.income
        ? aggregate?.income ?? 0
        : aggregate?.expense ?? 0;
    final byCategory = breakdownType == TransactionType.income
        ? aggregate?.incomeByCategory ?? const <String, double>{}
        : aggregate?.expenseByCategory ?? const <String, double>{};
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visibleBreakdown = _visibleBreakdown(sorted);
    final chartMax = income > expenseTotal ? income : expenseTotal;
    final breakdownTitle = _type == ReportTypeFilter.income
        ? 'Income by Category'
        : 'Expenses by Category';

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: Text('Report — $_rangeLabel'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export PDF report',
            onPressed: report == null || _exporting
                ? null
                : () => _exportPdf(
                    report,
                    selectedType,
                    activeCategory,
                    byCategory,
                    breakdownType,
                    aggregate!,
                  ),
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          if (_hasActiveFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Container(
            decoration: LifeHubTheme.cardDecoration,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous ${_rangeName(_range).toLowerCase()}',
                      onPressed: () => _shift(-1),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          _rangeLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next ${_rangeName(_range).toLowerCase()}',
                      onPressed: _activeRange.end.isBefore(DateTime.now())
                          ? () => _shift(1)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final r in ReportRange.values)
                      ChoiceChip(
                        label: Text(_rangeName(r)),
                        selected: _range == r,
                        onSelected: (_) => _selectRange(r),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<ReportTypeFilter>(
                  segments: const [
                    ButtonSegment(
                      value: ReportTypeFilter.all,
                      label: Text('All'),
                    ),
                    ButtonSegment(
                      value: ReportTypeFilter.income,
                      label: Text('Income'),
                    ),
                    ButtonSegment(
                      value: ReportTypeFilter.expenses,
                      label: Text('Expenses'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) => setState(() {
                    _type = value.first;
                    _category = null;
                  }),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: LifeHubTheme.lightText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reportState.when(
                          data: (_) =>
                              '${aggregate?.matchingCount ?? 0} matching transaction${aggregate?.matchingCount == 1 ? '' : 's'} • aggregated view',
                          loading: () => 'Calculating report…',
                          error: (_, _) => 'Could not calculate report',
                        ),
                        style: LifeHubTheme.caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Income vs expense bar
          FadeSlideIn.item(
            index: 0,
            child: Container(
              decoration: LifeHubTheme.cardDecoration,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Income vs Expense', style: LifeHubTheme.title),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: report == null
                        ? Center(
                            child: reportState.hasError
                                ? const Text('Could not calculate report.')
                                : const CircularProgressIndicator(),
                          )
                        : hideAmounts
                        ? const Center(
                            child: Text(
                              'Chart hidden while amounts are hidden',
                            ),
                          )
                        : BarChart(
                            BarChartData(
                              maxY: chartMax == 0 ? 1 : chartMax * 1.2,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(),
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) => Text(
                                      v == 0 ? 'Income' : 'Expense',
                                      style: LifeHubTheme.caption,
                                    ),
                                  ),
                                ),
                              ),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: income,
                                      color: LifeHubTheme.finance,
                                      width: 48,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: expenseTotal,
                                      color: LifeHubTheme.tasks,
                                      width: 48,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Expense breakdown pie
          FadeSlideIn.item(
            index: 1,
            child: Container(
              decoration: LifeHubTheme.cardDecoration,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(breakdownTitle, style: LifeHubTheme.title),
                  const SizedBox(height: 16),
                  if (report == null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          reportState.hasError
                              ? 'Could not calculate report.'
                              : 'Calculating report…',
                        ),
                      ),
                    )
                  else if (hideAmounts)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Chart hidden while amounts are hidden'),
                      ),
                    )
                  else if (visibleBreakdown.isEmpty || breakdownTotal <= 0)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('No matching data for these filters'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            for (var i = 0; i < visibleBreakdown.length; i++)
                              PieChartSectionData(
                                value: visibleBreakdown[i].value,
                                color: _palette[i % _palette.length],
                                title:
                                    '${(visibleBreakdown[i].value / breakdownTotal * 100).toStringAsFixed(0)}%',
                                radius: 60,
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown list
          FadeSlideIn.item(
            index: 2,
            child: Container(
              decoration: LifeHubTheme.cardDecoration,
              child: Column(
                children: [
                  if (report == null)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        reportState.hasError
                            ? 'Could not calculate report.'
                            : 'Calculating report…',
                      ),
                    )
                  else
                    for (var i = 0; i < visibleBreakdown.length; i++)
                      ListTile(
                        leading: CircleAvatar(
                          radius: 8,
                          backgroundColor: _palette[i % _palette.length],
                        ),
                        title: Text(visibleBreakdown[i].key),
                        trailing: Text(
                          Formatters.money(visibleBreakdown[i].value),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                  if (report != null && sorted.length > _maxBreakdownItems)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Text(
                        'Showing the largest categories; the remainder is grouped under Other categories.',
                        style: LifeHubTheme.caption,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
