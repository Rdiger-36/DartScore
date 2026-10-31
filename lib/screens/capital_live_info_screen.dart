import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../providers/capital_provider.dart';
import '../utils/capital_rules.dart';
import '../utils/capital_stats.dart';
import '../utils/layout.dart';
import '../utils/player_label.dart';
import '../widgets/capital_result.dart';
import '../widgets/stat_row.dart';

/// Live info for one Capital slot: every round it has played so far with the
/// arithmetic behind each, then the numbers that describe the slot.
///
/// Capital does not share `mode_live_info_screen.dart` with the other target
/// modes. Their info lists the last three visits as dart chips, which suits a
/// game where a visit stands on its own; a Capital round only makes sense
/// against the capital it was thrown at, so what this shows is the same round
/// log the result table unfolds, as far as the game has got. It is the history
/// of the game before the game is over.
///
/// Rebuilds from the provider, so a bot's round or the turn moving on shows
/// while the page is open.
class CapitalLiveInfoScreen extends StatelessWidget {
  final CapitalProvider provider;

  /// The slot to describe, by its index in the provider's seating order.
  final int slotIndex;

  const CapitalLiveInfoScreen({
    super.key,
    required this.provider,
    required this.slotIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final l     = context.l10n;
        final theme = Theme.of(context);
        final slot  = provider.playerStates[slotIndex];
        final throws = provider.throwHistory
            .where((t) => t.playerId == slot.player.id)
            .toList();
        final rounds = capitalRounds(throws);
        final stats  = CapitalStats.of(throws);

        return Scaffold(
          appBar: AppBar(
            title: Text(slot.label(l)),
            centerTitle: true,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
              child: ListView(
                padding: contentPadding(context, top: 12, bottom: 24, innerH: 16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l.capitalRoundsSoFar,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          CapitalRoundList(rounds: rounds),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(l.statistics,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          StatRow(
                              label: l.capitalFinalCapital,
                              value: '${slot.total}'),
                          StatRow(
                            label: l.capitalContractsLabel,
                            value: '${stats.contractsMet}'
                                '/${CapitalContract.contractCount}',
                          ),
                          StatRow(
                              label: l.capitalTimesHalved,
                              value: '${stats.timesHalved}'),
                          StatRow(
                              label: l.capitalPerVisit,
                              value: stats.pointsPerVisit.toStringAsFixed(1)),
                          StatRow(
                              label: l.bestVisit,
                              value: l.pointsN(stats.bestVisitPoints)),
                          StatRow(
                              label: l.dartsThrown, value: '${stats.darts}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
