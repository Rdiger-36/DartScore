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
/// The order is not the default and never was: [kDefaultInputSide] decides
/// that, and the values are stored by name, so this list stays free to grow.
enum InputSide { right, left }

/// The side the input starts on until the player says otherwise.
const InputSide kDefaultInputSide = InputSide.left;

/// Whether the window is wide enough for the two pane layouts.
///
/// Deliberately the same rule the orientation lock in `main.dart` applies, so
/// a window that is allowed to rotate is exactly a window that gets a tablet
/// layout. Reads the shortest side, not the width, so a rotation never changes
/// the answer.
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletBreakpoint;

/// Preferred width of the column that holds the scoreboard above the input.
/// It carries the score that is read from across the room, so it needs more
/// than the input alone would.
const double kGamePaneWidth = 640.0;

/// Places the column holding the score input beside a second pane, on the side
/// the user chose.
///
/// [primary] keeps [preferredWidth] where the window allows it and never takes
/// more than half, so a narrow tablet ends up with two even panes instead of
/// one that crowds out the other.
class SidePaneLayout extends StatelessWidget {
  /// The column the input lives in. Sits on the chosen side.
  final Widget primary;

  /// The pane that gets whatever width [primary] leaves over.
  final Widget secondary;

  /// The side [primary] sits on.
  final InputSide side;

  /// Width [primary] takes where there is room for it.
  final double preferredWidth;

  const SidePaneLayout({
    super.key,
    required this.primary,
    required this.secondary,
    required this.side,
    this.preferredWidth = kInputPaneWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width      = min(preferredWidth, constraints.maxWidth / 2);
        final fixedPane  = SizedBox(width: width, child: primary);
        final restPane   = Expanded(child: secondary);
        const divider    = VerticalDivider(width: 1, thickness: 1);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: side == InputSide.right
              ? [restPane, divider, fixedPane]
              : [fixedPane, divider, restPane],
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
