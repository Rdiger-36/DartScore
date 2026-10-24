import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/capital_provider.dart';
import '../utils/game_labels.dart';
import '../utils/player_label.dart';
import '../widgets/game_info_card.dart';
import '../widgets/rematch_button.dart';
import '../widgets/summary_body.dart';
import 'capital_screen.dart';

/// Post-game summary for Capital: who finished with the most, and what each
/// player's fifteen rounds came to.
class CapitalSummaryScreen extends StatelessWidget {
  const CapitalSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CapitalProvider>();
    final game     = provider.game!;
    final states   = provider.playerStates;
    final winnerId = provider.winnerId;
    final l        = context.l10n;
    final theme    = Theme.of(context);
    final cs       = theme.colorScheme;

    // Capital ranks on the capital alone, so a plain sort is the whole of it.
    // `utils/placement.dart` solves a different problem, the per leg placement
    // points of an X01 game, and does not apply here.
    final sorted = List.of(states)
      ..sort((a, b) => b.total.compareTo(a.total));

    final winnerSlot =
        states.where((s) => s.player.id == winnerId).firstOrNull;

    final header = Center(
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
            winnerSlot == null
                ? l.capitalDraw
                : l.capitalWinner(winnerSlot.label(l)),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.capitalSummaryTitle)),
      body: SummaryBody(
        header: header,
        top: 24,
        bottom: 24,
        result: [
          GameInfoCard(rows: [
            (l.gameLabel, l.modeCapitalName),
            (l.startingOrder, startingOrderLabel(l, game.startingOrder)),
          ]),
        ],
        details: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.capitalSummaryTitle,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  for (final slot in sorted)
                    _SummaryRow(
                      slot: slot,
                      isWinner: winnerId != null && slot.player.id == winnerId,
                    ),
                ],
              ),
            ),
          ),
        ],
        actions: [
          FilledButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.home_rounded),
            label: Text(l.backToHome),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          RematchButton(
            modeName: l.modeCapitalName,
            details: const [],
            slots: states
                .map((s) => RematchSlot.player(s.label(l)))
                .toList(),
            onRematch: () => provider.startRematch(
              game,
              states.map((s) => s.player).toList(),
            ),
            destination: (_) => const CapitalScreen(),
          ),
        ],
      ),
    );
  }
}

/// One player's line in the final table.
class _SummaryRow extends StatelessWidget {
  final CapitalPlayerState slot;
  final bool isWinner;

  const _SummaryRow({required this.slot, required this.isWinner});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
                Text(
                  slot.label(l),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                    color: isWinner ? cs.primary : null,
                  ),
                ),
                Text(
                  l.capitalContractsMet(slot.contractsMet),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${slot.total}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isWinner ? cs.primary : null,
                ),
              ),
              Text(
                l.capitalFinalCapital,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
