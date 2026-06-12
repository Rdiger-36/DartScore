import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../models/cricket_game.dart';
import '../models/player.dart';
import '../utils/layout.dart';
import '../widgets/cricket_marks_widget.dart';

/// Detailed view of a finished Cricket game from history, with final marks and
/// scores reconstructed from its stored throws.
class CricketHistorySummaryScreen extends StatelessWidget {
  final CricketGame game;
  final List<Player> players;

  const CricketHistorySummaryScreen({
    super.key,
    required this.game,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('dd.MM.yy  HH:mm').format(game.createdAt)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: FutureBuilder<_CricketHistoryData>(
            future: _load(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data;
              if (data == null) {
                return Center(child: Text(context.l10n.noThrowData));
              }
              return _Body(game: game, players: players, data: data);
            },
          ),
        ),
      ),
    );
  }

  /// Loads the game's throws and reconstructs each slot's final marks, score,
  /// and the winning slot. A slot is one team (if [game.isTeamGame]) or one
  /// player, mirroring `CricketProvider._buildSlots`.
  Future<_CricketHistoryData> _load() async {
    final throws = await DbHelper.instance.getCricketThrowsForGame(game.id!);

    final slots = game.isTeamGame
        ? game.teams!
            .map((team) => team.playerIds
                .map((id) => players.firstWhere((p) => p.id == id))
                .toList())
            .toList()
        : players.map((p) => [p]).toList();
    final slotNames = game.isTeamGame
        ? game.teams!.map((t) => t.name).toList()
        : players.map((p) => p.name).toList();

    final marks  = List.generate(slots.length, (_) => <int, int>{});
    final scores = List.filled(slots.length, 0);

    final isCT     = game.variant == CricketVariant.cutThroat;
    final isSimple = game.scoringMode == CricketScoringMode.simple;

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
    if (game.finishedAt != null) {
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
            isTeamSlot:  game.isTeamGame,
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
      padding: contentPadding(context, top: 16, bottom: 24, innerH: 12),
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
        _InfoRow(l.gameLabel, l.modeCricketName),
        const SizedBox(height: 6),
        _InfoRow(l.gameMode_, isCT ? l.cricketVariantCutThroat : l.cricketVariantNormal),
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

/// A label/value row used in the game-info section.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        )),
        Text(value, style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
        )),
      ],
    );
  }
}
