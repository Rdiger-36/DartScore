import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/capital_provider.dart';
import '../utils/game_labels.dart';
import '../utils/player_label.dart';
import '../widgets/capital_result.dart';
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
          CapitalResultCard(
            slots:    states,
            winnerId: winnerId,
            throws:   provider.throwHistory,
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
