import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../services/local_db.dart';
import '../utils/formatters.dart';

/// Reactive mirror of the "hide amounts" privacy setting so every screen
/// that displays money rebuilds immediately when the toggle changes.
class HideAmountsNotifier extends Notifier<bool> {
  @override
  bool build() => Formatters.hideAmounts;

  Future<void> set(bool value) async {
    await LocalDb.settings.put(AppConstants.keyHideAmounts, value);
    state = value;
  }
}

final hideAmountsProvider = NotifierProvider<HideAmountsNotifier, bool>(
  HideAmountsNotifier.new,
);
