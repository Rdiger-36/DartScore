import 'dart:math' show min;
import 'package:flutter/material.dart';

/// Screen width threshold (dp) above which tablet layout is applied.
const double kTabletBreakpoint = 600;

/// Maximum content width on tablets/large screens — matches a typical
/// portrait-phone width so the layout doesn't stretch across wide screens.
const double kMaxContentWidth = 440.0;

/// Maximum width for the game screen — slightly wider to fit scoreboard
/// and input comfortably on tablets.
const double kMaxGameWidth = 500.0;

// Legacy fraction constants kept for callers that pass them explicitly.
// They are no longer used by contentMaxWidth on phones; on tablets the
// kMax* constants take effect instead.
const double kContentWidthFraction = 0.85;
const double kGameWidthFraction = 0.95;

/// Max content width in dp for the current screen.
/// On phones (< 600 dp) the full screen width is used.
/// On tablets the width is capped at [maxWidth] to preserve a phone-portrait
/// feel and avoid overly wide content columns.
double contentMaxWidth(
  BuildContext context, {
  double fraction = kContentWidthFraction, // ignored on tablets
  double maxWidth = kMaxContentWidth,
}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < kTabletBreakpoint) return w;
  return min(w * fraction, maxWidth);
}

/// Symmetric horizontal padding so a full-width ListView centres its content.
/// On phones the padding equals [innerH] only (no extra side margins).
EdgeInsets contentPadding(
  BuildContext context, {
  double fraction = kContentWidthFraction,
  double maxWidth = kMaxContentWidth,
  double top = 0,
  double bottom = 0,
  double innerH = 0,
}) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < kTabletBreakpoint) {
    return EdgeInsets.fromLTRB(innerH, top, innerH, bottom);
  }
  final contentW = min(w * fraction, maxWidth);
  final side = ((w - contentW) / 2).clamp(0.0, double.infinity);
  return EdgeInsets.fromLTRB(side + innerH, top, side + innerH, bottom);
}
