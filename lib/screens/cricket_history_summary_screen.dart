import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../models/cricket_game.dart';
import '../models/player.dart';
import '../providers/cricket_provider.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../widgets/cricket_marks_widget.dart';
import '../widgets/game_info_card.dart';
import '../widgets/rematch_button.dart';
import 'cricket_screen.dart';

/// Detailed view of a finished Cricket game from history, with final marks and
/// scores reconstructed from its stored throws.
class CricketHistorySummaryScreen extends StatefulWidget {
  final CricketGame game;
  final List<Player> players;

  /// Whether this sits inside a pane that brings its own title bar, as the
  /// master detail layout of the history does on a tablet. Embedded it renders
  /// its content alone, without a screen around it.
  final bool embedded;

  const CricketHistorySummaryScreen({
    super.key,
    required this.game,
    required this.players,
    this.embedded = false,
  });

  @override
  State<CricketHistorySummaryScreen> createState() =>
      _CricketHistorySummaryScreenState();
}

class _CricketHistorySummaryScreenState extends State<CricketHistorySummaryScreen> {
  /// Started once and kept, not started again on every build.
  ///
  /// A read begun inside `build` is begun again by every rebuild, and a pane
  /// whose divider is being dragged rebuilds on every frame: the view would
  /// fall back to its spinner for the length of the drag and hammer the
  /// database while it lasted.
  late Future<_CricketHistoryData> _future = _load();

  @override
  void didUpdateWidget(CricketHistorySummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return _wrap(
      context,
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: FutureBuilder<_CricketHistoryData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data;
              if (data == null) {
                return Center(child: Text(context.l10n.noThrowData));
              }
              return _Body(game: widget.game, players: widget.players, data: data);
            },
          ),
        ),
      ),
    );
  }

  /// Puts the screen around [content], or hands it over bare when this view is
  /// widget.embedded in a pane that already has a title bar of its own.
  Widget _wrap(BuildContext context, Widget content) => widget.embedded
      ? content
      : Scaffold(
          appBar: AppBar(
            title: Text(DateFormat('dd.MM.yy  HH:mm').format(widget.game.createdAt)),
          ),
          body: content,
        );

  /// Loads the widget.game's throws and reconstructs each slot's final marks, score,
  /// and the winning slot. A slot is one team (if [widget.game.isTeamGame]) or one
  /// player, mirroring `CricketProvider._buildSlots`.
  Future<_CricketHistoryData> _load() async {
    final throws = await DbHelper.instance.getCricketThrowsForGame(widget.game.id!);

    final slots = widget.game.isTeamGame
        ? widget.game.teams!
            .map((team) => team.playerIds
                .map((id) => widget.players.firstWhere((p) => p.id == id))
                .toList())
            .toList()
        : widget.players.map((p) => [p]).toList();
    final slotNames = widget.game.isTeamGame
        ? widget.game.teams!.map((t) => t.name).toList()
        : widget.players.map((p) => p.name).toList();

    final marks  = List.generate(slots.length, (_) => <int, int>{});
    final scores = List.filled(slots.length, 0);

    final isCT     = widget.game.variant == CricketVariant.cutThroat;
    final isSimple = widget.game.scoringMode == CricketScoringMode.simple;

    for (final t in throws) {
      if (t.isMiss) continue;
      final slotIdx =
          slots.indexWhere((ps) => ps.any((p) => p.id == t.playerId));
      if (slotIdx < 0) continue;

      final eff  = isSimple ? 1 : t.multiplier;
      final cur  = marks[slotIdx][t.field] ?? 0;
      final newM = cur + eff;
      marks[slotIdx][t.field] = newM.clamp(0, 3);

      final scoring = (newM - 3).clamp(0, eff);
      if (scoring <= 0) continue;
      final fv  = t.field == 25 ? 25 : t.field;
      final pts = scoring * fv;

      if (isCT) {
        for (var i = 0; i < slots.length; i++) {
          if (i == slotIdx) continue;
          if ((marks[i][t.field] ?? 0) < 3) {
            scores[i] += pts;
          }
        }
      } else {
        final alive = Iterable<int>.generate(slots.length)
            .any((i) => i != slotIdx && (marks[i][t.field] ?? 0) < 3);
        if (alive) scores[slotIdx] += pts;
      }
    }

    // Determine winner from DB (finished_at set + score condition)
    int? winnerSlotIndex;
    if (widget.game.finishedAt != null) {
      if (isCT) {
        final minScore = scores.fold(999999, (a, b) => a < b ? a : b);
        winnerSlotIndex = scores.indexOf(minScore);
      } else {
        final maxScore = scores.fold(-1, (a, b) => a > b ? a : b);
        winnerSlotIndex = scores.indexOf(maxScore);
      }
      // If a slot closed all fields, prefer it as winner
      for (var i = 0; i < slots.length; i++) {
        final closedAll = cricketFields.every((f) => (marks[i][f] ?? 0) >= 3);
        if (closedAll) {
          final score = scores[i];
          final beats = Iterable<int>.generate(slots.length)
              .where((j) => j != i)
              .every((j) => isCT ? score <= scores[j] : score >= scores[j]);
          if (beats) { winnerSlotIndex = i; break; }
        }
      }
    }

    return _CricketHistoryData(
      slots: List.generate(slots.length, (i) => _CricketSlot(
            displayName: slotNames[i],
            players:     slots[i],
            isTeamSlot:  widget.game.isTeamGame,
            marks:       marks[i],
            score:       scores[i],
          )),
      winnerSlotIndex: winnerSlotIndex,
    );
  }
}

/// Reconstructed final state of one scoreboard slot (a team or a single
/// player) in a historical Cricket game: its members, final marks, and score.
class _CricketSlot {
  final String displayName;
  final List<Player> players;
  final bool isTeamSlot;
  final Map<int, int> marks;
  final int score;

  const _CricketSlot({
    required this.displayName,
    required this.players,
    required this.isTeamSlot,
    required this.marks,
    required this.score,
  });
}

/// Reconstructed final state of a historical Cricket game: per-slot marks and
/// scores, and the index of the winning slot.
class _CricketHistoryData {
  final List<_CricketSlot> slots;
  final int? winnerSlotIndex;
  const _CricketHistoryData({
    required this.slots,
    required this.winnerSlotIndex,
  });
}

/// Renders the reconstructed game details: variant, marks grid, and scores.
class _Body extends StatelessWidget {
  final CricketGame game;
  final List<Player> players;
  final _CricketHistoryData data;

  const _Body({
    required this.game,
    required this.players,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final cs      = theme.colorScheme;
    final l       = context.l10n;
    final isCT    = game.variant == CricketVariant.cutThroat;

    final sortedSlots = List.of(data.slots.indexed)
      ..sort((a, b) {
        if (a.$1 == data.winnerSlotIndex) return -1;
        if (b.$1 == data.winnerSlotIndex) return 1;
        return isCT
            ? a.$2.score.compareTo(b.$2.score)
            : b.$2.score.compareTo(a.$2.score);
      });
    final sorted = sortedSlots.map((e) => e.$2).toList();

    return ListView(
      // Fixed rather than measured: on a tablet this screen is rendered inside
      // a pane, and contentPadding measures the window, so it would put the
      // margin of a whole screen on either side of half of one.
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      children: [
        // Winner banner
        if (data.winnerSlotIndex != null) ...[
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_events_rounded, size: 52, color: cs.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  l.cricketWinner(
                      data.slots[data.winnerSlotIndex!].displayName),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Game info
        GameInfoCard(dense: true, rows: [
          (l.gameLabel, l.modeCricketName),
          (l.cricketVariant, cricketVariantLabel(l, game.variant)),
          (l.cricketScoringMode, cricketScoringModeLabel(l, game.scoringMode)),
          (l.startingOrder, startingOrderLabel(l, game.startingOrder)),
        ]),
        const SizedBox(height: 16),

        // ── Rematch ────────────────────────────────────────────────────────
        RematchButton(
          modeName: l.modeCricketName,
          details: [
            (l.cricketVariant, cricketVariantLabel(l, game.variant)),
            (l.cricketScoringMode, cricketScoringModeLabel(l, game.scoringMode)),
          ],
          slots: data.slots
              .map((s) => s.isTeamSlot
                  ? RematchSlot.team(s.displayName,
                      s.players.map((p) => RematchSlot.player(p.name)).toList())
                  : RematchSlot.player(s.displayName))
              .toList(),
          onRematch: () =>
              context.read<CricketProvider>().startRematch(game, players),
          destination: (_) => const CricketScreen(),
        ),
        const SizedBox(height: 16),

        // Per-player score cards
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.cricketSummaryTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...sortedSlots.map((e) {
                  final slot     = e.$2;
                  final isWinner = e.$1 == data.winnerSlotIndex;
                  final closed   = cricketFields
                      .where((f) => (slot.marks[f] ?? 0) >= 3)
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        if (isWinner)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.emoji_events_rounded, size: 18),
                          )
                        else
                          const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(slot.displayName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: isWinner
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isWinner ? cs.primary : null,
                                  )),
                              if (slot.isTeamSlot)
                                Text(
                                  slot.players.map((p) => p.name).join(' & '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                              Text('$closed/7 ${l.cricketFieldsClosed}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text('${slot.score}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isWinner ? cs.primary : null,
                            )),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Field marks overview
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.cricketMarks,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 52),
                    ...sorted.map((slot) => Expanded(
                          child: Column(
                            children: [
                              Text(slot.displayName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall),
                              if (slot.isTeamSlot)
                                Text(
                                  slot.players.map((p) => p.name).join(' & '),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                ...cricketFields.map((field) {
                  final label = field == 25 ? l.bull : '$field';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 52,
                          child: Text(label,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        ...sorted.map((slot) {
                          final m = slot.marks[field] ?? 0;
                          return Expanded(
                              child: Center(child: CricketMarksWidget(marks: m)));
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

