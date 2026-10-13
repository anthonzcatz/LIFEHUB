class NoteModel {
  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.colorIndex = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'colorIndex': colorIndex,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory NoteModel.fromMap(Map map) => NoteModel(
    id: map['id'] as String,
    title: map['title'] as String,
    content: (map['content'] as String?) ?? '',
    colorIndex: (map['colorIndex'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
  );
}

class TaskModel {
  TaskModel({
    required this.id,
    required this.title,
    this.isDone = false,
    this.priority = 'Medium',
    this.dueDate,
    this.reminderAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final bool isDone;
  final String priority;
  final DateTime? dueDate;
  final DateTime? reminderAt;
  final DateTime createdAt;

  TaskModel copyWith({
    String? title,
    bool? isDone,
    String? priority,
    DateTime? dueDate,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) => TaskModel(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    priority: priority ?? this.priority,
    dueDate: dueDate ?? this.dueDate,
    reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'isDone': isDone,
    'priority': priority,
    'dueDate': dueDate?.millisecondsSinceEpoch,
    'reminderAt': reminderAt?.millisecondsSinceEpoch,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory TaskModel.fromMap(Map map) => TaskModel(
    id: map['id'] as String,
    title: map['title'] as String,
    isDone: map['isDone'] == true,
    priority: (map['priority'] as String?) ?? 'Medium',
    dueDate: map['dueDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
        : null,
    reminderAt: map['reminderAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['reminderAt'] as int)
        : null,
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
  );
}
