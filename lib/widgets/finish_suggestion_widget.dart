import 'package:flutter/material.dart';
import '../models/game.dart';
import '../utils/finish_calculator.dart';

class FinishSuggestionWidget extends StatelessWidget {
  final int remaining;
  final String? favoriteDouble;
  /// Darts already thrown in the current visit (0, 1, or 2).
  final int dartsThrown;
  /// Checkout rule for the current player.
  final CheckoutMode checkoutMode;

  const FinishSuggestionWidget({
    super.key,
    required this.remaining,
    this.favoriteDouble,
    this.dartsThrown = 0,
    this.checkoutMode = CheckoutMode.doubleOut,
  });

  @override
  Widget build(BuildContext context) {
    // Score 1 only possible in straight-out
    if (remaining > 170 || remaining <= 0) return const SizedBox.shrink();
    if (remaining == 1 && checkoutMode != CheckoutMode.straightOut) {
      return const SizedBox.shrink();
    }

    final maxDarts = (3 - dartsThrown).clamp(1, 3);
    final routes = FinishCalculator.getRoutes(
      remaining,
      favoriteDouble,
      maxDarts: maxDarts,
      checkoutMode: checkoutMode,
    );
    if (routes.primary == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Primary route ──────────────────────────────────────────────
          _RouteRow(
            route: routes.primary!,
            color: cs.onTertiaryContainer,
            bold: true,
          ),
          // ── Alternative route ──────────────────────────────────────────
          if (routes.alternative != null) ...[
            const SizedBox(height: 4),
            _RouteRow(
              route: routes.alternative!,
              color: cs.onTertiaryContainer.withValues(alpha: 0.65),
              bold: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// A single centered checkout route displayed as dart chips with arrows.
class _RouteRow extends StatelessWidget {
  final List<String> route;
  final Color color;
  final bool bold;

  const _RouteRow({
    required this.route,
    required this.color,
    required this.bold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < route.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          _DartChip(
            label: route[i],
            color: color,
            isLast: i == route.length - 1,
            bold: bold,
            theme: theme,
          ),
        ],
      ],
    );
  }
}

class _DartChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLast;
  final bool bold;
  final ThemeData theme;

  const _DartChip({
    required this.label,
    required this.color,
    required this.isLast,
    required this.bold,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Checkout dart (last) gets a subtle underline to distinguish it
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        decoration: isLast ? TextDecoration.underline : null,
        decorationColor: color,
      ),
    );
  }
}
