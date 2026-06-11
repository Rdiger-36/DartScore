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

  /// Loads the game's throws and reconstructs each player's final marks, scores,
  /// and the winner.
  Future<_CricketHistoryData> _load() async {
    final throws = await DbHelper.instance.getCricketThrowsForGame(game.id!);

    // Reconstruct final marks and scores for each player
    final marks  = <int, Map<int, int>>{for (final p in players) p.id!: {}};
    final scores = <int, int>{for (final p in players) p.id!: 0};

    final isCT     = game.variant == CricketVariant.cutThroat;
    final isSimple = game.scoringMode == CricketScoringMode.simple;

    for (final t in throws) {
      if (t.isMiss) continue;
      final pid = t.playerId;
      if (!marks.containsKey(pid)) continue;

      final eff     = isSimple ? 1 : t.multiplier;
      final cur     = marks[pid]![t.field] ?? 0;
      final newM    = cur + eff;
      marks[pid]![t.field] = newM.clamp(0, 3);

      final scoring = (newM - 3).clamp(0, eff);
      if (scoring <= 0) continue;
      final fv     = t.field == 25 ? 25 : t.field;
      final pts    = scoring * fv;

      if (isCT) {
        for (final p in players) {
          if (p.id == pid) continue;
          if ((marks[p.id!]?[t.field] ?? 0) < 3) {
            scores[p.id!] = (scores[p.id!] ?? 0) + pts;
          }
        }
      } else {
        final alive = players.any(
            (p) => p.id != pid && (marks[p.id!]?[t.field] ?? 0) < 3);
        if (alive) scores[pid] = (scores[pid] ?? 0) + pts;
      }
    }

    // Determine winner from DB (finished_at set + score condition)
    int? winnerId;
    if (game.finishedAt != null) {
      if (isCT) {
        final minScore = scores.values.fold(999999, (a, b) => a < b ? a : b);
        winnerId = scores.entries
            .firstWhere((e) => e.value == minScore, orElse: () => scores.entries.first)
            .key;
      } else {
        final maxScore = scores.values.fold(-1, (a, b) => a > b ? a : b);
        winnerId = scores.entries
            .firstWhere((e) => e.value == maxScore, orElse: () => scores.entries.first)
            .key;
      }
      // If a player closed all fields, prefer them as winner
      for (final p in players) {
        final closedAll = cricketFields.every((f) => (marks[p.id!]?[f] ?? 0) >= 3);
        if (closedAll) {
          final score = scores[p.id!] ?? 0;
          final beats = players.where((o) => o.id != p.id).every((o) =>
              isCT ? score <= (scores[o.id!] ?? 0) : score >= (scores[o.id!] ?? 0));
          if (beats) { winnerId = p.id; break; }
        }
      }
    }

    return _CricketHistoryData(marks: marks, scores: scores, winnerId: winnerId);
  }
}

/// Reconstructed final state of a historical Cricket game: per-player marks
/// (by field), scores, and the winner.
class _CricketHistoryData {
  final Map<int, Map<int, int>> marks;
  final Map<int, int> scores;
  final int? winnerId;
  const _CricketHistoryData({
    required this.marks,
    required this.scores,
    required this.winnerId,
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

    final sorted = List.of(players)
      ..sort((a, b) {
        if (a.id == data.winnerId) return -1;
        if (b.id == data.winnerId) return 1;
        final sa = data.scores[a.id] ?? 0;
        final sb = data.scores[b.id] ?? 0;
        return isCT ? sa.compareTo(sb) : sb.compareTo(sa);
      });

    return ListView(
      padding: contentPadding(context, top: 16, bottom: 24, innerH: 12),
      children: [
        // Winner banner
        if (data.winnerId != null) ...[
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
                      players.firstWhere((p) => p.id == data.winnerId).name),
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
                ...sorted.map((p) {
                  final isWinner = p.id == data.winnerId;
                  final score    = data.scores[p.id] ?? 0;
                  final closed   = cricketFields
                      .where((f) => (data.marks[p.id]?[f] ?? 0) >= 3)
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
                              Text(p.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: isWinner
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isWinner ? cs.primary : null,
                                  )),
                              Text('$closed/7 ${l.cricketFieldsClosed}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text('$score',
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
                    ...sorted.map((p) => Expanded(
                          child: Text(p.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall),
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
                        ...sorted.map((p) {
                          final m = data.marks[p.id]?[field] ?? 0;
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
