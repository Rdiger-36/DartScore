import 'package:flutter/material.dart';

import '../utils/layout.dart';

/// The body of a post-game summary: how the game ended on one side, the numbers
/// behind it on the other, and the way out under both.
///
/// A phone, and a tablet too narrow to divide, get the single column the four
/// summaries have always been: [result], [details] and [footer] in that order,
/// with the same gap between the two blocks that used to sit there by hand.
///
/// The divider stands in the middle and stays there. Both columns hold cards of
/// the same kind, so there is nothing to rebalance between them.
class SummaryBody extends StatelessWidget {
  /// How the game ended: the winner, the rematch, and what was played.
  final List<Widget> result;

  /// The numbers behind it: the per player cards and whatever a mode keeps
  /// beside them, which is the longer of the two columns.
  final List<Widget> details;

  /// The way back out. Under both columns rather than at the end of one,
  /// because two columns that scroll on their own have no shared end.
  final Widget footer;

  /// Padding above and below the columns. X01 sits closer to its app bar than
  /// the three modes whose summary opens on a winner banner.
  final double top;
  final double bottom;

  const SummaryBody({
    super.key,
    required this.result,
    required this.details,
    required this.footer,
    this.top = 16,
    this.bottom = 16,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (!isTabletLayout(context) ||
        !fitsTwoPanes(width, kMinSummaryPaneWidth)) {
      return ListView(
        padding: contentPadding(context, top: top, bottom: bottom, innerH: 16),
        children: [
          ...result,
          const SizedBox(height: 16),
          ...details,
          const SizedBox(height: 24),
          footer,
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: SidePaneLayout(
            side: InputSide.left,
            minPaneWidth: kMinSummaryPaneWidth,
            primary: ListView(
              padding: EdgeInsets.fromLTRB(16, top, 8, bottom),
              children: result,
            ),
            secondary: ListView(
              padding: EdgeInsets.fromLTRB(8, top, 16, bottom),
              children: details,
            ),
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 3,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              // The button keeps a width it can be read as a button at rather
              // than the width of the room.
              child: Center(
                child: SizedBox(width: kMinSummaryPaneWidth, child: footer),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
