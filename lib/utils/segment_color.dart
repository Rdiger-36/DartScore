import 'package:flutter/material.dart';

import 'dartboard_geometry.dart';

/// Shared tones that mark a multiplied field across all game screens.
/// The blue originates from the X01 checkout-hint container colors so the
/// "a checkout is reachable" affordance and the triple-field affordance read
/// consistently; the green is its double counterpart, taken from the same
/// Material family and shared with the team accent palette.
const _blueContainerLight = Color(0xFFBBDEFB); // blue 100
const _blueOnContainerLight = Color(0xFF0D47A1); // blue 900
const _blueContainerDark = Color(0xFF1565C0); // blue 800
const _blueOnContainerDark = Color(0xFFBBDEFB); // blue 100

const _greenContainerLight = Color(0xFFC8E6C9); // green 100
const _greenOnContainerLight = Color(0xFF1B5E20); // green 900
const _greenContainerDark = Color(0xFF2E7D32); // green 800
const _greenOnContainerDark = Color(0xFFC8E6C9); // green 100

/// Background color for triple-field UI elements (buttons, board segments).
Color tripleContainerColor(BuildContext context) {
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return isDark ? _blueContainerDark : _blueContainerLight;
}

/// Foreground (text/icon) color on top of [tripleContainerColor].
Color onTripleContainerColor(BuildContext context) {
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return isDark ? _blueOnContainerDark : _blueOnContainerLight;
}

/// Background color for double-field UI elements, the green counterpart of
/// [tripleContainerColor].
Color doubleContainerColor(BuildContext context) {
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return isDark ? _greenContainerDark : _greenContainerLight;
}

/// Foreground (text/icon) color on top of [doubleContainerColor].
Color onDoubleContainerColor(BuildContext context) {
  final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
  return isDark ? _greenOnContainerDark : _greenOnContainerLight;
}

/// The paint on a tournament board, as this app draws it.
///
/// Declared once here and used both by the dartboard the app paints and by
/// any control that stands for a field of the board, so a key and the board
/// it represents never drift apart.
abstract final class BoardPaint {
  static const Color black = Color(0xFF1A1A1A);
  static const Color cream = Color(0xFFF5E6C8);
  static const Color red   = Color(0xFFC0392B);
  static const Color green = Color(0xFF1E7A3C);
  static const Color wire  = Color(0xFFC2C9D1);
}

/// The paint for [color] and a foreground legible on it.
(Color, Color) boardPaintFor(BoardColor color) => switch (color) {
      BoardColor.black => (BoardPaint.black, BoardPaint.cream),
      BoardColor.white => (BoardPaint.cream, BoardPaint.black),
      BoardColor.red   => (BoardPaint.red,   Colors.white),
      BoardColor.green => (BoardPaint.green, Colors.white),
    };
