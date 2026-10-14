import 'package:lifehub/features/finance/data/finance_report_pdf.dart';
import 'package:lifehub/features/finance/data/finance_repository.dart';
import 'package:lifehub/features/finance/models/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FinanceReportTotals totals() => const FinanceReportTotals(
    income: 50000,
    expense: 12345.50,
    matchingCount: 3,
    incomeByCategory: {'Salary': 50000},
    expenseByCategory: {'Food': 8000, 'Transport': 4345.50},
  );

  List<TransactionModel> transactions() => [
    TransactionModel(
      id: 't1',
      type: TransactionType.income,
      amount: 50000,
      category: 'Salary',
      note: 'Monthly pay',
      date: DateTime(2025, 1, 15),
    ),
    TransactionModel(
      id: 't2',
      type: TransactionType.expense,
      amount: 8000,
      category: 'Food',
      note: 'Groceries ₱ test',
      date: DateTime(2025, 1, 18),
    ),
    TransactionModel(
      id: 't3',
      type: TransactionType.expense,
      amount: 4345.50,
      category: 'Transport',
      date: DateTime(2025, 1, 20),
    ),
  ];

  test('build produces a valid PDF document', () async {
    final bytes = await FinanceReportPdf.build(
      rangeLabel: 'January 2025',
      totals: totals(),
      breakdown: const {'Food': 8000, 'Transport': 4345.50},
      breakdownType: TransactionType.expense,
      transactions: transactions(),
      totalMatching: 3,
      generatedAt: DateTime(2025, 1, 31, 10, 30),
    );

    // PDF magic header + non-trivial size.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('build handles empty data gracefully', () async {
    final bytes = await FinanceReportPdf.build(
      rangeLabel: 'Week of Jan 6',
      totals: const FinanceReportTotals(
        income: 0,
        expense: 0,
        matchingCount: 0,
        incomeByCategory: {},
        expenseByCategory: {},
      ),
      breakdown: const {},
      breakdownType: TransactionType.expense,
      transactions: const [],
      totalMatching: 0,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
