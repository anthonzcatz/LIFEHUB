import 'dart:async';

import 'package:flutter/services.dart';

/// Copy helper for sensitive values (vault passwords, generated secrets).
/// Schedules a clipboard wipe after [clearAfter]; the wipe only fires when
/// the clipboard still holds the value we wrote, so a newer copy is kept.
class ClipboardUtils {
  ClipboardUtils._();

  static const defaultClearAfter = Duration(seconds: 60);

  static Future<void> copySensitive(
    String value, {
    Duration clearAfter = defaultClearAfter,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    Timer(clearAfter, () async {
      try {
        final current = await Clipboard.getData('text/plain');
        if (current?.text == value) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });
  }
}
