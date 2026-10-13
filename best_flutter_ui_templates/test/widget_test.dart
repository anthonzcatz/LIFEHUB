import 'dart:io';

import 'package:lifehub/app/app.dart';
import 'package:lifehub/app/home_shell.dart';
import 'package:lifehub/core/constants/app_constants.dart';
import 'package:lifehub/core/services/security_service.dart';
import 'package:lifehub/features/auth/screens/pin_screen.dart';
import 'package:lifehub/features/finance/models/finance_models.dart';
import 'package:lifehub/features/finance/screens/finance_screen.dart';
import 'package:lifehub/features/finance/screens/report_screen.dart';
import 'package:lifehub/features/notes_tasks/models/notes_tasks_models.dart';
import 'package:lifehub/features/notes_tasks/screens/notes_screen.dart';
import 'package:lifehub/features/notes_tasks/screens/tasks_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;

  // Runs in real async (outside the testWidgets fake-async zone).
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(dir.path);
    for (final name in [
      AppConstants.settingsBox,
      AppConstants.transactionsBox,
      AppConstants.transactionIndexBox,
      AppConstants.budgetsBox,
      AppConstants.savingsGoalsBox,
      AppConstants.notesBox,
      AppConstants.tasksBox,
      AppConstants.habitsBox,
      AppConstants.habitLogsBox,
      AppConstants.vaultBox,
    ]) {
      await Hive.openBox(name);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  testWidgets('First launch shows onboarding', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LifeHubApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LifeHub'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text("Let's begin"), findsOneWidget);
  });

  testWidgets('PIN setup accepts four digits and confirms', (tester) async {
    var success = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PinScreen(mode: PinMode.setup, onSuccess: () => success = true),
      ),
    );
    await tester.pump();

    final field = find.byType(TextField);
    expect(find.text('Enter 4–8 digits'), findsOneWidget);
    expect(find.text('0/8 digits'), findsOneWidget);

    await tester.enterText(field, '4826');
    await tester.pump();
    expect(find.text('4/8 digits'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Confirm your PIN'), findsOneWidget);
    await tester.enterText(field, '4826');
    await tester.pump();
    expect(find.text('4/8 digits'), findsOneWidget);

    // The persistence and verification part of the final submit is covered
    // by the async SecurityService regression test in lifehub_unit_test.dart.
    expect(success, isFalse);
  });

  testWidgets('configured PIN mode always requires unlock', (tester) async {
    await tester.runAsync(() async {
      final settings = Hive.box(AppConstants.settingsBox);
      await settings.clear();
      await settings.put(AppConstants.keyOnboardingDone, true);
      await settings.put(AppConstants.keyAuthMode, 'pin');
      await SecurityService.setPin('4826');
    });

    await tester.pumpWidget(const ProviderScope(child: LifeHubApp()));
    await tester.pump();

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
  });

  testWidgets('unlock screen clears setup text when mode changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PinScreen(mode: PinMode.setup, onSuccess: () {}),
      ),
    );
    await tester.pump();

    final field = find.byType(TextField);
    await tester.enterText(field, '4826');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Confirm your PIN'), findsOneWidget);

    // Same widget type, as happens when the app gate rebuilds.
    await tester.pumpWidget(
      MaterialApp(
        home: PinScreen(mode: PinMode.unlock, onSuccess: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('0/8 digits'), findsOneWidget);
  });

  testWidgets('finance history defaults to current-month filtered view', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final box = Hive.box(AppConstants.transactionsBox);
      await box.clear();
      await box.put(
        'current',
        TransactionModel(
          id: 'current',
          type: TransactionType.expense,
          amount: 80,
          category: 'Current expense',
          date: now,
        ).toMap(),
      );
      await box.put(
        'previous',
        TransactionModel(
          id: 'previous',
          type: TransactionType.expense,
          amount: 40,
          category: 'Previous expense',
          date: DateTime(now.year, now.month - 1, 15),
        ).toMap(),
      );
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: FinanceScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current expense'), findsOneWidget);
    expect(find.text('Previous expense'), findsNothing);

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(find.text('Previous expense'), findsOneWidget);
  });

  testWidgets('report filters aggregate data by transaction type', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final box = Hive.box(AppConstants.transactionsBox);
      await box.clear();
      await box.put(
        'expense',
        TransactionModel(
          id: 'expense',
          type: TransactionType.expense,
          amount: 120,
          category: 'Food',
          date: now,
        ).toMap(),
      );
      await box.put(
        'income',
        TransactionModel(
          id: 'income',
          type: TransactionType.income,
          amount: 1000,
          category: 'Salary',
          date: now,
        ).toMap(),
      );
    });

    // Tall viewport so the whole report (filters + charts + breakdown)
    // is laid out without scrolling.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Expenses by Category'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<ReportTypeFilter>),
        matching: find.text('Income'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Income by Category'), findsOneWidget);
    expect(find.text('Expenses by Category'), findsNothing);
    expect(find.text('Salary'), findsOneWidget);
  });

  testWidgets('hide amounts masks report values and chart proportions', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await Hive.box(
        AppConstants.settingsBox,
      ).put(AppConstants.keyHideAmounts, true);
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(PieChart), findsNothing);
    expect(
      find.text('Chart hidden while amounts are hidden'),
      findsNWidgets(2),
    );

    await tester.runAsync(
      () => Hive.box(
        AppConstants.settingsBox,
      ).delete(AppConstants.keyHideAmounts),
    );
  });

  testWidgets('app switcher snapshot is obscured while inactive', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final settings = Hive.box(AppConstants.settingsBox);
      await settings.clear();
    });
    await tester.pumpWidget(const ProviderScope(child: LifeHubApp()));
    await tester.pumpAndSettle();
    final lockIcons = find.byIcon(Icons.lock_outline);
    expect(lockIcons, findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(lockIcons, findsNWidgets(2));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text("Let's begin"), findsOneWidget);
  });

  testWidgets('wide HomeShell uses an accessible navigation rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomeShell())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomAppBar), findsNothing);
  });

  testWidgets('task search and status filters bound the visible task set', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final box = Hive.box(AppConstants.tasksBox);
      await box.clear();
      await box.put(
        'overdue',
        TaskModel(
          id: 'overdue',
          title: 'Submit report',
          priority: 'High',
          dueDate: now.subtract(const Duration(days: 1)),
          createdAt: now,
        ).toMap(),
      );
      await box.put(
        'open',
        TaskModel(
          id: 'open',
          title: 'Call Bob',
          dueDate: now.add(const Duration(hours: 2)),
          createdAt: now,
        ).toMap(),
      );
      await box.put(
        'done',
        TaskModel(
          id: 'done',
          title: 'Read book',
          isDone: true,
          createdAt: now,
        ).toMap(),
      );
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TasksScreen())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'report');
    await tester.pumpAndSettle();
    expect(find.text('Submit report'), findsOneWidget);
    expect(find.text('Call Bob'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Overdue'));
    await tester.pumpAndSettle();
    expect(find.text('Submit report'), findsOneWidget);
    expect(find.text('Read book'), findsNothing);
  });

  testWidgets('notes search filters the virtualized grid', (tester) async {
    final now = DateTime.now();
    await tester.runAsync(() async {
      final box = Hive.box(AppConstants.notesBox);
      await box.clear();
      await box.put(
        'tax',
        NoteModel(
          id: 'tax',
          title: 'Tax checklist',
          content: 'Receipts and forms',
          createdAt: now,
          updatedAt: now,
        ).toMap(),
      );
      await box.put(
        'weekend',
        NoteModel(
          id: 'weekend',
          title: 'Weekend plan',
          content: 'Visit family',
          createdAt: now,
          updatedAt: now,
        ).toMap(),
      );
    });

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NotesScreen())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'receipts');
    await tester.pumpAndSettle();

    expect(find.text('Tax checklist'), findsOneWidget);
    expect(find.text('Weekend plan'), findsNothing);
  });
}
