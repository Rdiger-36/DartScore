import 'package:flutter/material.dart';

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
