enum TransactionType { expense, income }

class TransactionModel {
  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note = '',
    required this.date,
  });

  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String note;
  final DateTime date;

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'category': category,
    'note': note,
    'date': date.millisecondsSinceEpoch,
  };

  factory TransactionModel.fromMap(Map map) => TransactionModel(
    id: map['id'] as String,
    type: TransactionType.values.byName(map['type'] as String),
    amount: (map['amount'] as num).toDouble(),
    category: map['category'] as String,
    note: (map['note'] as String?) ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
  );
}

class BudgetModel {
  BudgetModel({
    required this.id,
    required this.category,
    required this.monthlyLimit,
  });

  final String id;
  final String category;
  final double monthlyLimit;

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category,
    'monthlyLimit': monthlyLimit,
  };

  factory BudgetModel.fromMap(Map map) => BudgetModel(
    id: map['id'] as String,
    category: map['category'] as String,
    monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
  );
}

/// A single deposit or withdrawal recorded against a savings goal.
class SavingsDepositModel {
  SavingsDepositModel({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    this.isWithdrawal = false,
  });

  final String id;

  /// Always positive; [isWithdrawal] decides the direction.
  final double amount;
  final DateTime date;
  final String note;
  final bool isWithdrawal;

  double get signedAmount => isWithdrawal ? -amount : amount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'amount': amount,
    'date': date.millisecondsSinceEpoch,
    'note': note,
    'isWithdrawal': isWithdrawal,
  };

  factory SavingsDepositModel.fromMap(Map map) => SavingsDepositModel(
    id: map['id'] as String,
    amount: (map['amount'] as num).toDouble(),
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    note: (map['note'] as String?) ?? '',
    isWithdrawal: map['isWithdrawal'] == true,
  );
}

class SavingsGoalModel {
  SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.deadline,
    DateTime? createdAt,
    List<SavingsDepositModel>? deposits,
  }) : createdAt = createdAt ?? DateTime.now(),
       deposits = deposits ?? const [];

  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime? deadline;
  final DateTime createdAt;

  /// Contribution history, newest first.
  final List<SavingsDepositModel> deposits;

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  int? get daysLeft {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  SavingsGoalModel copyWith({
    double? savedAmount,
    List<SavingsDepositModel>? deposits,
  }) => SavingsGoalModel(
    id: id,
    name: name,
    targetAmount: targetAmount,
    savedAmount: savedAmount ?? this.savedAmount,
    deadline: deadline,
    createdAt: createdAt,
    deposits: deposits ?? this.deposits,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'savedAmount': savedAmount,
    'deadline': deadline?.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'deposits': deposits.map((d) => d.toMap()).toList(),
  };

  factory SavingsGoalModel.fromMap(Map map) {
    final rawDeposits = map['deposits'];
    final deposits = rawDeposits is List
        ? (rawDeposits
              .map((d) => SavingsDepositModel.fromMap(d as Map))
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date)))
        : <SavingsDepositModel>[];
    return SavingsGoalModel(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0,
      deadline: map['deadline'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
      deposits: deposits,
    );
  }
}
