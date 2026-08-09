import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// One label/value line of a [GameInfoCard].
typedef GameInfoRow = (String label, String value);

/// Card listing the settings a finished game was played with, so the post-game
/// summary and the history detail describe a game the same way and in the same
/// shape as the surrounding stat cards.
///
/// Set [dense] on the history screens, whose cards use a tighter scale.
class GameInfoCard extends StatelessWidget {
  final List<GameInfoRow> rows;
  final bool dense;

  const GameInfoCard({super.key, required this.rows, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(dense ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.gameInfo,
              style: (dense
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...rows.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(r.$1, style: theme.textTheme.bodyMedium),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          r.$2,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
