import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../providers/bot_runner.dart';

/// A thin bar under the darts that drains over the pause a finished visit
/// stays on the board for, so the wait is visible and its length too. Keeps
/// its height when nothing is pending, so the input under it does not jump.
class VisitPauseBar extends StatefulWidget {
  final bool pending;

  const VisitPauseBar({super.key, required this.pending});

  @override
  State<VisitPauseBar> createState() => _VisitPauseBarState();
}

class _VisitPauseBarState extends State<VisitPauseBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TurnPacing.visitPause,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pending) _start();
  }

  @override
  void didUpdateWidget(VisitPauseBar old) {
    super.didUpdateWidget(old);
    if (widget.pending && !old.pending) {
      _start();
    } else if (!widget.pending && old.pending) {
      _controller.stop();
    }
  }

  /// Runs the bar down over the pause in force right now, which the settings
  /// may have changed since the widget was built.
  void _start() {
    _controller.duration = TurnPacing.visitPause;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 3,
      child: widget.pending
          ? AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => LinearProgressIndicator(
                value: 1 - _controller.value,
                minHeight: 3,
                color: cs.primary,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            )
          : null,
    );
  }
}

/// The button that ends the pause a finished visit stays on the board for,
/// with the [VisitPauseBar] running out above it at the same width. The
/// target modes show it where their throw buttons sit, which are locked
/// meanwhile anyway, so the hand finds it where it already is; [width] is
/// three of those buttons and their gaps, so it takes no more room than
/// they do.
class ContinueButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double width;
  final double height;

  const ContinueButton({
    super.key,
    required this.onPressed,
    required this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const VisitPauseBar(pending: true),
            const SizedBox(height: 6),
            SizedBox(
              height: height,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(context.l10n.continueNow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
