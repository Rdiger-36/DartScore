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

/// Share of the width the pane holding the input starts with, and the range a
/// drag of the divider may move it to.
const double kDefaultSplitFraction = 0.5;
const double kMinSplitFraction     = 0.3;
const double kMaxSplitFraction     = 0.7;

/// Width of the draggable divider between two panes. Wide enough to grab,
/// while the line drawn inside it stays hairline thin.
const double kDividerHitWidth = 16.0;

/// Identifies the divider between two panes, for tests that drag it.
const Key kPaneDividerKey = Key('pane-divider');

/// Places the column holding the score input beside a second pane, on the side
/// the user chose, with a divider that can be dragged to rebalance the two.
///
/// [fraction] is the share [primary] takes of the width. The divider reports a
/// new one through [onFractionChanged] while it is dragged and calls
/// [onFractionSettled] once the gesture ends, which is where a caller writes
/// the result down: a drag must not do that on every frame.
class SidePaneLayout extends StatelessWidget {
  /// The column the input lives in. Sits on the chosen side.
  final Widget primary;

  /// The pane that gets whatever width [primary] leaves over.
  final Widget secondary;

  /// The side [primary] sits on.
  final InputSide side;

  /// Share of the width [primary] takes.
  final double fraction;

  /// Called with the new share while the divider is dragged.
  final ValueChanged<double>? onFractionChanged;

  /// Called once the drag is over, with no value: the caller holds the current
  /// one already, and recomputing it here would read a width from a frame the
  /// drag has since moved past.
  final VoidCallback? onFractionSettled;

  const SidePaneLayout({
    super.key,
    required this.primary,
    required this.secondary,
    required this.side,
    this.fraction = kDefaultSplitFraction,
    this.onFractionChanged,
    this.onFractionSettled,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final width = (total * fraction).clamp(
          total * kMinSplitFraction,
          total * kMaxSplitFraction,
        );

        // A drag moves the divider itself, so the sign follows the side the
        // input is on: dragging right grows a pane on the left and shrinks one
        // on the right.
        void onDrag(double dx) {
          final delta = side == InputSide.left ? dx : -dx;
          onFractionChanged?.call((width + delta) / total);
        }

        final fixedPane = SizedBox(width: width, child: primary);
        final restPane  = Expanded(child: secondary);
        final divider   = _PaneDivider(
          key: kPaneDividerKey,
          onDrag: onFractionChanged == null ? null : onDrag,
          onDragEnd: onFractionSettled,
        );

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

/// The line between two panes, and the grip that drags it.
///
/// The touch target is [kDividerHitWidth] wide because a hairline is not
/// something a finger can find; the line inside it stays one pixel.
class _PaneDivider extends StatelessWidget {
  /// Reports the horizontal movement of the drag. Null leaves the divider as a
  /// plain line.
  final ValueChanged<double>? onDrag;

  /// Reports that the drag is over.
  final VoidCallback? onDragEnd;

  const _PaneDivider({super.key, this.onDrag, this.onDragEnd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final line = Center(
      child: Container(width: 1, color: cs.outlineVariant),
    );

    if (onDrag == null) {
      return SizedBox(width: kDividerHitWidth, child: line);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag!(d.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: kDividerHitWidth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              line,
              // The grip, so the divider looks like something that can be moved.
              Container(
                width: 4,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
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
