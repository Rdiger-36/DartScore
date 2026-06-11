import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Numeric score entry for X01: a keypad to type a visit total (0-180), a
/// darts-used selector (1-3), and quick-score chips for common scores. Reports
/// the entered score and darts via [onSubmit].
class NumPad extends StatefulWidget {
  final int maxScore;
  final void Function(int score, int darts) onSubmit;

  const NumPad({super.key, required this.maxScore, required this.onSubmit});

  @override
  State<NumPad> createState() => _NumPadState();
}

class _NumPadState extends State<NumPad> {
  String _input = '';
  int _darts = 3;

  /// Appends digit [v] to the input, capped at three characters.
  void _tap(String v) {
    if (_input.length >= 3) return;
    setState(() => _input += v);
  }

  /// Removes the last entered digit.
  void _backspace() {
    if (_input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  /// Validates the typed score (0-180) and submits it with the selected darts,
  /// then resets the input.
  void _submit() {
    final score = int.tryParse(_input) ?? 0;
    if (score < 0 || score > 180) return;
    widget.onSubmit(score, _darts);
    setState(() {
      _input = '';
      _darts = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Display
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _input.isEmpty ? '0' : _input,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: _backspace,
                icon: const Icon(Icons.backspace_outlined),
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        // Darts selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${context.l10n.darts_}: ', style: theme.textTheme.bodyMedium),
              for (final d in [1, 2, 3])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('$d'),
                    selected: _darts == d,
                    onSelected: (_) => setState(() => _darts = d),
                  ),
                ),
            ],
          ),
        ),
        // Keypad
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              for (final n in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                _NumKey(label: n, onTap: () => _tap(n)),
              _NumKey(label: '0', onTap: () => _tap('0')),
              _NumKey(
                label: context.l10n.miss.toUpperCase(),
                onTap: () {
                  setState(() => _input = '0');
                  _submit();
                },
                color: Theme.of(context).colorScheme.errorContainer,
                textColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              _NumKey(
                label: context.l10n.ok,
                onTap: _submit,
                color: Theme.of(context).colorScheme.primaryContainer,
                textColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
        // Quick-score buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [26, 41, 45, 60, 81, 85, 100, 140, 180]
                .where((s) => s <= widget.maxScore)
                .map(
                  (s) => ActionChip(
                    label: Text('$s'),
                    onPressed: () {
                      setState(() => _input = '$s');
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// A single keypad key (digit, Miss or OK) with optional accent colors.
class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;

  const _NumKey({
    required this.label,
    required this.onTap,
    this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color ?? theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
