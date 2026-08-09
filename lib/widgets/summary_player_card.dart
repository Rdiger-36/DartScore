import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/dart_throw.dart';
import '../utils/live_stats.dart';

/// One member of a team card: their name and the visits they threw themselves.
typedef SummaryMember = (String name, List<DartThrow> throws);

/// Summary card for one slot of a finished X01 game, shared by the post-game
/// summary and the history detail screen.
///
/// Works for a single player and for a whole team; a team passes [members] and
/// gets a per member breakdown under the combined numbers.
class SummaryPlayerCard extends StatelessWidget {
  /// Player or team name shown in the header.
  final String name;
  /// Every visit of this slot, team members combined.
  final List<DartThrow> throws;
  /// Legs won by this slot. Passed in rather than derived, because placement
  /// mode counts legs differently from "a visit that reached zero".
  final int legsWon;
  /// Sets won, or null where the source does not track sets per slot; then the
  /// header names the legs only.
  final int? setsWon;
  /// The slot's members, empty for an individual player.
  final List<SummaryMember> members;

  const SummaryPlayerCard({
    super.key,
    required this.name,
    required this.throws,
    required this.legsWon,
    this.setsWon,
    this.members = const [],
  });

  /// Whether this card stands for a team rather than a single player.
  bool get isTeam => members.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;
    final stats = LiveThrowStats.fromThrows(throws);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: isTeam
                      ? Icon(Icons.groups_rounded,
                          color: cs.onPrimaryContainer, size: 20)
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        setsWon != null
                            ? l.setsLegsWon(setsWon!, legsWon)
                            : '${l.legsWon}: $legsWon',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _StatRow(l.totalDarts,   '${stats.totalDarts}'),
            _StatRow(l.visits,       '${stats.totalVisits}'),
            _StatRow(l.threeDartAvg, stats.average.toStringAsFixed(2)),
            _StatRow(l.highestVisit, '${stats.highestVisit}'),
            _StatRow(l.busts,        '${stats.busts}'),
            if (isTeam) ...[
              const SizedBox(height: 12),
              Text(
                l.teamPlayers,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              for (final member in members)
                _MemberRow(name: member.$1, throws: member.$2),
            ],
          ],
        ),
      ),
    );
  }
}

/// A label/value row in a summary card's stats list.
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// One team member under a team card: average, highest visit and darts thrown.
class _MemberRow extends StatelessWidget {
  final String name;
  final List<DartThrow> throws;

  const _MemberRow({required this.name, required this.throws});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;
    final stats = LiveThrowStats.fromThrows(throws);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: cs.surfaceContainerHighest,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: theme.textTheme.bodySmall)),
          if (stats.totalDarts == 0)
            Text(
              l.noThrowData,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            )
          else ...[
            Text(
              'Ø ${stats.average.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Text(
              '${l.highAbbr} ${stats.highestVisit}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Text(
              l.dartsShort(stats.totalDarts),
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}
