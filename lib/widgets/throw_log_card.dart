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

    // The margin the stat cards around it carry, so a column
    // of cards comes out one width.
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
///
/// Laid out over two lines, the visit itself on the first and where it belongs
/// in the match on the second. In one line the name, the score, the remaining
/// and the set/leg/darts tail compete for the same width, and the tail is what
/// gets squeezed.
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
        ? '${l.setLabel(t.set)} · ${l.legLabel(t.leg)} · ${l.dartsN(t.dartsUsed)}'
        : '${l.legLabel(t.leg)} · ${l.dartsN(t.dartsUsed)}';

    // Where the second line starts, so it lines up with the name rather than
    // with the score pill in front of it.
    const textIndent = 52.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: t.bust ? cs.onErrorContainer : cs.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '→ ${t.remainingAfter}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: textIndent),
            child: Text(
              where,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
