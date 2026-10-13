import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_utils.dart';

import '../../../core/services/notification_service.dart';
import '../data/notes_tasks_repository.dart';
import '../models/notes_tasks_models.dart';

final notesTasksRepositoryProvider = Provider<NotesTasksRepository>(
  (ref) => NotesTasksRepository(),
);

class NotesNotifier extends Notifier<List<NoteModel>> {
  @override
  List<NoteModel> build() => ref.read(notesTasksRepositoryProvider).getNotes();

  Future<void> save({
    String? id,
    required String title,
    required String content,
    int colorIndex = 0,
  }) async {
    final now = DateTime.now();
    await ref
        .read(notesTasksRepositoryProvider)
        .saveNote(
          NoteModel(
            id: id ?? newId(),
            title: title,
            content: content,
            colorIndex: colorIndex,
            createdAt: id == null
                ? now
                : state
                          .where((n) => n.id == id)
                          .map((n) => n.createdAt)
                          .firstOrNull ??
                      now,
            updatedAt: now,
          ),
        );
    state = ref.read(notesTasksRepositoryProvider).getNotes();
  }

  Future<void> remove(String id) async {
    await ref.read(notesTasksRepositoryProvider).deleteNote(id);
    state = ref.read(notesTasksRepositoryProvider).getNotes();
  }
}

final notesProvider = NotifierProvider<NotesNotifier, List<NoteModel>>(
  NotesNotifier.new,
);

class TasksNotifier extends Notifier<List<TaskModel>> {
  @override
  List<TaskModel> build() => ref.read(notesTasksRepositoryProvider).getTasks();

  Future<ReminderScheduleResult?> add({
    required String title,
    String priority = 'Medium',
    DateTime? dueDate,
    DateTime? reminderAt,
  }) async {
    final reminderResult = await ref
        .read(notesTasksRepositoryProvider)
        .saveTask(
          TaskModel(
            id: newId(),
            title: title,
            priority: priority,
            dueDate: dueDate,
            reminderAt: reminderAt,
            createdAt: DateTime.now(),
          ),
        );
    state = ref.read(notesTasksRepositoryProvider).getTasks();
    return reminderResult;
  }

  Future<ReminderScheduleResult?> update(TaskModel task) async {
    final reminderResult = await ref
        .read(notesTasksRepositoryProvider)
        .saveTask(task);
    state = ref.read(notesTasksRepositoryProvider).getTasks();
    return reminderResult;
  }

  Future<ReminderScheduleResult?> toggle(TaskModel task) async {
    final reminderResult = await ref
        .read(notesTasksRepositoryProvider)
        .saveTask(
          task.copyWith(isDone: !task.isDone, clearReminder: !task.isDone),
        );
    state = ref.read(notesTasksRepositoryProvider).getTasks();
    return reminderResult;
  }

  Future<TaskModel?> remove(String id) async {
    final task = state.where((item) => item.id == id).firstOrNull;
    if (task == null) return null;
    await ref.read(notesTasksRepositoryProvider).deleteTask(id);
    state = ref.read(notesTasksRepositoryProvider).getTasks();
    return task;
  }

  Future<ReminderScheduleResult?> restore(TaskModel task) async {
    final result = await ref.read(notesTasksRepositoryProvider).saveTask(task);
    state = ref.read(notesTasksRepositoryProvider).getTasks();
    return result;
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<TaskModel>>(
  TasksNotifier.new,
);

/// Tasks due today (for the dashboard).
final todaysTasksProvider = Provider<List<TaskModel>>((ref) {
  ref.watch(tasksProvider);
  return ref
      .read(notesTasksRepositoryProvider)
      .tasksForDay(DateTime.now())
      .where((t) => !t.isDone)
      .toList();
});
