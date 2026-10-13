import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'local_db.dart';

/// Expense/income categories: built-in defaults plus user-created
/// custom categories persisted in the settings box.
class CategoryService {
  CategoryService._();

  static const _expenseKey = 'custom_expense_categories';
  static const _incomeKey = 'custom_income_categories';

  static List<String> _custom(bool expense) {
    final raw = LocalDb.settings.get(
      expense ? _expenseKey : _incomeKey,
      defaultValue: <String>[],
    );
    return List<String>.from(raw as List);
  }

  static List<String> expenseCategories() => [
    ...AppConstants.expenseCategories,
    ..._custom(true),
  ];

  static List<String> incomeCategories() => [
    ...AppConstants.incomeCategories,
    ..._custom(false),
  ];

  static List<String> customCategories({required bool isExpense}) =>
      _custom(isExpense);

  static Future<void> add(String name, {required bool isExpense}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final list = isExpense ? expenseCategories() : incomeCategories();
    if (list.any((c) => c.toLowerCase() == trimmed.toLowerCase())) return;
    final customs = _custom(isExpense)..add(trimmed);
    await LocalDb.settings.put(isExpense ? _expenseKey : _incomeKey, customs);
  }

  static Future<void> removeCustom(
    String name, {
    required bool isExpense,
  }) async {
    final customs = _custom(isExpense)..remove(name);
    await LocalDb.settings.put(isExpense ? _expenseKey : _incomeKey, customs);
  }

  /// Icon per category — gives transaction lists a pro look.
  static IconData iconFor(String name) {
    switch (name.toLowerCase()) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'bills':
        return Icons.receipt_long;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'health':
        return Icons.favorite;
      case 'education':
        return Icons.school;
      case 'salary':
        return Icons.work;
      case 'business':
        return Icons.store;
      case 'freelance':
        return Icons.laptop;
      case 'allowance':
        return Icons.wallet;
      case 'investment':
        return Icons.trending_up;
      case 'others':
        return Icons.category;
      default:
        return Icons.label;
    }
  }
}
