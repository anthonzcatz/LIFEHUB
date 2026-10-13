import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/lifehub_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/habits_providers.dart';

/// Habit detail — streak stats + monthly progress calendar where
/// past days can be toggled.
class HabitDetailScreen extends ConsumerStatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final habit = habits.where((h) => h.id == widget.habitId).firstOrNull;
    if (habit == null) {
      return const Scaffold(body: Center(child: Text('Habit not found')));
    }
    final color = Color(habit.colorValue);
    final doneSet = habit.completedDays.toSet();

    // Build the calendar grid for _month
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    final cells = <DateTime?>[
      for (var i = 0; i < startWeekday; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_month.year, _month.month, d),
    ];

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: Text(habit.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref, habit.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats row
          Row(
            children: [
              _StatCard(
                label: 'Streak',
                value: '${habit.streak} days',
                icon: Icons.local_fire_department,
                color: LifeHubTheme.tasks,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Total',
                value: '${habit.completedDays.length} days',
                icon: Icons.check_circle_outline,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar card
          Container(
            decoration: LifeHubTheme.cardDecoration,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                    ),
                    Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: LifeHubTheme.title,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (d) => SizedBox(
                          width: 36,
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: LifeHubTheme.caption,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: cells.map((day) {
                    if (day == null) return const SizedBox();
                    final isDone = doneSet.contains(Formatters.dayKey(day));
                    final isFuture = day.isAfter(DateTime.now());
                    return GestureDetector(
                      onTap: isFuture
                          ? null
                          : () => ref
                                .read(habitsProvider.notifier)
                                .toggleDay(habit, day),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDone
                              ? color
                              : isFuture
                              ? Colors.transparent
                              : LifeHubTheme.spacer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDone
                                  ? Colors.white
                                  : isFuture
                                  ? LifeHubTheme.deactivatedText
                                  : LifeHubTheme.darkText,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap a day to mark/unmark it',
                  style: LifeHubTheme.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: const Text('This will remove the habit and its history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(habitsProvider.notifier).remove(id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: LifeHubTheme.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: LifeHubTheme.title),
            Text(label, style: LifeHubTheme.caption),
          ],
        ),
      ),
    );
  }
}
