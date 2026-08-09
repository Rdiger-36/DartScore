import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../providers/game_provider.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../utils/throw_stats.dart';
import '../widgets/final_ranking_card.dart';
import '../widgets/game_info_card.dart';
import '../utils/placement.dart';
import '../widgets/rematch_button.dart';
import '../widgets/summary_player_card.dart';
import '../widgets/throw_log_card.dart';
import 'game_screen.dart';

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

    // Team configs only store player ids, so the rematch dialog needs a name
    // lookup to list a team's members.
    final namesById = {for (final p in players) p.id: p.name};

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
        GameInfoCard(dense: true, rows: [
          (context.l10n.gameLabel, context.l10n.modeX01Name),
          (
            context.l10n.matchFormat,
            game.placementMode
                ? context.l10n.placementMode
                : context.l10n.standardMode
          ),
          (
            context.l10n.gameMode_,
            context.l10n.gameSummaryInfo(game.startScore, game.legs, game.sets,
                placementMode: game.placementMode)
          ),
          // A solo game has nobody to be ordered against.
          if (game.isTeamGame || players.length > 1)
            (
              context.l10n.startingOrder,
              startingOrderLabel(context.l10n, game.startingOrder)
            ),
        ]),
        const SizedBox(height: 16),
        RematchButton(
          modeName: context.l10n.modeX01Name,
          details: [
            (
              context.l10n.matchFormat,
              game.placementMode
                  ? context.l10n.placementMode
                  : context.l10n.standardMode
            ),
            (
              context.l10n.gameMode_,
              context.l10n.gameSummaryInfo(game.startScore, game.legs, game.sets,
                  placementMode: game.placementMode)
            ),
            // With handicaps the game defaults say little, so the per-player
            // rows below carry the rules instead.
            if (!game.hasHandicaps) ...[
              (context.l10n.checkIn, checkInLabel(context.l10n, game.gameMode)),
              (
                context.l10n.checkOut,
                checkOutLabel(context.l10n, game.checkoutMode)
              ),
            ],
          ],
          slots: game.isTeamGame
              ? game.teams!
                  .map((t) => RematchSlot.team(
                        t.name,
                        [
                          for (final id in t.playerIds)
                            if (namesById[id] != null)
                              RematchSlot.player(
                                namesById[id]!,
                                rules: handicapRulesLabel(
                                    context.l10n, game, id),
                              ),
                        ],
                      ))
                  .toList()
              : players
                  .map((p) => RematchSlot.player(
                        p.name,
                        rules:
                            handicapRulesLabel(context.l10n, game, p.id),
                      ))
                  .toList(),
          onRematch: () =>
              context.read<GameProvider>().startRematch(game, players),
          destination: (_) => const GameScreen(),
        ),
        const SizedBox(height: 16),
        // Final ranking (placement mode only). Slots are keyed by team index in
        // a team game and by player id otherwise, matching how the placement
        // helpers group the throws.
        if (game.placementMode) ...[
          FinalRankingCard(
            throwsById: game.isTeamGame
                ? {
                    for (var ti = 0; ti < game.teams!.length; ti++)
                      ti: (data.allThrows
                          .where((t) =>
                              game.teams![ti].playerIds.contains(t.playerId))
                          .toList()
                        ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt))),
                  }
                : {
                    for (final p in players)
                      p.id!: data.playerThrows[p.id] ?? const <DartThrow>[],
                  },
            namesById: game.isTeamGame
                ? {
                    for (var ti = 0; ti < game.teams!.length; ti++)
                      ti: game.teams![ti].name,
                  }
                : {for (final p in players) p.id!: p.name},
          ),
          const SizedBox(height: 12),
        ],
        // Per-team or per-player stats
        if (game.isTeamGame)
          ...game.teams!.map((team) {
            final members = [
              for (final id in team.playerIds)
                (
                  namesById[id] ?? '',
                  data.playerThrows[id] ?? const <DartThrow>[],
                ),
            ];
            // The team's own throw list, back in the order the team threw them.
            final teamThrows = [for (final m in members) ...m.$2]
              ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt));
            return SummaryPlayerCard(
              name:    team.name,
              throws:  teamThrows,
              legsWon: legsWonFromThrows(teamThrows),
              members: members,
            );
          })
        else
          ...players.map((p) {
            final throws = data.playerThrows[p.id] ?? const <DartThrow>[];
            // In placement mode every slot checks out every leg, so legs won
            // must come from placementRanking() rather than counting checkout
            // throws.
            final legsWonOverride = game.placementMode
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
            return SummaryPlayerCard(
              name:    p.name,
              throws:  throws,
              legsWon: legsWonOverride ?? legsWonFromThrows(throws),
            );
          }),
        const SizedBox(height: 14),
        ThrowLogCard(
          throws: data.allThrows,
          playerName: (id) => namesById[id] ?? '',
          showSet: game.sets > 1,
        ),
      ],
    );
  }
}
