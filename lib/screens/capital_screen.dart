import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/capital_provider.dart';
import '../providers/tablet_layout_provider.dart';
import '../utils/capital_rules.dart';
import '../utils/dartboard_geometry.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../utils/player_label.dart';
import '../utils/segment_color.dart';
import '../widgets/dartboard_input.dart';
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

    final tablet = isTabletLayout(context);
    final size   = MediaQuery.sizeOf(context);
    // Side by side only in landscape, as in the Checkout Ladder: the input is
    // the tall thing, and in portrait a split would squeeze it into half the
    // width while the capitals beside it stay short.
    final layout = tablet && size.width >= size.height
        ? context.watch<TabletLayoutProvider>()
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit(context);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: tablet ? 56 : 44,
          centerTitle: true,
          title: Text(
            l.modeCapitalName,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: tablet ? 19 : 15),
          ),
          actions: [
            if (layout != null)
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, size: 26),
                tooltip: l.swapInputSide,
                onPressed: () => layout.setSide(
                  layout.side == InputSide.left
                      ? InputSide.right
                      : InputSide.left,
                ),
              ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: tablet ? 26 : 22),
              tooltip: l.quitGame,
              onPressed: () => _confirmQuit(context),
            ),
          ],
        ),
        // The bottom inset is consumed here, for the reason the X01 screen
        // gives: left to the input's grid it opens a gap above the action row
        // instead of below it.
        body: SafeArea(
          top: false,
          child: layout != null
              ? SidePaneLayout(
                  side: layout.side,
                  primary: const DartboardInput<CapitalProvider>(
                      fillHeight: true),
                  secondary: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      children: [
                        _Scoreboard(provider: provider),
                        const SizedBox(height: 8),
                        _ContractBand(provider: provider),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: tablet
                          ? DartboardInput.maxFilledWidth
                          : contentMaxWidth(context,
                              fraction: kGameWidthFraction,
                              maxWidth: kMaxGameWidth),
                    ),
                    child: LayoutBuilder(
                      builder: (context, box) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // The capitals scroll inside a share of the screen,
                          // so a game of eight never pushes the input off it.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                                maxHeight: box.maxHeight * 0.3),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                              child: _Scoreboard(provider: provider),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: _ContractBand(provider: provider),
                          ),
                          Expanded(
                            child: DartboardInput<CapitalProvider>(
                                fillHeight: tablet),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
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
/// carrying a second line do not fit above the input. By default it is the
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
    final board = provider.game!.boardType;
    final hits = provider.visitHits;
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
                  capitalContractName(l, contract, board),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              // A met contract is marked by the check alone rather than by
              // tinting the whole band. Green rather than the brand red, which
              // reads as a failure.
              if (met)
                Icon(Icons.check_circle,
                    size: 20, color: onDoubleContainerColor(context)),
            ],
          ),
          Row(
            children: [
              // In the Colors round each dart thrown shows the paint it landed
              // in on the chosen board, so the player can check the line
              // beside it against the board on the wall.
              if (contract == CapitalContract.colors)
                for (final hit in hits)
                  if (areaOf(hit) case final area?)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _AreaDot(color: boardTone(board, area)),
                    ),
              if (contract == CapitalContract.colors && hits.isNotEmpty)
                const SizedBox(width: 4),
              Expanded(
                child: Text(
                  capitalProgressLine(l, contract, hits, board),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One dot in the paint of an area of the board, outlined like the wire on a
/// real board so a cream dot stays visible on a light surface.
class _AreaDot extends StatelessWidget {
  final Color color;
  const _AreaDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: BoardPaint.wire),
        ),
      );
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
