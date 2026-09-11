import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/player.dart';
import '../utils/bot_thrower.dart';
import '../utils/player_label.dart';

/// The card under the roster that adds a computer opponent to a game: a
/// switch in the header like the handicap and team cards, and once it is on,
/// one chip per tier and under them a row for every bot picked, saying which
/// slot it throws in and roughly how well.
///
/// Shared by all four setup screens. A tier is picked and dropped by its chip
/// alone; the roster above never lists a bot, and more than one tier may play
/// at once. [selectedPlayers] is the whole selection in throwing order, people
/// included, so a bot's slot number is the one it will really throw in.
/// Switching the card off drops every bot from the selection, which the
/// caller does in [onEnabledChanged].
class BotSelectSection extends StatelessWidget {
  final bool enabled;
  final List<Player> selectedPlayers;
  final ValueChanged<bool> onEnabledChanged;
  final void Function(BotLevel level, bool selected) onToggle;

  const BotSelectSection({
    super.key,
    required this.enabled,
    required this.selectedPlayers,
    required this.onEnabledChanged,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined,
                    size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l.botOpponent,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
            if (enabled) ...[
            const SizedBox(height: 4),
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
            const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
