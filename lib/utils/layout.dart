import 'dart:math' show min;
import 'package:flutter/material.dart';

/// Screen width threshold (dp) above which tablet layout is applied.
const double kTabletBreakpoint = 600;

/// Maximum content width on tablets/large screens: matches a typical
/// portrait-phone width so the layout doesn't stretch across wide screens.
const double kMaxContentWidth = 440.0;

/// Maximum width for the game screen: slightly wider to fit scoreboard
/// and input comfortably on tablets.
const double kMaxGameWidth = 500.0;

// Legacy fraction constants kept for callers that pass them explicitly.
// They are no longer used by contentMaxWidth on phones; on tablets the
// kMax* constants take effect instead.
const double kContentWidthFraction = 0.85;
const double kGameWidthFraction = 0.95;

/// Preferred width of the score input when it shares the screen with a second
/// pane. Wider buttons do not make a tap more accurate, they only lengthen the
/// way to the next one, so the input keeps roughly its phone size and the space
/// that is won goes to the pane beside it.
const double kInputPaneWidth = 440.0;

/// Widest the live stats read comfortably. Beyond this a label and its value
/// drift so far apart that the pair stops reading as one row.
const double kStatsPaneMaxWidth = 600.0;

/// Which side of the screen the score input sits on when a second pane shares
/// it with them.
///
/// [right] is index 0 because it is the default and describes how the layout
/// looked before the setting existed.
enum InputSide { right, left }

/// Whether the window is wide enough for the two pane layouts.
///
/// Deliberately the same rule the orientation lock in `main.dart` applies, so
/// a window that is allowed to rotate is exactly a window that gets a tablet
/// layout. Reads the shortest side, not the width, so a rotation never changes
/// the answer.
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;

/// Places the score input beside a second pane, on the side the user chose.
///
/// The input keeps [kInputPaneWidth] where the window allows it and never takes
/// more than half, so a narrow tablet ends up with two even panes instead of an
/// input that crowds out what it sits next to.
class SidePaneLayout extends StatelessWidget {
  /// The pane that gets whatever width the input leaves over.
  final Widget info;

  /// The score input.
  final Widget input;

  /// The side the input sits on.
  final InputSide side;

  const SidePaneLayout({
    super.key,
    required this.info,
    required this.input,
    required this.side,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inputWidth = min(kInputPaneWidth, constraints.maxWidth / 2);
        final inputPane  = SizedBox(width: inputWidth, child: input);
        final infoPane   = Expanded(child: info);
        const divider    = VerticalDivider(width: 1, thickness: 1);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: side == InputSide.right
              ? [infoPane, divider, inputPane]
              : [inputPane, divider, infoPane],
        );
      },
    );
  }
}

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
