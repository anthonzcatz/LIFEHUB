import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../models/notes_tasks_models.dart';
import '../providers/notes_tasks_providers.dart';

/// Preset reminder offsets relative to the task's due date/time.
enum _ReminderPreset { none, atDue, min15, hour1, day1, custom }

void showTaskFormSheet(BuildContext context, {TaskModel? task}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => TaskFormSheet(task: task),
  );
}

class TaskFormSheet extends ConsumerStatefulWidget {
  const TaskFormSheet({super.key, this.task});

  /// Non-null when editing an existing task.
  final TaskModel? task;

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  late final TextEditingController _titleController;
  String _priority = 'Medium';
  DateTime? _dueDate;
  DateTime? _reminderAt;
  _ReminderPreset _preset = _ReminderPreset.none;
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? '');
    if (t != null) {
      _priority = t.priority;
      _dueDate = t.dueDate;
      _reminderAt = t.reminderAt;
      _preset = t.reminderAt == null
          ? _ReminderPreset.none
          : _ReminderPreset.custom;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime({
    required bool requireFuture,
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: requireFuture ? now : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        initial ?? DateTime(now.year, now.month, now.day, now.hour + 1),
      ),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _fmt(DateTime d) =>
      '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _applyPreset(_ReminderPreset p) {
    setState(() {
      _preset = p;
      switch (p) {
        case _ReminderPreset.none:
          _reminderAt = null;
        case _ReminderPreset.atDue:
          _reminderAt = _dueDate;
        case _ReminderPreset.min15:
          _reminderAt = _dueDate?.subtract(const Duration(minutes: 15));
        case _ReminderPreset.hour1:
          _reminderAt = _dueDate?.subtract(const Duration(hours: 1));
        case _ReminderPreset.day1:
          _reminderAt = _dueDate?.subtract(const Duration(days: 1));
        case _ReminderPreset.custom:
          // Custom picker is opened separately.
          break;
      }
    });
  }

  String? _reminderFeedback(ReminderScheduleResult? result) {
    if (result == null || result.status == ReminderScheduleStatus.exact) {
      return null;
    }
    return switch (result.status) {
      ReminderScheduleStatus.exact => null,
      ReminderScheduleStatus.inexact =>
        'Task saved. Android may deliver this reminder a little later.',
      ReminderScheduleStatus.permissionDenied =>
        'Task saved, but notifications are disabled for LifeHub.',
      ReminderScheduleStatus.invalidTime =>
        'Task saved, but the reminder time has already passed.',
      ReminderScheduleStatus.failed =>
        'Task saved, but the reminder could not be scheduled.',
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a task title.')));
      return;
    }
    if (_reminderAt != null && !_reminderAt!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose a future reminder time or select None.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notifier = ref.read(tasksProvider.notifier);
      final result = _isEditing
          ? await notifier.update(
              widget.task!.copyWith(
                title: title,
                priority: _priority,
                dueDate: _dueDate,
                reminderAt: _reminderAt,
                clearReminder: _reminderAt == null,
              ),
            )
          : await notifier.add(
              title: title,
              priority: _priority,
              dueDate: _dueDate,
              reminderAt: _reminderAt,
            );
      if (!mounted) return;
      final feedback = _reminderFeedback(result);
      Navigator.pop(context);
      if (feedback != null) {
        messenger.showSnackBar(SnackBar(content: Text(feedback)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not save the task. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? 'Edit Task' : 'New Task',
            style: LifeHubTheme.title,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: !_isEditing,
            decoration: const InputDecoration(
              labelText: 'Task title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Priority', style: LifeHubTheme.caption),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: AppConstants.taskPriorities
                .map((p) => ButtonSegment(value: p, label: Text(p)))
                .toList(),
            selected: {_priority},
            onSelectionChanged: (s) => setState(() => _priority = s.first),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(
              _dueDate == null
                  ? 'Set due date & time'
                  : 'Due: ${_fmt(_dueDate!)}',
            ),
            onPressed: () async {
              final picked = await _pickDateTime(
                requireFuture: false,
                initial: _dueDate,
              );
              if (picked != null) {
                setState(() {
                  _dueDate = picked;
                  _applyPreset(_preset); // keep reminder in sync
                });
              }
            },
          ),
          const SizedBox(height: 8),
          const Text('Reminder', style: LifeHubTheme.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: _preset == _ReminderPreset.none,
                onSelected: (_) => _applyPreset(_ReminderPreset.none),
              ),
              ChoiceChip(
                label: const Text('At due time'),
                selected: _preset == _ReminderPreset.atDue,
                onSelected: _dueDate == null
                    ? null
                    : (_) => _applyPreset(_ReminderPreset.atDue),
              ),
              ChoiceChip(
                label: const Text('15 min before'),
                selected: _preset == _ReminderPreset.min15,
                onSelected: _dueDate == null
                    ? null
                    : (_) => _applyPreset(_ReminderPreset.min15),
              ),
              ChoiceChip(
                label: const Text('1 hour before'),
                selected: _preset == _ReminderPreset.hour1,
                onSelected: _dueDate == null
                    ? null
                    : (_) => _applyPreset(_ReminderPreset.hour1),
              ),
              ChoiceChip(
                label: const Text('1 day before'),
                selected: _preset == _ReminderPreset.day1,
                onSelected: _dueDate == null
                    ? null
                    : (_) => _applyPreset(_ReminderPreset.day1),
              ),
              ChoiceChip(
                label: const Text('Custom'),
                selected: _preset == _ReminderPreset.custom,
                onSelected: (_) async {
                  final picked = await _pickDateTime(
                    requireFuture: true,
                    initial: _reminderAt,
                  );
                  if (picked != null) {
                    setState(() {
                      _reminderAt = picked;
                      _preset = _ReminderPreset.custom;
                    });
                  }
                },
              ),
            ],
          ),
          if (_reminderAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 16,
                  color: LifeHubTheme.nearlyDarkBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  'Remind: ${_fmt(_reminderAt!)}',
                  style: LifeHubTheme.caption,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LifeHubTheme.tasks,
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Task' : 'Add Task'),
            ),
          ),
        ],
      ),
    );
  }
}
