import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/formatters.dart';
import '../models/finance_models.dart';
import 'finance_repository.dart';

/// Builds a shareable, nicely formatted PDF copy of the finance report —
/// header with branding, income/expense/net summary cards, category
/// breakdown table and a paginated transactions table.
class FinanceReportPdf {
  FinanceReportPdf._();

  /// Table caps so a multi-year export can't produce a thousand-page PDF.
  static const _maxBreakdownRows = 12;
  static const _maxTransactionRows = 300;

  static const _brand = PdfColor.fromInt(0xFF3F51B5);
  static const _income = PdfColor.fromInt(0xFF0E9F6E);
  static const _expense = PdfColor.fromInt(0xFFD9534F);
  static const _ink = PdfColor.fromInt(0xFF1F2933);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFE5E7EB);
  static const _zebra = PdfColor.fromInt(0xFFF6F8FB);

  static Future<Uint8List> build({
    required String rangeLabel,
    required FinanceReportTotals totals,
    required Map<String, double> breakdown,
    required TransactionType? breakdownType,
    required List<TransactionModel> transactions,
    required int totalMatching,
    String currencySymbol = '₱',
    DateTime? generatedAt,
  }) async {
    final generated = generatedAt ?? DateTime.now();
    final fonts = await _loadFonts();
    final theme = fonts == null
        ? null
        : pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2);

    final doc = pw.Document(theme: theme, title: 'LifeHub financial report');
    final sortedBreakdown = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final breakdownTotal = breakdownType == TransactionType.income
        ? totals.income
        : totals.expense;
    final shownRows = _capBreakdown(sortedBreakdown);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 48),
        header: (context) => _header(context, rangeLabel, generated),
        footer: _footer,
        build: (context) => [
          _summaryCards(totals, currencySymbol),
          pw.SizedBox(height: 22),
          _sectionTitle(
            breakdownType == TransactionType.income
                ? 'Income by category'
                : 'Expenses by category',
          ),
          pw.SizedBox(height: 8),
          if (shownRows.isEmpty || breakdownTotal <= 0)
            _emptyNote('No matching data for these filters')
          else
            _breakdownTable(shownRows, breakdownTotal, currencySymbol),
          pw.SizedBox(height: 22),
          _sectionTitle('Transactions'),
          pw.SizedBox(height: 8),
          if (transactions.isEmpty)
            _emptyNote('No transactions in this period')
          else
            _transactionsTable(transactions, totalMatching, currencySymbol),
        ],
      ),
    );
    return doc.save();
  }

  /// Renders the PDF and writes it to the cache dir for sharing.
  static Future<String> writeToCache({
    required String rangeLabel,
    required FinanceReportTotals totals,
    required Map<String, double> breakdown,
    required TransactionType? breakdownType,
    required List<TransactionModel> transactions,
    required int totalMatching,
    String currencySymbol = '₱',
  }) async {
    final bytes = await build(
      rangeLabel: rangeLabel,
      totals: totals,
      breakdown: breakdown,
      breakdownType: breakdownType,
      transactions: transactions,
      totalMatching: totalMatching,
      currencySymbol: currencySymbol,
    );
    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final file = File(
      '${dir.path}${Platform.pathSeparator}lifehub-report-$stamp.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<(pw.Font, pw.Font)?> _loadFonts() async {
    try {
      final regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      return (pw.Font.ttf(regular), pw.Font.ttf(bold));
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _header(
    pw.Context context,
    String rangeLabel,
    DateTime generated,
  ) {
    final compact = context.pageNumber > 1;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LifeHub',
                  style: pw.TextStyle(
                    fontSize: compact ? 14 : 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _brand,
                  ),
                ),
                pw.Text(
                  'Financial Report',
                  style: const pw.TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  rangeLabel,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Generated ${Formatters.shortDateTime(generated)}',
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1.4, color: _brand),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _footer(pw.Context context) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        'LifeHub — data stays on your device',
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
      pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
    ],
  );

  static pw.Widget _summaryCards(
    FinanceReportTotals totals,
    String currencySymbol,
  ) {
    final net = totals.income - totals.expense;
    return pw.Row(
      children: [
        _summaryCard(
          'Total income',
          _money(totals.income, currencySymbol),
          _income,
        ),
        pw.SizedBox(width: 8),
        _summaryCard(
          'Total expenses',
          _money(totals.expense, currencySymbol),
          _expense,
        ),
        pw.SizedBox(width: 8),
        _summaryCard(
          'Net balance',
          '${net < 0 ? '-' : ''}${_money(net.abs(), currencySymbol)}',
          net < 0 ? _expense : _brand,
        ),
      ],
    );
  }

  static pw.Widget _summaryCard(String label, String value, PdfColor accent) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            // Soft tint of the accent for the card background.
            color: PdfColor(
              accent.red + (1 - accent.red) * 0.9,
              accent.green + (1 - accent.green) * 0.9,
              accent.blue + (1 - accent.blue) * 0.9,
            ),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _line, width: 0.6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: const pw.TextStyle(fontSize: 8.5, color: _muted),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      );

  static List<MapEntry<String, double>> _capBreakdown(
    List<MapEntry<String, double>> sorted,
  ) {
    if (sorted.length <= _maxBreakdownRows) return sorted;
    final keep = _maxBreakdownRows - 1;
    final otherTotal = sorted.skip(keep).fold(0.0, (sum, e) => sum + e.value);
    return [...sorted.take(keep), MapEntry('Other categories', otherTotal)];
  }

  static pw.Widget _breakdownTable(
    List<MapEntry<String, double>> rows,
    double total,
    String currencySymbol,
  ) {
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.6),
        bottom: pw.BorderSide(color: _line, width: 0.6),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(2.2),
        2: pw.FlexColumnWidth(3),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        _tableHeader(['Category', 'Amount', 'Share']),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: _zebra) : null,
            children: [
              _cell(rows[i].key),
              _cell(
                _money(rows[i].value, currencySymbol),
                align: pw.TextAlign.right,
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          // Proportional share bar via flex segments.
                          for (final seg in _barSegments(
                            total <= 0 ? 0 : rows[i].value / total,
                          ))
                            pw.Expanded(
                              flex: seg.$2,
                              child: pw.Container(
                                height: 7,
                                decoration: seg.$1
                                    ? pw.BoxDecoration(
                                        color: _brand,
                                        borderRadius: pw.BorderRadius.circular(
                                          3,
                                        ),
                                      )
                                    : const pw.BoxDecoration(color: _line),
                              ),
                            ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      '${(rows[i].value / (total <= 0 ? 1 : total) * 100).toStringAsFixed(0)}%',
                      style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// (filled?, flex) segments for the share bar — flex is always >= 1.
  static List<(bool, int)> _barSegments(double share) {
    final filled = (share.clamp(0, 1) * 100).round();
    if (filled <= 0) return const [(false, 1)];
    if (filled >= 100) return const [(true, 1)];
    return [(true, filled), (false, 100 - filled)];
  }

  static pw.Widget _transactionsTable(
    List<TransactionModel> transactions,
    int totalMatching,
    String currencySymbol,
  ) {
    final shown = transactions.take(_maxTransactionRows).toList();
    final hidden = totalMatching - shown.length;
    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _line, width: 0.6),
        bottom: pw.BorderSide(color: _line, width: 0.6),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.6),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(3.4),
        4: pw.FlexColumnWidth(1.8),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        _tableHeader(['Date', 'Type', 'Category', 'Note', 'Amount']),
        for (var i = 0; i < shown.length; i++)
          pw.TableRow(
            decoration: i.isOdd ? const pw.BoxDecoration(color: _zebra) : null,
            children: [
              _cell(Formatters.shortDate(shown[i].date)),
              _cell(
                shown[i].type == TransactionType.income ? 'Income' : 'Expense',
              ),
              _cell(shown[i].category),
              _cell(
                shown[i].note.isEmpty ? '—' : shown[i].note,
                muted: shown[i].note.isEmpty,
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 7,
                ),
                child: pw.Text(
                  '${shown[i].type == TransactionType.income ? '+' : '-'}'
                  '${_money(shown[i].amount, currencySymbol)}',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: shown[i].type == TransactionType.income
                        ? _income
                        : _expense,
                  ),
                ),
              ),
            ],
          ),
        if (hidden > 0)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  '…and $hidden more transaction${hidden == 1 ? '' : 's'} '
                  'not shown (export capped at $_maxTransactionRows rows)',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                ),
              ),
              for (var i = 0; i < 4; i++) pw.SizedBox(),
            ],
          ),
      ],
    );
  }

  static pw.TableRow _tableHeader(List<String> labels) => pw.TableRow(
    decoration: const pw.BoxDecoration(
      color: _brand,
      borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
    ),
    children: [
      for (var i = 0; i < labels.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: pw.Text(
            labels[i],
            textAlign: i == labels.length - 1 || i == 1
                ? pw.TextAlign.right
                : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
    ],
  );

  static pw.Widget _cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool muted = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: pw.Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: pw.TextOverflow.clip,
      style: pw.TextStyle(fontSize: 9, color: muted ? _muted : _ink),
    ),
  );

  static pw.Widget _sectionTitle(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 13,
      fontWeight: pw.FontWeight.bold,
      color: _ink,
    ),
  );

  static pw.Widget _emptyNote(String text) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _zebra,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: const pw.TextStyle(fontSize: 9.5, color: _muted),
    ),
  );

  /// Money for the PDF — always unmasked since exporting is an
  /// explicit user action.
  static String _money(num amount, String currencySymbol) =>
      '$currencySymbol${NumberFormat('#,##0.00').format(amount)}';
}
