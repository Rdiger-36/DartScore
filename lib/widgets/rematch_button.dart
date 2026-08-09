import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// One label/value line of the rematch confirmation dialog, e.g. the variant
/// or the leg/set format of the game that is about to be repeated.
typedef RematchDetail = (String label, String value);

/// One participant of the game that would be repeated: either a single player
/// or a team together with the members that play for it.
class RematchSlot {
  /// Team name, or the player's name for an individual slot.
  final String name;

  /// Names of the team's members; empty for an individual slot.
  final List<String> members;

  const RematchSlot.player(this.name) : members = const [];
  const RematchSlot.team(this.name, this.members);

  /// Whether this slot is a team whose members should be listed.
  bool get isTeam => members.isNotEmpty;
}

/// Full-width "Play Again" button for the summary screens: asks for
/// confirmation, showing the mode, settings and players that would be reused,
/// then runs [onRematch] and replaces the current route with the play screen
/// built by [destination].
///
/// Stateful so the pending start is visible and the button cannot be triggered
/// twice while the new game is being persisted.
class RematchButton extends StatefulWidget {
  /// Localized name of the game mode, shown first in the dialog.
  final String modeName;

  /// Settings of the finished game, listed under the mode in the dialog.
  final List<RematchDetail> details;

  /// The participating players, or the teams and their members in a team game.
  final List<RematchSlot> slots;

  /// Starts the new game (typically a provider's `startRematch`).
  final Future<void> Function() onRematch;

  /// Builds the play screen the button navigates to once the game has started.
  final WidgetBuilder destination;

  const RematchButton({
    super.key,
    required this.modeName,
    required this.details,
    required this.slots,
    required this.onRematch,
    required this.destination,
  });

  @override
  State<RematchButton> createState() => _RematchButtonState();
}

class _RematchButtonState extends State<RematchButton> {
  bool _starting = false;

  /// Asks for confirmation and, if granted, starts the rematch and opens the
  /// play screen, replacing this summary so the finished game cannot be
  /// navigated back into. Declining just closes the dialog and leaves the
  /// summary as it was.
  Future<void> _start() async {
    if (_starting) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorLabel = context.l10n.error;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RematchConfirmDialog(
        modeName: widget.modeName,
        details: widget.details,
        slots: widget.slots,
      ),
    );
    if (confirmed != true) return;

    setState(() => _starting = true);
    try {
      await widget.onRematch();
      navigator.pushReplacement(
        MaterialPageRoute(builder: widget.destination),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        messenger.showSnackBar(SnackBar(content: Text('$errorLabel: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _starting ? null : _start,
      icon: _starting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.replay_rounded),
      label: Text(context.l10n.playAgain),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

/// Confirmation dialog listing what the rematch would reuse: the mode, the
/// per-mode settings and the players. Pops `true` to start, `false` to cancel.
class _RematchConfirmDialog extends StatelessWidget {
  final String modeName;
  final List<RematchDetail> details;
  final List<RematchSlot> slots;

  const _RematchConfirmDialog({
    required this.modeName,
    required this.details,
    required this.slots,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l.playAgainTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogRow(l.gameLabel, modeName),
            ...details.map((d) => _DialogRow(d.$1, d.$2)),
            // Team games get one row per team so the members are visible;
            // individual games stay on a single row of names.
            if (slots.any((s) => s.isTeam))
              ...slots.map((s) => _DialogRow(
                    s.name,
                    s.isTeam ? s.members.join(', ') : s.name,
                  ))
            else
              _DialogRow(l.playersTitle, slots.map((s) => s.name).join(', ')),
            const SizedBox(height: 16),
            Text(l.playAgainQuestion, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.startGame),
        ),
      ],
    );
  }
}

/// A label/value line in the rematch confirmation dialog.
class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
