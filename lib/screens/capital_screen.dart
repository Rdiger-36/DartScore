import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/capital_provider.dart';
import '../utils/capital_rules.dart';
import '../utils/dartboard_geometry.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../utils/player_label.dart';
import '../utils/segment_color.dart';
import '../utils/visit_darts.dart';
import '../widgets/visit_darts_row.dart';
import '../widgets/visit_pause.dart';
import 'capital_summary_screen.dart';
import 'capital_live_info_screen.dart';

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
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 1, label: Text(l.single)),
            ButtonSegment(value: 2, label: Text(l.double_)),
            ButtonSegment(value: 3, label: Text(l.triple)),
          ],
          selected: {_multiplier},
          onSelectionChanged: (s) => setState(() => _multiplier = s.first),
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: 10)),
            // The chosen segment wears the color the app marks that ring by,
            // as the X01 switch does.
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? _ringColor(context)
                    : null),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? _onRingColor(context)
                    : null),
          ),
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

  /// The tint the chosen ring segment wears.
  ///
  /// The app's own marks for a multiplied field, green for a double and blue
  /// for a triple, not the board's red and green: the board paints a double
  /// and a triple alike, so those two could not tell the segments apart.
  Color _ringColor(BuildContext context) => switch (_multiplier) {
        2 => doubleContainerColor(context),
        3 => tripleContainerColor(context),
        _ => Theme.of(context).colorScheme.surfaceContainerHigh,
      };

  /// Foreground for [_ringColor].
  Color _onRingColor(BuildContext context) => switch (_multiplier) {
        2 => onDoubleContainerColor(context),
        3 => onTripleContainerColor(context),
        _ => Theme.of(context).colorScheme.onSurface,
      };

  /// One board button, painted the way that field is painted on the board.
  ///
  /// The twenty numbers follow the ring the selector is on, so switching to
  /// Double or Triple repaints them red and green. The two bulls keep their
  /// own colors, and a miss is not a field at all so it stays on the surface.
  /// A rounded rectangle rather than a pill, and the number over what the dart
  /// would be worth, both as the X01 input draws a field.
  Widget _button(
    BuildContext context,
    String label,
    BoardHit hit,
    VoidCallback? onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    final t  = Theme.of(context).textTheme;
    final color = colorOf(hit);
    final (background, foreground) = color == null
        ? (cs.surfaceContainerHighest, cs.onSurfaceVariant)
        : boardPaintFor(color);
    final disabled = onTap == null;
    final bg = disabled ? background.withValues(alpha: 0.35) : background;
    final fg = disabled ? foreground.withValues(alpha: 0.5) : foreground;

    return Material(
      color: bg,
      // The outline keeps a cream key off a light background and a black key
      // off a dark one, so it earns its place in both themes. A hair under one
      // logical pixel rendered with visible breaks around the curve, so it is
      // a full one.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: BoardPaint.wire, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(
                label,
                style: t.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: fg),
              ),
            ),
            // What the dart is worth, for the twenty numbers under a
            // multiplied ring. The bulls and the miss carry one value each, so
            // naming it under the label would only repeat the label.
            if (hit.multiplier > 1 && hit.field != 25)
              Text(
                '${scoreOf(hit)}',
                style: t.labelSmall?.copyWith(
                  color: fg.withValues(alpha: 0.7),
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the live numbers of the Capital slot at [slotIndex]: its last three
/// visits and what the game has come to for it so far.
void openCapitalSlotInfo(BuildContext context, int slotIndex) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => CapitalLiveInfoScreen(
      provider:  context.read<CapitalProvider>(),
      slotIndex: slotIndex,
    ),
  ));
}
