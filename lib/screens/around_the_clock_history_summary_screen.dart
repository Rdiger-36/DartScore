import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/around_the_clock_game.dart';
import '../models/player.dart';
import '../providers/around_the_clock_provider.dart';
import '../utils/layout.dart';

/// Detailed view of a finished Around the Clock game from history, rebuilt by
/// replaying its stored throws through a fresh provider.
class AroundTheClockHistorySummaryScreen extends StatelessWidget {
  final AroundTheClockGame game;
  final List<Player> players;

  const AroundTheClockHistorySummaryScreen({
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
          child: FutureBuilder<AroundTheClockProvider>(
            future: _load(),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final provider = snap.data;
              if (provider == null) {
                return Center(child: Text(context.l10n.noThrowData));
              }
              return _Body(game: game, provider: provider);
            },
          ),
        ),
      ),
    );
  }

  /// Replays the game's throws via a standalone provider instance, reusing
  /// its variant-aware progression/winner logic instead of duplicating it here.
  Future<AroundTheClockProvider> _load() async {
    final provider = AroundTheClockProvider();
    await provider.resumeGame(game, players);
    return provider;
  }
}

/// Renders the replayed game details: variant, players, and per-player progress.
class _Body extends StatelessWidget {
  final AroundTheClockGame game;
  final AroundTheClockProvider provider;

  const _Body({required this.game, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final cs       = theme.colorScheme;
    final l        = context.l10n;
    final states   = provider.playerStates;
    final winnerId = provider.winnerId;
    final total    = aroundTheClockOrder.length;

    final sorted = List.of(states)
      ..sort((a, b) {
        if (a.player.id == winnerId) return -1;
        if (b.player.id == winnerId) return 1;
        final fa = a.finishedAtDart ?? 1 << 30;
        final fb = b.finishedAtDart ?? 1 << 30;
        if (fa != fb) return fa.compareTo(fb);
        return b.progress.compareTo(a.progress);
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
                  l.aroundClockWinner(
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
        _InfoRow(l.gameLabel, l.modeAroundClockName),
        const SizedBox(height: 6),
        _InfoRow(l.gameMode_, _variantLabel(l, game.variant)),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.aroundClockSummaryTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...sorted.map((s) {
                  final isWinner = s.player.id == winnerId;
                  final hit = s.progress.clamp(0, total);
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
                              Text(l.aroundClockProgressN(hit, total),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (s.finishedAtDart != null)
                          Text(l.aroundClockDartsUsed(s.finishedAtDart!),
                              style: theme.textTheme.titleMedium?.copyWith(
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

/// Localized display name for an Around the Clock [variant].
String _variantLabel(AppLocalizations l, AroundTheClockVariant variant) {
  switch (variant) {
    case AroundTheClockVariant.basic:
      return l.aroundClockBasic;
    case AroundTheClockVariant.fullSegments:
      return l.aroundClockFullSegments;
    case AroundTheClockVariant.skipRules:
      return l.aroundClockSkipRules;
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
