import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/cricket_game.dart';
import '../providers/cricket_provider.dart';
import '../utils/layout.dart';

/// Post-game summary for Cricket: the winner plus each player's final marks and
/// score.
class CricketSummaryScreen extends StatelessWidget {
  const CricketSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CricketProvider>();
    final game     = provider.game!;
    final states   = provider.playerStates;
    final winnerId = provider.winnerId;
    final l        = context.l10n;
    final theme    = Theme.of(context);
    final cs       = theme.colorScheme;

    final isCutThroat = game.variant == CricketVariant.cutThroat;

    // Sort for display: winner first, then by score (asc for CT, desc for normal)
    final sorted = List.of(states)
      ..sort((a, b) {
        if (a.player.id == winnerId) return -1;
        if (b.player.id == winnerId) return 1;
        return isCutThroat
            ? a.score.compareTo(b.score)
            : b.score.compareTo(a.score);
      });

    return Scaffold(
      appBar: AppBar(title: Text(l.cricketSummaryTitle)),
      body: ListView(
        padding: contentPadding(context, top: 24, bottom: 24, innerH: 16),
        children: [
          // ── Winner banner ────────────────────────────────────────────────
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
                    l.cricketWinner(
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

          // ── Player results ───────────────────────────────────────────────
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
                  ...sorted.map((s) {
                    final isWinner = s.player.id == winnerId;
                    final fieldsClosed =
                        cricketFields.where((f) => s.hasClosedField(f)).length;
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
                                  '$fieldsClosed/7 ${l.cricketFieldsClosed}',
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
                                l.cricketTotalScore,
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

          // ── Final field status ───────────────────────────────────────────
          const SizedBox(height: 16),
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
                  // Header
                  Row(
                    children: [
                      const SizedBox(width: 52),
                      ...sorted.map((s) => Expanded(
                            child: Text(s.displayName,
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
                                style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold)),
                          ),
                          ...sorted.map((s) {
                            final marks = s.marks[field] ?? 0;
                            return Expanded(
                              child: Center(
                                child: _SummaryMark(closed: marks >= 3),
                              ),
                            );
                          }),
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

/// A compact open/closed indicator for one Cricket field in the summary grid.
class _SummaryMark extends StatelessWidget {
  final bool closed;
  const _SummaryMark({required this.closed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Icon(
      closed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
      size: 20,
      color: closed ? cs.primary : cs.outlineVariant,
    );
  }
}
