import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_utils.dart';

import '../data/habits_repository.dart';
import '../models/habit.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>(
  (ref) => HabitsRepository(),
);

class HabitsNotifier extends Notifier<List<HabitModel>> {
  @override
  List<HabitModel> build() => ref.read(habitsRepositoryProvider).getHabits();

  Future<void> add({
    required String name,
    String icon = 'other',
    int colorValue = 0xFF7B61FF,
    String description = '',
  }) async {
    await ref
        .read(habitsRepositoryProvider)
        .saveHabit(
          HabitModel(
            id: newId(),
            name: name,
            icon: icon,
            colorValue: colorValue,
            description: description,
            createdAt: DateTime.now(),
          ),
        );
    state = ref.read(habitsRepositoryProvider).getHabits();
  }

  Future<void> toggleToday(HabitModel habit) async {
    await ref.read(habitsRepositoryProvider).toggleDay(habit, DateTime.now());
    state = ref.read(habitsRepositoryProvider).getHabits();
  }

  Future<void> toggleDay(HabitModel habit, DateTime day) async {
    await ref.read(habitsRepositoryProvider).toggleDay(habit, day);
    state = ref.read(habitsRepositoryProvider).getHabits();
  }

  Future<void> remove(String id) async {
    await ref.read(habitsRepositoryProvider).deleteHabit(id);
    state = ref.read(habitsRepositoryProvider).getHabits();
  }
}

final habitsProvider = NotifierProvider<HabitsNotifier, List<HabitModel>>(
  HabitsNotifier.new,
);
