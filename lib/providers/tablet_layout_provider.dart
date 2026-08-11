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
  static const _sideKey           = 'input_side';
  static const _splitPortraitKey  = 'tablet_split_fraction';
  static const _splitLandscapeKey = 'tablet_split_fraction_landscape';

  InputSide _side = kDefaultInputSide;
  double _splitPortrait  = kDefaultSplitFraction;
  double _splitLandscape = kDefaultSplitFraction;

  /// The side the input sits on.
  InputSide get side => _side;

  /// Share of the width the first pane takes, between [kMinSplitFraction] and
  /// [kMaxSplitFraction].
  ///
  /// Kept per orientation: the two are different screens to divide, and a
  /// split that reads well across a landscape tablet leaves an upright one
  /// with two columns too narrow for what is in them.
  double splitFraction({required bool landscape}) =>
      landscape ? _splitLandscape : _splitPortrait;

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

    final savedPortrait  = prefs.getDouble(_splitPortraitKey);
    final savedLandscape = prefs.getDouble(_splitLandscapeKey);
    if (savedPortrait != null) {
      _splitPortrait =
          savedPortrait.clamp(kMinSplitFraction, kMaxSplitFraction).toDouble();
    }
    if (savedLandscape != null) {
      _splitLandscape =
          savedLandscape.clamp(kMinSplitFraction, kMaxSplitFraction).toDouble();
    }

    if (savedSide != null || savedPortrait != null || savedLandscape != null) {
      notifyListeners();
    }
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

  /// Moves the divider of the given orientation so the first pane takes
  /// [fraction] of the width.
  ///
  /// A drag calls this on every frame, so it only notifies; the result reaches
  /// disk through [persistSplitFraction] once the gesture is over.
  void setSplitFraction(double fraction, {required bool landscape}) {
    final clamped =
        fraction.clamp(kMinSplitFraction, kMaxSplitFraction).toDouble();
    if (clamped == splitFraction(landscape: landscape)) return;
    if (landscape) {
      _splitLandscape = clamped;
    } else {
      _splitPortrait = clamped;
    }
    notifyListeners();
  }

  /// Writes the split of the given orientation down as it currently stands.
  Future<void> persistSplitFraction({required bool landscape}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(
      landscape ? _splitLandscapeKey : _splitPortraitKey,
      splitFraction(landscape: landscape),
    );
  }
}
