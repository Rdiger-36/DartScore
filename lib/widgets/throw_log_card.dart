import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/dart_throw.dart';

/// The complete throw log of a finished X01 game, shared by the post-game
/// summary and the history detail screen so both read the same way.
class ThrowLogCard extends StatelessWidget {
  /// Every visit of the game in throwing order.
  final List<DartThrow> throws;
  /// Resolves a visit's player id to the name shown in front of the row.
  final String Function(int playerId) playerName;
  /// Whether to name the set as well; pointless in a single-set game.
  final bool showSet;

  const ThrowLogCard({
    super.key,
    required this.throws,
    required this.playerName,
    this.showSet = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.allThrows,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final t in throws)
              _ThrowLogRow(
                t: t,
                playerName: playerName(t.playerId),
                showSet: showSet,
              ),
          ],
        ),
      ),
    );
  }
}

/// A single visit in the throw log: thrower, score, resulting remaining and
/// where in the match it happened.
class _ThrowLogRow extends StatelessWidget {
  final DartThrow t;
  final String playerName;
  final bool showSet;

  const _ThrowLogRow({
    required this.t,
    required this.playerName,
    required this.showSet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;

    final where = showSet
        ? '${l.setLabel(t.set)} · ${l.legLabel(t.leg)} · ${l.dartsShort(t.dartsUsed)}'
        : '${l.legLabel(t.leg)} · ${l.dartsShort(t.dartsUsed)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              playerName,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: t.bust ? cs.errorContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              t.bust ? l.bust.toUpperCase() : '${t.score}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: t.bust ? cs.onErrorContainer : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '→ ${t.remainingAfter}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            where,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
