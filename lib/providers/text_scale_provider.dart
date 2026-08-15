import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/layout.dart';

/// Holds the text size the reader picked and persists it across launches.
///
/// The factor lands on top of the size the system asks for rather than
/// replacing it, and it only takes effect where there is room for it: the app
/// applies it on tablet sized windows, where the screen is read from further
/// away than a phone is.
class TextScaleProvider extends ChangeNotifier {
  static const _key = 'text_scale';

  double _factor = kDefaultTextScale;

  /// The factor the text of the app is multiplied by.
  double get factor => _factor;

  /// Creates the provider and asynchronously loads the persisted factor.
  TextScaleProvider() {
    _load();
  }

  /// Reads the saved factor, falling back to [kDefaultTextScale] for a reader
  /// who never touched the setting or for a value written by a version with a
  /// different range.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null) _factor = _clamp(saved);
    notifyListeners();
  }

  /// Sets the factor and writes it down. Values outside the range are pulled
  /// into it, so no caller can leave the app at a size it cannot be read at.
  Future<void> setFactor(double factor) async {
    final next = _clamp(factor);
    if (next == _factor) return;
    _factor = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, next);
  }

  /// Puts the text back to the size the system asks for.
  Future<void> reset() => setFactor(kDefaultTextScale);

  /// Keeps [factor] inside the range the slider offers.
  double _clamp(double factor) =>
      factor.clamp(kMinTextScale, kMaxTextScale).toDouble();
}
