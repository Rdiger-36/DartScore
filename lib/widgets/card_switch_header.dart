import 'package:flutter/material.dart';

/// The header row of a setup card that a switch turns on and off: an icon,
/// the title and the switch, as the handicap, team and bot cards have it.
///
/// The whole row answers a tap the way the switch does, like a
/// `SwitchListTile`, so the card does not ask for an aim at the switch alone
/// where every other toggle in the setup takes a tap anywhere on its row.
class CardSwitchHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const CardSwitchHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    // One toggle for a screen reader too, not a label beside a switch.
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
