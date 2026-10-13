import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub/core/services/notification_service.dart';

void main() {
  test(
    'past one-off reminders are rejected without requesting permissions',
    () async {
      final result = await NotificationService.scheduleReminder(
        id: 'past-task',
        title: 'Task Reminder',
        body: 'You have a task due.',
        when: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(result.status, ReminderScheduleStatus.invalidTime);
      expect(result.scheduled, isFalse);
    },
  );

  test('invalid daily reminder time is rejected', () async {
    final result = await NotificationService.scheduleDailyReminder(
      id: 'invalid-daily',
      title: 'Habit Reminder',
      body: 'Check your habits.',
      hour: 24,
      minute: 0,
    );

    expect(result.status, ReminderScheduleStatus.invalidTime);
  });
}
