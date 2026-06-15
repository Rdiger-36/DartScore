import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../utils/layout.dart';
import '../utils/placement.dart';

/// Detailed view of a finished X01 game from history: per-player stats and the
/// full throw log, loaded from the stored throws.
class HistoryGameSummaryScreen extends StatelessWidget {
  final Game game;
  final List<Player> players;

  const HistoryGameSummaryScreen({
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
          child: FutureBuilder<_GameData>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null || data.playerThrows.isEmpty) {
            return Center(child: Text(context.l10n.noThrowData));
          }
          return _SummaryBody(game: game, data: data, players: players);
        },
      ),
        ),
      ),
    );
  }

  /// Loads the game's throws and groups them by player.
  Future<_GameData> _load() async {
    final db = DbHelper.instance;
    final allThrows = await db.getThrowsForGame(game.id!);
    final Map<int, List<DartThrow>> byPlayer = {};
    for (final t in allThrows) {
      byPlayer.putIfAbsent(t.playerId, () => []).add(t);
    }
    return _GameData(playerThrows: byPlayer, allThrows: allThrows);
  }
}

/// Loaded throws for a historical game: grouped by player and as a flat list.
class _GameData {
  final Map<int, List<DartThrow>> playerThrows;
  final List<DartThrow> allThrows;
  const _GameData({required this.playerThrows, required this.allThrows});
}

/// Renders the game info, per-player stat cards, and the combined throw log.
class _SummaryBody extends StatelessWidget {
  final Game game;
  final _GameData data;
  final List<Player> players;

  const _SummaryBody({
    required this.game,
    required this.data,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Find winner: player who reached 0 last (highest leg win)
    Player? winner;
    for (final t in data.allThrows.reversed) {
      if (!t.bust && t.remainingBefore - t.score == 0) {
        winner = players.firstWhere((p) => p.id == t.playerId,
            orElse: () => players.first);
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        // Winner banner
        if (winner != null)
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
                  context.l10n.wins(winner.name),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        // Game info
        _InfoRow(context.l10n.gameLabel, context.l10n.modeX01Name),
        const SizedBox(height: 6),
        _InfoRow(context.l10n.gameMode_, context.l10n.gameSummaryInfo(game.startScore, game.legs, game.sets, placementMode: game.placementMode)),
        const SizedBox(height: 12),
        // Final ranking (placement mode only)
        if (game.placementMode) ...[
          _FinalRankingCard(game: game, data: data, players: players),
          const SizedBox(height: 12),
        ],
        // Per-player stats
        ...players.map((p) {
          final throws = data.playerThrows[p.id] ?? [];
          // In placement mode every slot checks out every leg, so legs won
          // must come from placementRanking() rather than counting checkout
          // throws (team games keep the existing per-player count).
          final legsWonOverride = game.placementMode && !game.isTeamGame
              ? (placementRanking(
                      data.playerThrows,
                      data.allThrows.isEmpty
                          ? 0
                          : data.allThrows
                              .map((t) => t.leg)
                              .reduce((a, b) => a > b ? a : b),
                      1)
                  .legsWon[p.id!])
              : null;
          return _PlayerCard(
              player: p, throws: throws, legsWonOverride: legsWonOverride);
        }),
        const SizedBox(height: 14),
        // Throw log
        Text(
          context.l10n.allThrows,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: data.allThrows.map((t) {
                final player = players.firstWhere((p) => p.id == t.playerId,
                    orElse: () => players.first);
                return _ThrowLogRow(t: t, playerName: player.name);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Final ranking card for a finished placement-mode game: every player/team
/// sorted by legs won (desc), tie-broken by the cumulative sum of per-leg
/// finishing positions (asc, lower is better), computed from stored throws.
class _FinalRankingCard extends StatelessWidget {
  final Game game;
  final _GameData data;
  final List<Player> players;

  const _FinalRankingCard({
    required this.game,
    required this.data,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;

    final Map<int, List<DartThrow>> throwsById = {};
    final Map<int, String> namesById = {};
    if (game.isTeamGame) {
      for (var ti = 0; ti < game.teams!.length; ti++) {
        final team = game.teams![ti];
        final teamThrows = data.allThrows
            .where((t) => team.playerIds.contains(t.playerId))
            .toList()
          ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt));
        throwsById[ti] = teamThrows;
        namesById[ti] = team.name;
      }
    } else {
      for (final p in players) {
        throwsById[p.id!] = data.playerThrows[p.id] ?? [];
        namesById[p.id!] = p.name;
      }
    }

    final maxLeg = data.allThrows.isEmpty
        ? 0
        : data.allThrows.map((t) => t.leg).reduce((a, b) => a > b ? a : b);
    final ranking = placementRanking(throwsById, maxLeg, 1);
    final legTable = legPlacementsTable(throwsById, maxLeg, 1);
    final points = placementPointsTotal(throwsById, maxLeg, 1);

    final ranked = throwsById.keys.toList()
      ..sort((a, b) {
        final pointsA = points[a] ?? 0;
        final pointsB = points[b] ?? 0;
        if (pointsA != pointsB) return pointsB.compareTo(pointsA);
        final legsA = ranking.legsWon[a] ?? 0;
        final legsB = ranking.legsWon[b] ?? 0;
        return legsA != legsB
            ? legsB.compareTo(legsA)
            : (ranking.placementSum[a] ?? 0)
                .compareTo(ranking.placementSum[b] ?? 0);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.finalRanking,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...ranked.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final id = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$rank.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(namesById[id] ?? '?',
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      '${l.legs}: ${ranking.legsWon[id] ?? 0}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${l.points}: ${points[id] ?? 0}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            if (maxLeg > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                l.legByLegPlacements,
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                l.placementPointsHint,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(40),
                  columnWidths: {
                    0: const FixedColumnWidth(100),
                    maxLeg + 1: const FixedColumnWidth(56),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                  children: [
                    TableRow(children: [
                      const SizedBox.shrink(),
                      for (var leg = 1; leg <= maxLeg; leg++)
                        _RankCell(l.legAbbr(leg), bold: true, alignment: Alignment.center),
                      _RankCell(l.points, bold: true, alignment: Alignment.center),
                    ]),
                    ...ranked.map((id) {
                      return TableRow(children: [
                        _RankCell(namesById[id] ?? '?', alignment: Alignment.centerLeft),
                        for (var leg = 1; leg <= maxLeg; leg++)
                          _RankCell(
                            legTable[leg]?[id] != null ? '${legTable[leg]![id]}.' : '-',
                            alignment: Alignment.center,
                          ),
                        _RankCell('${points[id] ?? 0}', bold: true, alignment: Alignment.center),
                      ]);
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single padded, optionally bold cell used in the per-leg placement table.
class _RankCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Alignment alignment;

  const _RankCell(this.text, {this.bold = false, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: bold ? FontWeight.bold : null,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
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

/// Per-player stat card for a historical game, computing average, legs won,
/// darts, highest visit, and busts from the player's throws.
class _PlayerCard extends StatelessWidget {
  final Player player;
  final List<DartThrow> throws;
  /// Overrides the checkout-count-based legs-won display (used in placement
  /// mode, where every player checks out every leg).
  final int? legsWonOverride;
  const _PlayerCard({
    required this.player,
    required this.throws,
    this.legsWonOverride,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalDarts = throws.fold(0, (s, t) => s + t.dartsUsed);
    final scored = throws.fold(0, (s, t) => s + (t.bust ? 0 : t.score));
    final avg = totalDarts == 0 ? 0.0 : (scored / totalDarts) * 3;
    final busts = throws.where((t) => t.bust).length;
    final high = throws.isEmpty ? 0 : throws.map((t) => t.score).reduce((a, b) => a > b ? a : b);
    final legs = legsWonOverride ??
        throws.where((t) => !t.bust && t.remainingBefore - t.score == 0).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(player.name.isNotEmpty ? player.name[0].toUpperCase() : "?",
                      style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(player.name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _Row(context.l10n.threeDartAvg, avg.toStringAsFixed(2)),
            _Row(context.l10n.legsWon, '$legs'),
            _Row(context.l10n.darts_, '$totalDarts'),
            _Row(context.l10n.highestVisit, '$high'),
            _Row(context.l10n.busts, '$busts'),
          ],
        ),
      ),
    );
  }
}

/// A compact label/value stat row in a player card.
class _Row extends StatelessWidget {
  final String l, v;
  const _Row(this.l, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: Theme.of(context).textTheme.bodySmall),
          Text(v, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// A single row in the combined throw log: player, visit score, and remaining.
class _ThrowLogRow extends StatelessWidget {
  final DartThrow t;
  final String playerName;
  const _ThrowLogRow({required this.t, required this.playerName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(playerName,
                style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
          ),
          Container(
            width: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: t.bust ? cs.errorContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              t.bust ? 'BUST' : '${t.score}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: t.bust ? cs.onErrorContainer : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '→ ${t.remainingBefore - (t.bust ? 0 : t.score)}',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            '${context.l10n.legLabel(t.leg)}  ${context.l10n.dartsShort(t.dartsUsed)}',
            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
