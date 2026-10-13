import '../../../core/constants/app_constants.dart';
import '../../../core/services/local_db.dart';
import '../../../core/utils/formatters.dart';
import '../models/habit.dart';

class HabitsRepository {
  List<HabitModel> getHabits() => LocalDb.box(
    AppConstants.habitsBox,
  ).values.map((m) => HabitModel.fromMap(m as Map)).toList();

  Future<void> saveHabit(HabitModel h) =>
      LocalDb.box(AppConstants.habitsBox).put(h.id, h.toMap());

  Future<void> deleteHabit(String id) =>
      LocalDb.box(AppConstants.habitsBox).delete(id);

  Future<void> toggleDay(HabitModel habit, DateTime day) async {
    final key = Formatters.dayKey(day);
    final days = habit.completedDays.toSet();
    if (days.contains(key)) {
      days.remove(key);
    } else {
      days.add(key);
    }
    final list = days.toList()..sort();
    await saveHabit(habit.copyWith(completedDays: list));
  }
}
