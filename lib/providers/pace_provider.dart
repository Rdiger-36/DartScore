import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bot_runner.dart';

/// Holds the [GamePace] the reader picked and persists it across launches.
///
/// The pace itself is read by the game providers through [TurnPacing], which
/// this provider keeps in step: they do not depend on each other, and a game
/// already running follows a change at its next visit.
class PaceProvider extends ChangeNotifier {
  static const _key = 'game_pace';

  GamePace _pace = GamePace.normal;

  /// The pace games move at.
  GamePace get pace => _pace;

  /// Creates the provider and asynchronously loads the persisted pace.
  PaceProvider() {
    _load();
  }

  /// Reads the saved pace, falling back to normal for a reader who never
  /// touched the setting or for a value from a version with other options.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_key);
    if (saved != null && saved >= 0 && saved < GamePace.values.length) {
      _pace = GamePace.values[saved];
    }
    TurnPacing.pace = _pace;
    notifyListeners();
  }

  /// Sets the pace, hands it to the game providers and writes it down.
  Future<void> setPace(GamePace pace) async {
    if (pace == _pace) return;
    _pace = pace;
    TurnPacing.pace = pace;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, pace.index);
  }
}
