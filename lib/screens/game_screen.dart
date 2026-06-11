import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/game_provider.dart';
import '../widgets/dartboard_input.dart';
import '../widgets/finish_suggestion_widget.dart';
import '../models/game.dart';
import 'game_summary_screen.dart';
import '../utils/layout.dart';

/// Live X01 game screen: scoreboard with live running score, dartboard/numpad
/// input, finish suggestions, and undo. Routes to the summary when the game ends.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int? _liveRemaining;
  bool _liveBust = false;
  int _liveDartsInVisit = 0;
  bool _liveCheckedInThisVisit = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, provider, _) {
        if (provider.game == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (provider.gameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const GameSummaryScreen()),
            );
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final game       = provider.game!;
        final states     = provider.playerStates;
        final currentIdx = provider.currentPlayerIndex;
        final current    = provider.currentPlayerState;
        final isSolo     = states.length == 1;
        final displayRemaining = _liveRemaining ?? current.remaining;
        final handicaps  = provider.handicaps;

        // Check-In only applies in the very first leg of the game (leg 1, set 1).
        final checkInActive = provider.currentLeg == 1 && provider.currentSet == 1;

        // Per-player resolved modes (handicap overrides game defaults)
        List<GameMode> playerCheckIns = states
            .map((s) => checkInActive
                ? (handicaps[s.player.id]?.checkIn ?? game.gameMode)
                : GameMode.straightIn)
            .toList();
        List<CheckoutMode> playerCheckOuts = states
            .map((s) => handicaps[s.player.id]?.checkOut ?? game.checkoutMode)
            .toList();
        // hasCheckedIn: straight-in is always checked in; double-in/master-in require remaining < startScore
        List<bool> playerCheckedIn = states.asMap().entries.map((e) {
          final alreadyIn = playerCheckIns[e.key] == GameMode.straightIn ||
              e.value.remaining < game.startScore;
          // Live override: if the qualifying dart was thrown this visit, show as checked in immediately
          if (e.key == currentIdx) return alreadyIn || _liveCheckedInThisVisit;
          return alreadyIn;
        }).toList();

        final currentCheckOut = playerCheckOuts[currentIdx];
        final currentHasCheckedIn = playerCheckedIn[currentIdx];
        // Committed check-in only (no live component) — passed to DartboardInput
        // so its scoring gate is stable and doesn't create a feedback loop.
        final currentHasCheckedInCommitted =
            playerCheckIns[currentIdx] == GameMode.straightIn ||
            current.remaining < game.startScore;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            toolbarHeight: 44,
            automaticallyImplyLeading: false,
            title: Text(
              isSolo
                  ? '${context.l10n.openPlay} · ${game.startScore}'
                  : '${game.startScore} · ${context.l10n.legLabel(provider.currentLeg)} · ${context.l10n.setLabel(provider.currentSet)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            actions: [
              // Visit-level undo (no dialog)
              IconButton(
                icon: Icon(Icons.undo_rounded,
                    size: 22,
                    color: provider.canUndo
                        ? null
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                tooltip: context.l10n.undoVisit,
                onPressed: provider.canUndo
                    ? () {
                        setState(() { _liveRemaining = null; _liveBust = false; _liveCheckedInThisVisit = false; });
                        provider.undoLastThrow();
                      }
                    : null,
              ),
              // Visit-level redo (no dialog)
              IconButton(
                icon: Icon(Icons.redo_rounded,
                    size: 22,
                    color: provider.canRedo
                        ? null
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                tooltip: context.l10n.redoVisit,
                onPressed: provider.canRedo
                    ? () {
                        setState(() { _liveRemaining = null; _liveBust = false; _liveCheckedInThisVisit = false; });
                        provider.redoLastThrow();
                      }
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                tooltip: context.l10n.quitGame,
                onPressed: () => _confirmQuit(context),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context, fraction: kGameWidthFraction, maxWidth: kMaxGameWidth)),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Scoreboard + reservierter Checkout-Bereich ───────────
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Scoreboard(
                    states: states,
                    currentIdx: currentIdx,
                    game: game,
                    isSolo: isSolo,
                    liveRemaining: displayRemaining,
                    liveBust: _liveBust,
                    currentLeg: provider.currentLeg,
                    currentSet: provider.currentSet,
                    liveDartsInVisit: _liveDartsInVisit,
                    playerCheckIns: playerCheckIns,
                    playerCheckOuts: playerCheckOuts,
                    playerCheckedIn: playerCheckedIn,
                  ),
                  const SizedBox(height: 6),
                  // Fester Bereich für Checkout-Hinweis — Buttons verschieben sich nie
                  SizedBox(
                    height: 62,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: FinishSuggestionWidget(
                        key: ValueKey(
                          '${_liveBust ? current.remaining : displayRemaining}_$_liveDartsInVisit',
                        ),
                        remaining: _liveBust ? current.remaining : displayRemaining,
                        favoriteDouble: current.player.favoriteDouble,
                        dartsThrown: _liveDartsInVisit,
                        checkoutMode: currentHasCheckedIn ? currentCheckOut : CheckoutMode.doubleOut,
                      ),
                    ),
                  ),
                ],
                  ),
                ),
              ),
              // ── Dartboard input ─────────────────────────────────────────
              Expanded(
                child: DartboardInput(
                  key: ValueKey(
                      'player_${current.player.id}_leg_${provider.currentLeg}_set_${provider.currentSet}'),
                  remaining: current.remaining,
                  checkoutMode: currentCheckOut,
                  gameMode: playerCheckIns[currentIdx],
                  hasCheckedIn: currentHasCheckedInCommitted,
                  onScoreUpdate: (live, bust, dartsInVisit, checkedInThisVisit) => setState(() {
                    _liveRemaining = live;
                    _liveBust = bust;
                    _liveDartsInVisit = dartsInVisit;
                    _liveCheckedInThisVisit = checkedInThisVisit;
                  }),
                  onVisitComplete: (score, darts, bust, hits) {
                    setState(() {
                      _liveRemaining = null;
                      _liveBust = false;
                      _liveDartsInVisit = 0;
                      _liveCheckedInThisVisit = false;
                    });
                    provider.submitScore(score, darts, bust: bust, hits: hits);
                  },
                ),
              ),
            ],
          ),
            ),
          ),
        );
      },
    );
  }

  /// Asks the user to confirm leaving the game, returning to the home screen if
  /// they accept.
  void _confirmQuit(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) {
        final l = context.l10n;
        return AlertDialog(
          title: Text(l.quitTitle),
          content: Text(l.quitBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text(l.leave),
            ),
          ],
        );
      },
    );
  }
}

// ── Scoreboard ────────────────────────────────────────────────────────────────

/// The X01 scoreboard: one card per player/team showing remaining score (live
/// for the active player), legs/sets, average, and check-in/out badges.
class _Scoreboard extends StatelessWidget {
  final List<PlayerState> states;
  final int currentIdx;
  final Game game;
  final bool isSolo;
  final int liveRemaining;
  final bool liveBust;
  final int currentLeg;
  final int currentSet;
  final int liveDartsInVisit;
  final List<GameMode> playerCheckIns;
  final List<CheckoutMode> playerCheckOuts;
  final List<bool> playerCheckedIn;

  const _Scoreboard({
    required this.states,
    required this.currentIdx,
    required this.game,
    required this.isSolo,
    required this.liveRemaining,
    required this.liveBust,
    required this.currentLeg,
    required this.currentSet,
    required this.liveDartsInVisit,
    required this.playerCheckIns,
    required this.playerCheckOuts,
    required this.playerCheckedIn,
  });

  /// Builds one player score card.
  Widget _buildCard({
    required BuildContext context,
    required int i,
    required bool isCurrent,
    required bool isNext,
  }) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final s     = states[i];

    final displayValue = isCurrent
        ? (liveBust ? s.remaining : liveRemaining)
        : s.remaining;
    final showBust = isCurrent && liveBust;

    // Perfect-game live badge
    final minDarts      = minimumDartsForScore[game.startScore];
    final committedDarts = s.throws
        .where((t) => t.leg == currentLeg && t.set == currentSet)
        .fold(0, (sum, t) => sum + t.dartsUsed);
    final totalDarts    = committedDarts + (isCurrent ? liveDartsInVisit : 0);
    final checkRemaining = isCurrent ? liveRemaining : s.remaining;
    final remainingDarts = minDarts != null ? minDarts - totalDarts : 0;
    final maxAchievable  = remainingDarts > 0 ? (remainingDarts - 1) * 60 + 50 : 0;
    final perfectStillPossible = minDarts != null &&
        totalDarts < minDarts &&
        checkRemaining > 0 &&
        checkRemaining <= maxAchievable;

    final cardColor = showBust
        ? cs.errorContainer
        : isCurrent
            ? cs.primary
            : cs.surfaceContainerHigh;
    final onCard     = showBust
        ? cs.onErrorContainer
        : isCurrent
            ? cs.onPrimary
            : cs.onSurface;
    final onCardMuted = onCard.withValues(alpha: 0.65);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name: team name (big) + current player (small) for teams
                  Text(
                    s.displayName,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onCard,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (s.isTeamSlot)
                    Text(
                      s.player.name,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onCard.withValues(alpha: 0.75),
                      ),
                    ),
                  // Mode badge (check-in required OR in checkout range)
                  Center(
                    child: _ModeBadge(
                      remaining: displayValue,
                      checkIn: playerCheckIns[i],
                      checkOut: playerCheckOuts[i],
                      checkedIn: playerCheckedIn[i],
                      onCard: onCard,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Big score
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 110),
                    child: Text(
                      showBust ? 'BUST' : '$displayValue',
                      key: ValueKey('$i-$displayValue-$showBust'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: onCard,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Stats + perfect-game badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (!isSolo)
                            Text(
                              game.sets > 1
                                  ? '${context.l10n.setsAbbr} ${s.setsWon}  ${context.l10n.legsAbbr} ${s.legsWon}'
                                  : '${context.l10n.legs}: ${s.legsWon}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: onCardMuted),
                            ),
                          Text(
                            'Ø ${s.average.toStringAsFixed(1)}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: onCardMuted),
                          ),
                        ],
                      ),
                      if (perfectStillPossible)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$minDarts',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    // With 3+ players: show only current + next.  ≤2: show all.
    final nextIdx = (currentIdx + 1) % states.length;
    final showAll = states.length <= 2;
    final mainIndices = showAll
        ? List.generate(states.length, (i) => i)
        : [currentIdx, nextIdx];
    final otherIndices = showAll
        ? <int>[]
        : List.generate(states.length, (i) => i)
            .where((i) => i != currentIdx && i != nextIdx)
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Main cards (current + next) ────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: mainIndices.map((i) => _buildCard(
                context: context,
                i: i,
                isCurrent: i == currentIdx,
                isNext: !showAll && i == nextIdx,
              )).toList(),
            ),
          ),

          // ── Other players — compact score strip ────────────────────
          if (otherIndices.isNotEmpty) ...[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: otherIndices.map((i) {
                  final s = states[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: cs.outline.withValues(alpha: 0.3),
                          child: Text(
                            s.player.name.isNotEmpty
                                ? s.player.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          s.displayName.split(' ').first,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${s.remaining}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mode badge ────────────────────────────────────────────────────────────────
// Shown below the player name in the scoreboard card.
// • "DOUBLE IN" (amber)  — when double-in is required and player hasn't checked in
// • "D-Out / M-Out / S-Out" (subtle) — when in checkout range (remaining ≤ 170)
// • Nothing  — normal scoring range, already checked in, no special action needed

/// Small status badge under a player's name showing a required check-in or the
/// active checkout rule, or nothing during normal scoring.
class _ModeBadge extends StatelessWidget {
  final int remaining;
  final GameMode checkIn;
  final CheckoutMode checkOut;
  final bool checkedIn;
  final Color onCard;

  const _ModeBadge({
    required this.remaining,
    required this.checkIn,
    required this.checkOut,
    required this.checkedIn,
    required this.onCard,
  });

  @override
  Widget build(BuildContext context) {
    // Priority 1: Double-In / Master-In not yet done
    if ((checkIn == GameMode.doubleIn || checkIn == GameMode.masterIn) && !checkedIn) {
      final label = checkIn == GameMode.masterIn ? 'MASTER IN' : 'DOUBLE IN';
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }

    // Priority 2: In checkout range — show checkout mode
    if (remaining <= 170 && remaining > 1) {
      final label = switch (checkOut) {
        CheckoutMode.doubleOut  => 'D-Out',
        CheckoutMode.masterOut  => 'M-Out',
        CheckoutMode.straightOut => 'S-Out',
      };
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          '→ $label',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: onCard.withValues(alpha: 0.7),
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
