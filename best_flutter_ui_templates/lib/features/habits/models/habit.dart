import '../../../core/utils/formatters.dart';

class HabitModel {
  HabitModel({
    required this.id,
    required this.name,
    this.icon = 'other',
    this.colorValue = 0xFF7B61FF,
    this.description = '',
    required this.createdAt,
    List<String>? completedDays,
  }) : completedDays = completedDays ?? <String>[];

  final String id;
  final String name;
  final String icon;
  final int colorValue;
  final String description;
  final DateTime createdAt;

  /// List of 'yyyy-MM-dd' day keys when the habit was completed.
  final List<String> completedDays;

  bool isDoneOn(DateTime day) => completedDays.contains(Formatters.dayKey(day));

  bool get isDoneToday => isDoneOn(DateTime.now());

  /// Consecutive-day streak ending today (or yesterday if today is
  /// not yet checked off).
  int get streak {
    final done = completedDays.toSet();
    var count = 0;
    var day = DateTime.now();
    if (!done.contains(Formatters.dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    while (done.contains(Formatters.dayKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  HabitModel copyWith({List<String>? completedDays}) => HabitModel(
    id: id,
    name: name,
    icon: icon,
    colorValue: colorValue,
    description: description,
    createdAt: createdAt,
    completedDays: completedDays ?? this.completedDays,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'colorValue': colorValue,
    'description': description,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'completedDays': completedDays,
  };

  factory HabitModel.fromMap(Map map) => HabitModel(
    id: map['id'] as String,
    name: map['name'] as String,
    icon: (map['icon'] as String?) ?? 'other',
    colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF7B61FF,
    description: (map['description'] as String?) ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    completedDays:
        (map['completedDays'] as List?)?.cast<String>() ?? <String>[],
  );
}
