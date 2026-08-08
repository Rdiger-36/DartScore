import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Full-width "Play Again" button for the summary screens: runs [onRematch] to
/// start a new game with the same settings and players, then replaces the
/// current route with the play screen built by [destination].
///
/// Stateful so the pending start is visible and the button cannot be triggered
/// twice while the new game is being persisted.
class RematchButton extends StatefulWidget {
  /// Starts the new game (typically a provider's `startRematch`).
  final Future<void> Function() onRematch;

  /// Builds the play screen the button navigates to once the game has started.
  final WidgetBuilder destination;

  const RematchButton({
    super.key,
    required this.onRematch,
    required this.destination,
  });

  @override
  State<RematchButton> createState() => _RematchButtonState();
}

class _RematchButtonState extends State<RematchButton> {
  bool _starting = false;

  /// Starts the rematch and opens the play screen, replacing this summary so
  /// the finished game cannot be navigated back into.
  Future<void> _start() async {
    if (_starting) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorLabel = context.l10n.error;
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
