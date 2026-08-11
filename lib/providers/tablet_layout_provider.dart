import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/layout.dart';

/// Holds how the tablet layout of the live game is arranged: which side of the
/// screen the score input sits on, and how the width is divided between it and
/// the pane beside it. Both persist across launches.
///
/// These only ever apply to a layout that puts two panes side by side, which is
/// a tablet. A phone is portrait only and stacks its rows, so the values are
/// loaded but never read there.
class TabletLayoutProvider extends ChangeNotifier {
  static const _sideKey  = 'input_side';
  static const _splitKey = 'tablet_split_fraction';

  InputSide _side = kDefaultInputSide;
  double _splitFraction = kDefaultSplitFraction;

  /// The side the input sits on.
  InputSide get side => _side;

  /// Share of the width the pane holding the input takes, between
  /// [kMinSplitFraction] and [kMaxSplitFraction].
  double get splitFraction => _splitFraction;

  /// Creates the provider and asynchronously loads both settings.
  TabletLayoutProvider() {
    _load();
  }

  /// Reads the saved values from shared_preferences, keeping the defaults when
  /// nothing was ever stored or the stored side is not one of the values.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final savedSide = prefs.getString(_sideKey);
    if (savedSide != null) {
      _side = InputSide.values.firstWhere(
        (s) => s.name == savedSide,
        orElse: () => kDefaultInputSide,
      );
    }

    final savedSplit = prefs.getDouble(_splitKey);
    if (savedSplit != null) {
      _splitFraction =
          savedSplit.clamp(kMinSplitFraction, kMaxSplitFraction).toDouble();
    }

    if (savedSide != null || savedSplit != null) notifyListeners();
  }

  /// Moves the input to [side], notifies listeners and persists the choice.
  ///
  /// Stored by name rather than by index so the enum stays free to grow.
  Future<void> setSide(InputSide side) async {
    if (side == _side) return;
    _side = side;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sideKey, side.name);
  }

  /// Moves the divider so the input pane takes [fraction] of the width.
  ///
  /// A drag calls this on every frame, so it only notifies; the result reaches
  /// disk through [persistSplitFraction] once the gesture is over.
  void setSplitFraction(double fraction) {
    final clamped =
        fraction.clamp(kMinSplitFraction, kMaxSplitFraction).toDouble();
    if (clamped == _splitFraction) return;
    _splitFraction = clamped;
    notifyListeners();
  }

  /// Writes the split down as it currently stands.
  Future<void> persistSplitFraction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_splitKey, _splitFraction);
  }
}
