import 'package:flutter/material.dart';

/// Shared blue tones used to mark triple fields across all game screens.
/// Originates from the X01 checkout-hint container colors so the "a checkout
/// is reachable" affordance and the triple-field affordance read consistently.
const _blueContainerLight = Color(0xFFBBDEFB); // blue 100
const _blueOnContainerLight = Color(0xFF0D47A1); // blue 900
const _blueContainerDark = Color(0xFF1565C0); // blue 800
const _blueOnContainerDark = Color(0xFFBBDEFB); // blue 100

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
