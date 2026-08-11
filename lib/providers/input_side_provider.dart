import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/layout.dart';

/// Holds which side of a tablet screen the score input sits on and persists it
/// across launches.
///
/// The setting only ever shows up in a layout that puts the input beside a
/// second pane, which is a tablet. A phone is portrait only and stacks its
/// rows, so the value is loaded but never read there.
class InputSideProvider extends ChangeNotifier {
  static const _key = 'input_side';

  InputSide _side = kDefaultInputSide;

  /// The side the input sits on.
  InputSide get side => _side;

  /// Creates the provider and asynchronously loads the persisted side.
  InputSideProvider() {
    _load();
  }

  /// Reads the saved side from shared_preferences, keeping the default when
  /// nothing was ever stored or the stored name is not one of the values.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    _side = InputSide.values.firstWhere(
      (s) => s.name == saved,
      orElse: () => kDefaultInputSide,
    );
    notifyListeners();
  }

  /// Moves the input to [side], notifies listeners and persists the choice.
  ///
  /// Stored by name rather than by index so the enum stays free to grow.
  Future<void> setSide(InputSide side) async {
    if (side == _side) return;
    _side = side;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, side.name);
  }
}
