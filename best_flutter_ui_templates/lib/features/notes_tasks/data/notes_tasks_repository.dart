import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_db.dart';
import '../../../core/services/notification_service.dart';
import '../models/notes_tasks_models.dart';

class NotesTasksRepository {
  // ---------- Notes ----------

  List<NoteModel> getNotes() =>
      LocalDb.box(
          AppConstants.notesBox,
        ).values.map((m) => NoteModel.fromMap(m as Map)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> saveNote(NoteModel n) =>
      LocalDb.box(AppConstants.notesBox).put(n.id, n.toMap());

  Future<void> deleteNote(String id) =>
      LocalDb.box(AppConstants.notesBox).delete(id);

  // ---------- Tasks ----------

  List<TaskModel> getTasks() {
    final tasks = LocalDb.box(
      AppConstants.tasksBox,
    ).values.map((m) => TaskModel.fromMap(m as Map)).toList();
    tasks.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final ad = a.dueDate ?? DateTime(9999);
      final bd = b.dueDate ?? DateTime(9999);
      return ad.compareTo(bd);
    });
    return tasks;
  }

  /// Tasks due on or before [day] (includes overdue), still pending.
  List<TaskModel> tasksForDay(DateTime day) {
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
    return getTasks()
        .where((t) => t.dueDate != null && !t.dueDate!.isAfter(endOfDay))
        .toList();
  }

  Future<ReminderScheduleResult?> saveTask(TaskModel task) async {
    await LocalDb.box(AppConstants.tasksBox).put(task.id, task.toMap());
    if (task.reminderAt != null && !task.isDone) {
      return NotificationService.scheduleReminder(
        id: 'task_${task.id}',
        title: 'Task Reminder',
        body: 'You have a task due.',
        when: task.reminderAt!,
      );
    }
    await NotificationService.cancel('task_${task.id}');
    return null;
  }

  Future<void> deleteTask(String id) async {
    await LocalDb.box(AppConstants.tasksBox).delete(id);
    await NotificationService.cancel('task_$id');
  }
}
