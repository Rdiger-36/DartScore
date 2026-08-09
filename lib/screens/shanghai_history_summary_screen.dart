import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/shanghai_game.dart';
import '../models/player.dart';
import '../providers/shanghai_provider.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../widgets/game_info_card.dart';
import '../widgets/rematch_button.dart';
import 'shanghai_screen.dart';

/// Detailed view of a finished Shanghai game from history, rebuilt by replaying
/// its stored throws through a fresh provider.
class ShanghaiHistorySummaryScreen extends StatelessWidget {
  final ShanghaiGame game;
  final List<Player> players;

  const ShanghaiHistorySummaryScreen({
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
          child: FutureBuilder<ShanghaiProvider>(
            future: _load(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final provider = snap.data;
              if (provider == null) {
                return Center(child: Text(context.l10n.noThrowData));
              }
              return _Body(game: game, players: players, provider: provider);
            },
          ),
        ),
      ),
    );
  }

  /// Replays the game's throws via a standalone provider instance, reusing
  /// its variant-aware scoring/winner logic instead of duplicating it here.
  Future<ShanghaiProvider> _load() async {
    final provider = ShanghaiProvider();
    await provider.resumeGame(game, players);
    return provider;
  }
}

/// Renders the replayed game details: variant, players, and final scores.
class _Body extends StatelessWidget {
  final ShanghaiGame game;
  final List<Player> players;
  final ShanghaiProvider provider;

  const _Body({
    required this.game,
    required this.players,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final cs     = theme.colorScheme;
    final l      = context.l10n;
    final states = provider.playerStates;
    final winnerId = provider.winnerId;
    final isSequential = game.variant == ShanghaiVariant.sequential;

    final sorted = List.of(states)
      ..sort((a, b) {
        if (a.player.id == winnerId) return -1;
        if (b.player.id == winnerId) return 1;
        if (isSequential) {
          final fa = a.finishedAtDart ?? 1 << 30;
          final fb = b.finishedAtDart ?? 1 << 30;
          if (fa != fb) return fa.compareTo(fb);
        }
        return b.score.compareTo(a.score);
      });

    return ListView(
      padding: contentPadding(context, top: 16, bottom: 24, innerH: 12),
      children: [
        if (winnerId != null) ...[
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
                  l.shanghaiWinner(
                      states.firstWhere((s) => s.player.id == winnerId).displayName),
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
          (l.gameLabel, l.modeShanghaiName),
          (l.shanghaiVariant, shanghaiVariantLabel(l, game.variant)),
        ]),
        const SizedBox(height: 16),

        // ── Rematch ────────────────────────────────────────────────────────
        RematchButton(
          modeName: l.modeShanghaiName,
          details: [
            (l.shanghaiVariant, shanghaiVariantLabel(l, game.variant)),
          ],
          slots: states
              .map((s) => s.isTeamSlot
                  ? RematchSlot.team(s.displayName,
                      s.players.map((p) => RematchSlot.player(p.name)).toList())
                  : RematchSlot.player(s.displayName))
              .toList(),
          onRematch: () =>
              context.read<ShanghaiProvider>().startRematch(game, players),
          destination: (_) => const ShanghaiScreen(),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.shanghaiSummaryTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...sorted.map((s) {
                  final isWinner = s.player.id == winnerId;
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
                              Text(s.displayName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: isWinner
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isWinner ? cs.primary : null,
                                  )),
                              if (s.isTeamSlot)
                                Text(
                                  s.players.map((p) => p.name).join(' & '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                              if (isSequential)
                                Text(
                                  s.finishedAtDart != null
                                      ? l.shanghaiDartsUsed(s.finishedAtDart!)
                                      : '${l.shanghaiTarget}: ${s.progress}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        Text('${s.score}',
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
      ],
    );
  }
}

