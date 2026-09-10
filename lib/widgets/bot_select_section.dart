import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/player.dart';
import '../utils/bot_thrower.dart';
import '../utils/player_label.dart';

/// The card under the roster that adds a computer opponent to a game: one
/// chip per tier, and under them a row for every bot picked, saying which
/// slot it throws in and roughly how well.
///
/// Shared by all four setup screens. A tier is picked and dropped by its chip
/// alone; the roster above never lists a bot, and more than one tier may play
/// at once. [selectedPlayers] is the whole selection in throwing order, people
/// included, so a bot's slot number is the one it will really throw in.
class BotSelectSection extends StatelessWidget {
  final List<Player> selectedPlayers;
  final void Function(BotLevel level, bool selected) onToggle;

  const BotSelectSection({
    super.key,
    required this.selectedPlayers,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;

    final picked = {
      for (final p in selectedPlayers)
        if (p.botLevel != null) p.botLevel!,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.botOpponent,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final level in BotLevel.values)
                  FilterChip(
                    label: Text(l.botTier(level)),
                    selected: picked.contains(level),
                    onSelected: (v) => onToggle(level, v),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (picked.isEmpty)
              Text(l.botHint,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant))
            else
              for (var i = 0; i < selectedPlayers.length; i++)
                if (selectedPlayers[i].isBot)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(selectedPlayers[i].label(l)),
                    subtitle: Text(
                      '${l.playerN(i + 1)} · '
                      '${l.botAverageHint(expectedAverageOf(selectedPlayers[i].botLevel!))}',
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
