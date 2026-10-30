import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/capital_provider.dart';
import '../utils/capital_rules.dart';
import '../utils/capital_stats.dart';
import '../utils/dartboard_geometry.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../utils/player_label.dart';
import '../utils/segment_color.dart';
import '../utils/visit_darts.dart';
import '../widgets/visit_darts_row.dart';
import '../widgets/visit_pause.dart';
import 'capital_summary_screen.dart';
import 'mode_live_info_screen.dart';

/// The live Capital screen: the capitals, the contract band, the visit and the
/// board input.
class CapitalScreen extends StatelessWidget {
  const CapitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = context.watch<CapitalProvider>();
    if (provider.game == null) return const Scaffold(body: SizedBox.shrink());

    // A finished game goes straight to its summary, the way every other mode
    // does, rather than leaving the board on screen with nothing left to do.
    if (provider.gameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CapitalSummaryScreen()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.modeCapitalName),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _confirmQuit(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: provider.canUndo ? provider.undoLastDart : null,
            ),
          ],
        ),
        body: SafeArea(child: _body(context, provider, l)),
      ),
    );
  }

  /// The board, the contract and the keypad, arranged for the window.
  ///
  /// A landscape tablet divides: the keypad is the tall thing and gets a pane
  /// of its own, which leaves the capitals and the contract the full height
  /// beside it rather than squeezed above it. Everything narrower keeps the
  /// single column, where the keypad still has to reach the bottom of the
  /// screen.
  Widget _body(
      BuildContext context, CapitalProvider provider, AppLocalizations l) {
    final tablet = isTabletLayout(context);
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width >= size.height;

    final visit = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: provider.visitPending ? provider.flushHeldVisit : null,
      child: VisitDartsRow(
        darts: [
          for (final dart in provider.visitBuffer)
            visitDartFrom(dart.field, dart.multiplier, l),
        ],
      ),
    );

    if (tablet && landscape) {
      return SidePaneLayout(
        side: InputSide.left,
        primary: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: _CapitalInput(provider: provider),
        ),
        secondary: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Column(
            children: [
              _Scoreboard(provider: provider),
              const SizedBox(height: 8),
              _ContractBand(provider: provider),
              const SizedBox(height: 8),
              visit,
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: contentPadding(context, top: 8, bottom: 8, innerH: 12),
      child: Column(
        children: [
          _Scoreboard(provider: provider),
          const SizedBox(height: 8),
          _ContractBand(provider: provider),
          const SizedBox(height: 8),
          visit,
          const SizedBox(height: 8),
          Expanded(child: _CapitalInput(provider: provider)),
        ],
      ),
    );
  }

  /// Asks before abandoning a game in progress, as every other mode does.
  void _confirmQuit(BuildContext context) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: AlertDialog(
            title: Text(l.quitTitle),
            content: Text(l.quitBody),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l.cancel)),
              FilledButton(
                onPressed: () {
                  context.read<CapitalProvider>().leaveGame();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: Text(l.leave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The capitals, one compact row per player.
///
/// Only one row shows its arithmetic at a time, because eight rows each
/// carrying a second line do not fit beside a keypad. By default it is the
/// slot that just threw, which is the sum worth reading; tapping any other
/// player shows theirs instead, and tapping it again hands the scoreboard
/// back to whoever throws next.
class _Scoreboard extends StatefulWidget {
  final CapitalProvider provider;
  const _Scoreboard({required this.provider});

  @override
  State<_Scoreboard> createState() => _ScoreboardState();
}

class _ScoreboardState extends State<_Scoreboard> {
  /// The slot the reader pinned, or null to follow whoever threw last.
  int? _pinned;

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final shown = _pinned ?? provider.lastSettledIndex;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final (index, slot) in provider.playerStates.indexed)
              _SlotRow(
                slot: slot,
                onTurn: index == provider.currentPlayerIndex,
                showExpression: index == shown,
                pinned: index == _pinned,
                onOpenInfo:  () => openCapitalSlotInfo(context, index),
                onTogglePin: () => setState(
                    () => _pinned = _pinned == index ? null : index),
              ),
          ],
        ),
      ),
    );
  }
}

/// One scoreboard row: who, what they hold, and the sum when it is their turn
/// to be read.
class _SlotRow extends StatelessWidget {
  final CapitalPlayerState slot;
  final bool onTurn;
  final bool showExpression;
  final bool pinned;

  /// Opens the slot's live numbers, from a tap on the name as every other mode
  /// opens its own.
  final VoidCallback onOpenInfo;

  /// Shows this slot's arithmetic in place of the last thrower's, from a tap on
  /// the score that arithmetic produced.
  final VoidCallback onTogglePin;

  const _SlotRow({
    required this.slot,
    required this.onTurn,
    required this.showExpression,
    required this.pinned,
    required this.onOpenInfo,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final expression = capitalScoreExpression(
      totalBefore: slot.totalBefore,
      total:       slot.total,
      met:         slot.lastRoundMet,
      darts:       slot.lastVisit,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: onTurn ? cs.primary.withValues(alpha: 0.08) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                child: onTurn
                    ? Icon(Icons.play_arrow, size: 14, color: cs.primary)
                    : null,
              ),
              Expanded(
                child: InkWell(
                  onTap: onOpenInfo,
                  child: Text(
                    slot.label(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: onTurn ? cs.primary : null,
                      fontWeight: onTurn ? FontWeight.bold : null,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: onTogglePin,
                child: Padding(
                  // Slop around the number, which is a far smaller target than
                  // the name beside it. No vertical padding: the scoreboard has
                  // to hold eight rows.
                  padding: const EdgeInsets.only(left: 10, right: 2),
                  child: Row(
                    children: [
                      if (pinned)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.push_pin, size: 12,
                              color: cs.onSurfaceVariant),
                        ),
                      Text(
                        '${slot.total}',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showExpression && expression != null)
            Padding(
              padding: const EdgeInsets.only(left: 18, bottom: 2),
              child: Text(
                expression,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: slot.lastRoundMet == false
                      ? cs.error
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The contract band: which round this is, what it asks, and what the visit
/// still needs once darts have landed.
class _ContractBand extends StatelessWidget {
  final CapitalProvider provider;
  const _ContractBand({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final contract = provider.contract;
    final met = provider.contractMet && contract != CapitalContract.capital;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.capitalRoundLabel(provider.currentRound),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  capitalContractName(l, contract),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              // The keypad is already green, so a met contract is marked by
              // the check alone rather than by tinting the whole band. Green
              // rather than the brand red, which reads as a failure.
              if (met)
                Icon(Icons.check_circle,
                    size: 20, color: onDoubleContainerColor(context)),
            ],
          ),
          Text(
            capitalProgressLine(l, contract, provider.visitHits),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The board input: a ring modifier, the twenty numbers, both bulls and a miss.
///
/// Capital judges where a dart actually landed rather than whether it hit a
/// named target, so unlike Shanghai it needs the whole board rather than a
/// multiplier alone.
/// The height of the keypad's bottom row, stated rather than left to the
/// button's own defaults, because the Continue button that takes its place has
/// to stand exactly as tall.
const double _keyRowHeight = 48;

class _CapitalInput extends StatefulWidget {
  final CapitalProvider provider;
  const _CapitalInput({required this.provider});

  @override
  State<_CapitalInput> createState() => _CapitalInputState();
}

class _CapitalInputState extends State<_CapitalInput> {
  /// The ring the next number tapped lands in, which resets after each dart.
  int _multiplier = 1;

  Future<void> _record(BoardHit hit) async {
    await widget.provider.recordDart(hit);
    if (mounted) setState(() => _multiplier = 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locked = widget.provider.inputLocked;

    return Column(
      children: [
        Row(
          children: [
            _ring(context, l.single, 1),
            const SizedBox(width: 6),
            _ring(context, l.double_, 2),
            const SizedBox(width: 6),
            _ring(context, l.triple, 3),
          ],
        ),
        const SizedBox(height: 6),
        // The grid is sized to the space it is given rather than to a fixed
        // aspect ratio, so four rows of five fill the pane exactly and leave
        // no slack between the numbers and the row below them.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const columns = 5;
              const rows = 4;
              const spacing = 6.0;
              final cellWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              final cellHeight =
                  (constraints.maxHeight - spacing * (rows - 1)) / rows;
              // Keys stay close to round. Letting them fill the pane exactly
              // stretched them into lozenges, but clamping them square left a
              // gap above and below, and two gaps read worse than one. A cell
              // slightly taller than wide absorbs nearly all the slack.
              final ratio = (cellWidth / cellHeight).clamp(0.95, 2.2);
              return Center(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: columns,
                  mainAxisSpacing: spacing,
                  crossAxisSpacing: spacing,
                  childAspectRatio: ratio.toDouble(),
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var field = 1; field <= 20; field++)
                      _button(
                        context,
                        '$field',
                        (field: field, multiplier: _multiplier),
                        locked
                            ? null
                            : () => _record(
                                (field: field, multiplier: _multiplier)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // The bulls and the miss are the one row here shaped like the throw
        // buttons the other modes hand over to Continue, and they are locked
        // meanwhile anyway, so the hand finds it where it already was. The
        // button stands as tall as the keys and carries the pause bar under
        // itself, the nine pixels of which the grid above gives up.
        if (widget.provider.visitPending)
          LayoutBuilder(
            builder: (context, constraints) => ContinueButton(
              onPressed: widget.provider.flushHeldVisit,
              width: constraints.maxWidth,
              height: _keyRowHeight,
            ),
          )
        else
          SizedBox(
            height: _keyRowHeight,
            child: Row(
              children: [
                Expanded(
                  child: _button(context, '25', (field: 25, multiplier: 1),
                      locked
                          ? null
                          : () => _record((field: 25, multiplier: 1))),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _button(context, 'Bull', (field: 25, multiplier: 2),
                      locked
                          ? null
                          : () => _record((field: 25, multiplier: 2))),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _button(context, l.miss, boardMiss,
                      locked ? null : () => _record(boardMiss)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// One ring selector, tinted the way a multiplied field is tinted elsewhere.
  ///
  /// The chosen ring is filled and outlined; the others stay on the plain
  /// surface with full strength text, because a faded label reads as disabled
  /// rather than as unselected.
  Widget _ring(BuildContext context, String label, int multiplier) {
    final cs = Theme.of(context).colorScheme;
    final selected = _multiplier == multiplier;
    final (background, foreground) = switch (multiplier) {
      3 => (tripleContainerColor(context), onTripleContainerColor(context)),
      2 => (doubleContainerColor(context), onDoubleContainerColor(context)),
      _ => (cs.secondaryContainer, cs.onSecondaryContainer),
    };
    return Expanded(
      child: FilledButton(
        onPressed: () => setState(() => _multiplier = multiplier),
        style: FilledButton.styleFrom(
          backgroundColor: selected ? background : cs.surface,
          foregroundColor: selected ? foreground : cs.onSurface,
          side: BorderSide(
            color: selected ? foreground : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  /// One board button, painted the way that field is painted on the board.
  ///
  /// The twenty numbers follow the ring the selector is on, so switching to
  /// Double or Triple repaints them red and green. The two bulls keep their
  /// own colors, and a miss is not a field at all so it stays on the surface.
  Widget _button(
    BuildContext context,
    String label,
    BoardHit hit,
    VoidCallback? onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    final color = colorOf(hit);
    final (background, foreground) = color == null
        ? (cs.surfaceContainerHighest, cs.onSurfaceVariant)
        : boardPaintFor(color);

    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.35),
        disabledForegroundColor: foreground.withValues(alpha: 0.5),
        padding: EdgeInsets.zero,
        // The outline keeps a cream key off a light background and a black
        // key off a dark one, so it earns its place in both themes. A hair
        // under one logical pixel rendered with visible breaks around the
        // curve, so it is a full one.
        side: const BorderSide(color: BoardPaint.wire, width: 1),
      ),
      child: FittedBox(child: Text(label)),
    );
  }
}

/// Opens the live numbers of the Capital slot at [slotIndex]: its last three
/// visits and what the game has come to for it so far.
void openCapitalSlotInfo(BuildContext context, int slotIndex) {
  final provider = context.read<CapitalProvider>();
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ModeLiveInfoScreen(
      listenable: provider,
      data: (context) {
        final l      = context.l10n;
        final slot   = provider.playerStates[slotIndex];
        final id     = slot.player.id;
        final throws = provider.throwHistory
            .where((t) => t.playerId == id)
            .toList();
        final stats  = CapitalStats.of(throws);
        final visits = capitalVisits(throws);
        final recent =
            visits.length <= 3 ? visits : visits.sublist(visits.length - 3);
        return (
          title:    slot.label(l),
          subtitle: null,
          visitSlots: CapitalProvider.dartsPerVisit,
          recentVisits: [
            for (final visit in recent.reversed)
              (
                darts: [
                  for (final dart in visit)
                    visitDartFrom(dart.field, dart.multiplier, l),
                ],
                yield: l.pointsN(capitalPointsOfVisit(visit)),
              ),
          ],
          stats: [
            (l.capitalFinalCapital, '${slot.total}'),
            (l.capitalContractsLabel,
                '${stats.contractsMet}/${CapitalContract.contractCount}'),
            (l.capitalTimesHalved, '${stats.timesHalved}'),
            (l.capitalPerVisit, stats.pointsPerVisit.toStringAsFixed(1)),
            (l.bestVisit, l.pointsN(stats.bestVisitPoints)),
            (l.dartsThrown, '${stats.darts}'),
          ],
        );
      },
    ),
  ));
}
