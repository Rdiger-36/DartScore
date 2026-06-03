import 'package:flutter/material.dart';

/// Fraction of screen width used for content on tablets.
/// Adjust this single value to change all content widths app-wide.
const double kContentWidthFraction = 0.85;

/// Fraction used for the game screen — allows more space on tablets.
const double kGameWidthFraction = 0.95;

/// Screen width threshold (dp) above which tablet layout is applied.
const double kTabletBreakpoint = 600;

/// Max content width in pixels for the current screen.
/// On phones (< 600dp) the full screen width is used.
double contentMaxWidth(BuildContext context, {double fraction = kContentWidthFraction}) {
  final w = MediaQuery.sizeOf(context).width;
  return w < kTabletBreakpoint ? w : w * fraction;
}

/// Symmetric horizontal padding so a full-width ListView centres its content.
/// On phones the padding equals [innerH] only (no extra side margins).
EdgeInsets contentPadding(
  BuildContext context, {
  double fraction = kContentWidthFraction,
  double top = 0,
  double bottom = 0,
  double innerH = 0,
}) {
  final w = MediaQuery.sizeOf(context).width;
  final side = w < kTabletBreakpoint
      ? 0.0
      : ((1 - fraction) / 2 * w).clamp(0.0, double.infinity);
  return EdgeInsets.fromLTRB(side + innerH, top, side + innerH, bottom);
}
