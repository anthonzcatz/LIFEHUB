import 'package:intl/intl.dart';

import '../constants/app_constants.dart';
import '../services/local_db.dart';

class Formatters {
  Formatters._();

  static String get currencySymbol =>
      LocalDb.settings.get(AppConstants.keyCurrency, defaultValue: '₱')
          as String;

  /// Privacy mode — masks every monetary value shown in the UI.
  static bool get hideAmounts =>
      LocalDb.settings.get(AppConstants.keyHideAmounts, defaultValue: false) ==
      true;

  static String money(num amount) {
    if (hideAmounts) return '$currencySymbol••••';
    final f = NumberFormat('#,##0.00');
    return '$currencySymbol${f.format(amount)}';
  }

  static String date(DateTime d) => DateFormat('MMM d, yyyy').format(d);
  static String shortDate(DateTime d) => DateFormat('MMM d').format(d);
  static String shortDateTime(DateTime d) =>
      DateFormat('MMM d, h:mm a').format(d);
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);
  static String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
}
