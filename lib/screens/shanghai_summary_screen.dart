import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/shanghai_game.dart';
import '../providers/shanghai_provider.dart';
import '../utils/layout.dart';

/// Post-game summary for Shanghai: the winner and each player's final score,
/// ranked.
class ShanghaiSummaryScreen extends StatelessWidget {
  const ShanghaiSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShanghaiProvider>();
    final game     = provider.game!;
    final states   = provider.playerStates;
    final winnerId = provider.winnerId;
    final l        = context.l10n;
    final theme    = Theme.of(context);
    final cs       = theme.colorScheme;

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

    return Scaffold(
      appBar: AppBar(title: Text(l.shanghaiSummaryTitle)),
      body: ListView(
        padding: contentPadding(context, top: 24, bottom: 24, innerH: 16),
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
                    child: Icon(Icons.emoji_events_rounded,
                        size: 52, color: cs.primary),
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
            const SizedBox(height: 28),
          ],

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
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          if (isWinner)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child:
                                  Icon(Icons.emoji_events_rounded, size: 18),
                            )
                          else
                            const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.displayName,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: isWinner
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isWinner ? cs.primary : null,
                                  ),
                                ),
                                if (isSequential)
                                  Text(
                                    s.finishedAtDart != null
                                        ? l.shanghaiDartsUsed(s.finishedAtDart!)
                                        : '${l.shanghaiTarget}: ${s.progress}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${s.score}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isWinner ? cs.primary : null,
                                ),
                              ),
                              Text(
                                l.shanghaiTotalScore,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.home_rounded),
            label: Text(l.backToHome),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
