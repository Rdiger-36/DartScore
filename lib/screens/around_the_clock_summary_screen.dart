import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/around_the_clock_game.dart';
import '../providers/around_the_clock_provider.dart';
import '../utils/layout.dart';

class AroundTheClockSummaryScreen extends StatelessWidget {
  const AroundTheClockSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AroundTheClockProvider>();
    final states   = provider.playerStates;
    final winnerId = provider.winnerId;
    final l        = context.l10n;
    final theme    = Theme.of(context);
    final cs       = theme.colorScheme;
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

    return Scaffold(
      appBar: AppBar(title: Text(l.aroundClockSummaryTitle)),
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
            const SizedBox(height: 28),
          ],

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
                                Text(
                                  l.aroundClockProgressN(hit, total),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (s.finishedAtDart != null)
                            Text(
                              l.aroundClockDartsUsed(s.finishedAtDart!),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isWinner ? cs.primary : null,
                              ),
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
