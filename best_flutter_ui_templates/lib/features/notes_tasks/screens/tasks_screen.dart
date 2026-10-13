import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../models/notes_tasks_models.dart';
import '../providers/notes_tasks_providers.dart';
import 'notes_screen.dart';
import 'task_form_sheet.dart';

enum _TaskFilter { all, open, completed, overdue }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const _maxVisibleTasks = 100;
  String _query = '';
  _TaskFilter _filter = _TaskFilter.all;

  String _filterLabel(_TaskFilter filter) => switch (filter) {
    _TaskFilter.all => 'All',
    _TaskFilter.open => 'Open',
    _TaskFilter.completed => 'Completed',
    _TaskFilter.overdue => 'Overdue',
  };

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final query = _query.trim().toLowerCase();
    final filteredTasks = tasks.where((task) {
      final queryMatches =
          query.isEmpty ||
          '${task.title} ${task.priority}'.toLowerCase().contains(query);
      final filterMatches = switch (_filter) {
        _TaskFilter.all => true,
        _TaskFilter.open => !task.isDone,
        _TaskFilter.completed => task.isDone,
        _TaskFilter.overdue =>
          !task.isDone &&
              task.dueDate != null &&
              task.dueDate!.isBefore(DateTime.now()),
      };
      return queryMatches && filterMatches;
    }).toList();
    final visibleTasks = filteredTasks.take(_maxVisibleTasks).toList();

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Tasks & Notes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.note_alt_outlined),
            tooltip: 'Notes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotesScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LifeHubTheme.tasks,
        icon: const Icon(Icons.add_task, color: Colors.white),
        label: const Text('New Task', style: TextStyle(color: Colors.white)),
        onPressed: () => showTaskFormSheet(context),
      ),
      body: tasks.isEmpty
          ? const EmptyState(
              message:
                  'No tasks yet.\nTap "New Task" to create your first one.',
              icon: Icons.check_circle_outline,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'Search tasks or priorities',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(() => _query = ''),
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final filter in _TaskFilter.values) ...[
                        if (filter != _TaskFilter.values.first)
                          const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(_filterLabel(filter)),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${filteredTasks.length} matching task${filteredTasks.length == 1 ? '' : 's'}',
                      style: LifeHubTheme.caption,
                    ),
                  ),
                ),
                Expanded(
                  child: filteredTasks.isEmpty
                      ? const EmptyState(
                          message: 'No tasks match these filters.',
                          icon: Icons.filter_alt_off_outlined,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount:
                              visibleTasks.length +
                              (filteredTasks.length > _maxVisibleTasks ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= visibleTasks.length) {
                              return const Padding(
                                padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                                child: Text(
                                  'Showing the first 100 tasks. Refine search or filters to see a smaller set.',
                                  textAlign: TextAlign.center,
                                  style: LifeHubTheme.caption,
                                ),
                              );
                            }
                            return FadeSlideIn.item(
                              index: index,
                              child: _TaskTile(task: visibleTasks[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue =
        task.dueDate != null &&
        !task.isDone &&
        task.dueDate!.isBefore(DateTime.now());

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: LifeHubTheme.dismissibleBackground,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final notifier = ref.read(tasksProvider.notifier);
        final removed = await notifier.remove(task.id);
        if (removed == null) return;
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Task deleted.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                final result = await notifier.restore(removed);
                if (result != null && !result.scheduled) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Task restored, but its reminder could not be scheduled.',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
      child: Card(
        color: LifeHubTheme.white,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showTaskFormSheet(context, task: task),
          child: CheckboxListTile(
            value: task.isDone,
            onChanged: (_) async {
              final result = await ref
                  .read(tasksProvider.notifier)
                  .toggle(task);
              if (!context.mounted || result == null) return;
              final message = switch (result.status) {
                ReminderScheduleStatus.exact => null,
                ReminderScheduleStatus.inexact =>
                  'Task updated. Android may deliver the reminder a little later.',
                ReminderScheduleStatus.permissionDenied =>
                  'Task updated, but notifications are disabled for LifeHub.',
                ReminderScheduleStatus.invalidTime =>
                  'Task updated, but its reminder time has passed.',
                ReminderScheduleStatus.failed =>
                  'Task updated, but its reminder could not be scheduled.',
              };
              if (message != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(message)));
              }
            },
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isDone ? TextDecoration.lineThrough : null,
                color: task.isDone
                    ? LifeHubTheme.deactivatedText
                    : LifeHubTheme.darkText,
              ),
            ),
            subtitle: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor(
                      task.priority,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.priority,
                    style: TextStyle(
                      fontSize: 11,
                      color: _priorityColor(task.priority),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (task.dueDate != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: overdue ? Colors.red : LifeHubTheme.lightText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.shortDateTime(task.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: overdue ? Colors.red : LifeHubTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                if (task.reminderAt != null)
                  const Tooltip(
                    message: 'Reminder scheduled',
                    child: Icon(
                      Icons.notifications,
                      size: 12,
                      color: LifeHubTheme.lightText,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'High':
        return Colors.red;
      case 'Low':
        return LifeHubTheme.finance;
      default:
        return LifeHubTheme.notes;
    }
  }
}
