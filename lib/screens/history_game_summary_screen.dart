import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';

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
      body: FutureBuilder<_GameData>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null || data.playerThrows.isEmpty) {
            return const Center(child: Text('Keine Wurfdaten vorhanden.'));
          }
          return _SummaryBody(game: game, data: data, players: players);
        },
      ),
    );
  }

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

class _GameData {
  final Map<int, List<DartThrow>> playerThrows;
  final List<DartThrow> allThrows;
  const _GameData({required this.playerThrows, required this.allThrows});
}

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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events_rounded, size: 40, color: cs.primary),
                const SizedBox(height: 6),
                Text(
                  '🎯 ${winner.name} gewinnt!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        // Game info
        _InfoRow(context.l10n.gameMode_, context.l10n.gameSummaryInfo(game.startScore, game.legs, game.sets)),
        const SizedBox(height: 12),
        // Per-player stats
        ...players.map((p) {
          final throws = data.playerThrows[p.id] ?? [];
          return _PlayerCard(player: p, throws: throws);
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

class _PlayerCard extends StatelessWidget {
  final Player player;
  final List<DartThrow> throws;
  const _PlayerCard({required this.player, required this.throws});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalDarts = throws.fold(0, (s, t) => s + t.dartsUsed);
    final scored = throws.fold(0, (s, t) => s + (t.bust ? 0 : t.score));
    final avg = totalDarts == 0 ? 0.0 : (scored / totalDarts) * 3;
    final busts = throws.where((t) => t.bust).length;
    final high = throws.isEmpty ? 0 : throws.map((t) => t.score).reduce((a, b) => a > b ? a : b);
    final legs = throws.where((t) => !t.bust && t.remainingBefore - t.score == 0).length;

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
            'L${t.leg}  ${t.dartsUsed}P',
            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
