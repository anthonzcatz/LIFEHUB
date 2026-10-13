import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

/// Central Hive initializer. All data is stored as `Map<dynamic, dynamic>`
/// so no code generation is required.
class LocalDb {
  LocalDb._();

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(AppConstants.settingsBox),
      Hive.openBox(AppConstants.transactionsBox),
      Hive.openBox(AppConstants.transactionIndexBox),
      Hive.openBox(AppConstants.budgetsBox),
      Hive.openBox(AppConstants.savingsGoalsBox),
      Hive.openBox(AppConstants.notesBox),
      Hive.openBox(AppConstants.tasksBox),
      Hive.openBox(AppConstants.habitsBox),
      Hive.openBox(AppConstants.habitLogsBox),
      Hive.openBox(AppConstants.vaultBox),
    ]);
  }

  static Box box(String name) => Hive.box(name);
  static Box get settings => Hive.box(AppConstants.settingsBox);
}
