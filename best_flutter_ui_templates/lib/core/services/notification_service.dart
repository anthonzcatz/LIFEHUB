import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

enum ReminderScheduleStatus {
  exact,
  inexact,
  permissionDenied,
  invalidTime,
  failed,
}

class ReminderScheduleResult {
  const ReminderScheduleResult(this.status);

  final ReminderScheduleStatus status;

  bool get scheduled =>
      status == ReminderScheduleStatus.exact ||
      status == ReminderScheduleStatus.inexact;
}

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _reminderChannel = AndroidNotificationDetails(
    'lifehub_reminders',
    'Reminders',
    channelDescription: 'Task and habit reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _details = NotificationDetails(
    android: _reminderChannel,
    iOS: DarwinNotificationDetails(),
  );

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    // Use the real device timezone — without this, tz.local defaults to
    // UTC and reminders fire at the wrong time.
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Keep default location if the platform lookup fails.
    }

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  static int _idFromString(String value) {
    final digest = sha256.convert(utf8.encode(value)).bytes;
    final id =
        ((digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3]) &
        0x7FFFFFFF;
    return id == 0 ? 1 : id;
  }

  static Future<bool> _requestPermissions() async {
    if (!_initialized) await init();
    final android = _android;
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      if (enabled != true) {
        final granted = await android.requestNotificationsPermission();
        if (granted == false) return false;
      }
      return true;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) !=
          false;
    }
    final macos = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (macos != null) {
      return await macos.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) !=
          false;
    }
    return true;
  }

  static Future<AndroidScheduleMode> _scheduleMode() async {
    try {
      final canExact = await _android?.canScheduleExactNotifications();
      if (canExact == false) return AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {}
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  static Future<ReminderScheduleResult> scheduleReminder({
    required String id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    try {
      if (!when.isAfter(DateTime.now())) {
        return const ReminderScheduleResult(ReminderScheduleStatus.invalidTime);
      }
      if (!await _requestPermissions()) {
        return const ReminderScheduleResult(
          ReminderScheduleStatus.permissionDenied,
        );
      }
      final mode = await _scheduleMode();
      await _plugin.zonedSchedule(
        _idFromString(id),
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
      );
      return ReminderScheduleResult(
        mode == AndroidScheduleMode.exactAllowWhileIdle
            ? ReminderScheduleStatus.exact
            : ReminderScheduleStatus.inexact,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleReminder failed: $e');
      return const ReminderScheduleResult(ReminderScheduleStatus.failed);
    }
  }

  static Future<ReminderScheduleResult> scheduleDailyReminder({
    required String id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const ReminderScheduleResult(ReminderScheduleStatus.invalidTime);
    }
    try {
      if (!await _requestPermissions()) {
        return const ReminderScheduleResult(
          ReminderScheduleStatus.permissionDenied,
        );
      }
      final now = DateTime.now();
      var when = DateTime(now.year, now.month, now.day, hour, minute);
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      final mode = await _scheduleMode();
      await _plugin.zonedSchedule(
        _idFromString(id),
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        _details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return ReminderScheduleResult(
        mode == AndroidScheduleMode.exactAllowWhileIdle
            ? ReminderScheduleStatus.exact
            : ReminderScheduleStatus.inexact,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleDailyReminder failed: $e');
      return const ReminderScheduleResult(ReminderScheduleStatus.failed);
    }
  }

  static Future<bool> showTestNotification() async {
    try {
      if (!await _requestPermissions()) return false;
      await _plugin.show(
        0,
        'LifeHub test',
        'Notifications are working.',
        _details,
      );
      return true;
    } catch (e) {
      debugPrint('NotificationService.showTestNotification failed: $e');
      return false;
    }
  }

  static Future<void> cancel(String id) async {
    try {
      if (!_initialized) await init();
      await _plugin.cancel(_idFromString(id));
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    try {
      if (!_initialized) await init();
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
