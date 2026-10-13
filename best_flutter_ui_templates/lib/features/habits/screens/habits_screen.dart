import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/lifehub_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../models/habit.dart';
import '../providers/habits_providers.dart';
import 'habit_detail_screen.dart';
import 'habit_form_sheet.dart';

/// Habits tab — grid of habit cards (adapted from the template's
/// area_list_view style) with today's check-off and streak.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final doneToday = habits.where((h) => h.isDoneToday).length;

    return Scaffold(
      backgroundColor: LifeHubTheme.background,
      appBar: AppBar(
        title: const Text('Habits'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LifeHubTheme.habits,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Habit', style: TextStyle(color: Colors.white)),
        onPressed: () => showHabitFormSheet(context),
      ),
      body: habits.isEmpty
          ? const EmptyState(
              message: 'No habits yet.\nBuild your first daily habit!',
              icon: Icons.repeat,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: LifeHubTheme.cardDecoration,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: LifeHubTheme.tasks,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$doneToday of ${habits.length} habits done today',
                            style: LifeHubTheme.subtitle,
                          ),
                        ),
                        Text(
                          '${habits.isEmpty ? 0 : (doneToday / habits.length * 100).toStringAsFixed(0)}%',
                          style: LifeHubTheme.title,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ).copyWith(bottom: 90),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                    itemCount: habits.length,
                    itemBuilder: (context, i) => FadeSlideIn.item(
                      index: i,
                      child: _HabitCard(habit: habits[i]),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit});

  final HabitModel habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = habit.isDoneToday;
    final color = Color(habit.colorValue);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habit.id)),
      ),
      child: Container(
        decoration: LifeHubTheme.cardDecoration,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(habitIcon(habit.icon), color: color),
                ),
                const Spacer(),
                InkWell(
                  onTap: () =>
                      ref.read(habitsProvider.notifier).toggleToday(habit),
                  borderRadius: BorderRadius.circular(20),
                  child: Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    color: done ? color : LifeHubTheme.deactivatedText,
                    size: 30,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              habit.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: LifeHubTheme.subtitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: LifeHubTheme.tasks,
                ),
                Text(
                  ' ${habit.streak} day streak',
                  style: LifeHubTheme.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
