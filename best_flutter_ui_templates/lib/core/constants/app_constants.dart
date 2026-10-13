class AppConstants {
  AppConstants._();

  // Hive box names
  static const String settingsBox = 'settings';
  static const String transactionsBox = 'transactions';
  static const String transactionIndexBox = 'transaction_index';
  static const String budgetsBox = 'budgets';
  static const String savingsGoalsBox = 'savings_goals';
  static const String notesBox = 'notes';
  static const String tasksBox = 'tasks';
  static const String habitsBox = 'habits';
  static const String habitLogsBox = 'habit_logs';
  static const String vaultBox = 'vault';

  // Settings keys
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyPinHash = 'pin_hash';
  static const String keyPinSalt = 'pin_salt';
  static const String keyPinFailedAttempts = 'pin_failed_attempts';
  static const String keyPinLockUntil = 'pin_lock_until_ms';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyUserName = 'user_name';
  static const String keyUserEmail = 'user_email';
  static const String keyUserPhoto = 'user_photo_path';
  static const String keyUserBio = 'user_bio';
  static const String keyAuthMode = 'auth_mode'; // 'none' | 'pin' | 'firebase'
  static const String keyCurrency = 'currency_symbol';
  static const String keyHabitReminderEnabled = 'habit_reminder_enabled';
  static const String keyHabitReminderTime = 'habit_reminder_time'; // 'HH:mm'
  static const String keyHideAmounts = 'hide_amounts';

  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Bills',
    'Shopping',
    'Entertainment',
    'Health',
    'Education',
    'Others',
  ];

  static const List<String> incomeCategories = [
    'Salary',
    'Business',
    'Freelance',
    'Allowance',
    'Investment',
    'Others',
  ];

  static const List<String> taskPriorities = ['Low', 'Medium', 'High'];

  static const List<String> habitIcons = [
    'exercise',
    'reading',
    'studying',
    'water',
    'sleep',
    'meditation',
    'other',
  ];
}
