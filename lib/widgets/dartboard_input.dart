import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/game_provider.dart';
import '../utils/triple_color.dart';

/// A single dart entered on the board input: which [field] was hit, the
/// [modifier] (single/double/triple) and the resulting [score].
class DartEntry {
  final int field;    // 1-20, 25=bull, 0=miss
  final int modifier; // 1=single, 2=double, 3=triple
  final int score;

  const DartEntry({required this.field, required this.modifier, required this.score});

  /// Short notation for this dart, e.g. `T20`, `D16`, `Bull`, `25` or `Miss`.
  String get label {
    if (field == 0) return 'Miss';
    if (field == 25) return modifier == 2 ? 'Bull' : '25';
    final prefix = modifier == 2 ? 'D' : modifier == 3 ? 'T' : '';
    return '$prefix$field';
  }
}

/// Dartboard-style score entry for X01: a number grid plus single/double/triple
/// modifier, miss and bull. Reads the current player's in-progress visit and
/// undo/redo state from [GameProvider], which also enforces check-in/check-out
/// rules and detects busts. Only the active modifier is local UI state.
class DartboardInput extends StatefulWidget {
  const DartboardInput({super.key});

  @override
  State<DartboardInput> createState() => _DartboardInputState();
}

class _DartboardInputState extends State<DartboardInput> {
  int _modifier = 1;

  static const _fields = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  ];

  /// Registers a tap on [field] (0=miss, 25=bull) with the active modifier.
  void _tapField(int field) {
    context.read<GameProvider>().tapField(field, _modifier);
    setState(() => _modifier = 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = context.watch<GameProvider>();
    final darts = provider.currentVisitDarts;
    final dartCount = darts.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact mode for small screens (e.g. iPhone SE): reduce spacing and
        // increase childAspectRatio so the grid takes less vertical space.
        final compact = constraints.maxHeight < 420;
        final gridSpacing = compact ? 4.0 : 6.0;
        final gridAspectRatio = compact ? 1.7 : 1.4;
        final segmentVPadding = compact ? 4.0 : 8.0;
        final gapAfterProgress = compact ? 6.0 : 10.0;
        final gapAfterSegment = compact ? 6.0 : 12.0;
        final gapBeforeActions = compact ? 4.0 : 6.0;
        final actionVPadding = compact ? 7.0 : 11.0;
        final bottomPad = compact ? 8.0 : 14.0;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
          // Dart progress row with undo/redo
          _DartProgressRow(
            darts: darts,
            isNegative: provider.liveBust,
            canUndo: provider.canUndoDart,
            canRedo: provider.canRedoDart,
            onUndo: provider.undoLastDart,
            onRedo: provider.redoLastDart,
          ),
          SizedBox(height: gapAfterProgress),
          // Modifier
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 1, label: Text(context.l10n.single)),
                ButtonSegment(value: 2, label: Text(context.l10n.double_)),
                ButtonSegment(value: 3, label: Text(context.l10n.triple)),
              ],
              selected: {_modifier},
              onSelectionChanged: (s) => setState(() => _modifier = s.first),
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                    EdgeInsets.symmetric(vertical: segmentVPadding)),
                textStyle: WidgetStateProperty.all(theme.textTheme.labelMedium),
              ),
            ),
          ),
          SizedBox(height: gapAfterSegment),
          // Number grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: gridSpacing,
              crossAxisSpacing: gridSpacing,
              childAspectRatio: gridAspectRatio,
              children: _fields.map((f) => _FieldButton(
                field: f,
                modifier: _modifier,
                disabled: dartCount >= 3,
                compact: compact,
                onTap: () => _tapField(f),
              )).toList(),
            ),
          ),
          SizedBox(height: gapBeforeActions),
          // Miss | Bull | Fertig
          Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, bottomPad),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: context.l10n.miss,
                    icon: Icons.close,
                    color: cs.errorContainer,
                    textColor: cs.onErrorContainer,
                    disabled: dartCount >= 3,
                    verticalPadding: actionVPadding,
                    onTap: () => _tapField(0),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: context.l10n.bullLabel(_modifier == 2),
                    icon: Icons.adjust,
                    color: cs.secondaryContainer,
                    textColor: cs.onSecondaryContainer,
                    disabled: dartCount >= 3 || _modifier == 3,
                    verticalPadding: actionVPadding,
                    onTap: () => _tapField(25),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    label: context.l10n.done_,
                    icon: Icons.check,
                    color: Colors.amber,
                    textColor: Colors.black,
                    disabled: dartCount == 0,
                    verticalPadding: actionVPadding,
                    onTap: provider.finishVisitEarly,
                  ),
                ),
              ],
            ),
          ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}

// ── Dart progress row ────────────────────────────────────────────────────────

/// The three-dart progress strip with undo/redo buttons shown above the grid.
class _DartProgressRow extends StatelessWidget {
  final List<DartEntry> darts;
  final bool isNegative;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const _DartProgressRow({
    required this.darts,
    required this.isNegative,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
      decoration: BoxDecoration(
        color: isNegative ? cs.errorContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Undo button
          _UndoRedoBtn(
            icon: Icons.undo_rounded,
            enabled: canUndo,
            onTap: onUndo,
          ),
          // Three dart slots
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: _DartSlot(
                index: i,
                entry: i < darts.length ? darts[i] : null,
                isActive: i == darts.length,
                isNegative: isNegative,
              ),
            ),
            if (i < 2)
              Container(
                width: 1,
                height: 26,
                color: cs.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
          ],
          // Redo button
          _UndoRedoBtn(
            icon: Icons.redo_rounded,
            enabled: canRedo,
            onTap: onRedo,
          ),
        ],
      ),
    );
  }
}

/// A small undo or redo icon button, dimmed when disabled.
class _UndoRedoBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _UndoRedoBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(
            icon,
            size: 20,
            color: enabled
                ? cs.onSurface
                : cs.onSurface.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}

// ── Dart slot ────────────────────────────────────────────────────────────────

/// One of the three dart slots in the progress strip, showing the thrown dart's
/// label and points or a placeholder for the active/empty slot.
class _DartSlot extends StatelessWidget {
  final int index;
  final DartEntry? entry;
  final bool isActive;
  final bool isNegative;

  const _DartSlot({
    required this.index,
    this.entry,
    required this.isActive,
    required this.isNegative,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final Color accent = isNegative
        ? cs.onErrorContainer
        : (isActive ? cs.primary : cs.onSurfaceVariant);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Dart ${index + 1}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: accent.withValues(alpha: isActive ? 1.0 : 0.55),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          entry?.label ?? (isActive ? '▶' : '—'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: entry != null
                ? (entry!.field == 0 ? cs.error : cs.onSurface)
                : accent,
          ),
        ),
        Text(
          entry != null ? '+${entry!.score}' : ' ',
          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Field button ─────────────────────────────────────────────────────────────

/// A single number button (1-20) in the grid, colored by the active modifier
/// and showing the resulting score for doubles/triples.
class _FieldButton extends StatelessWidget {
  final int field;
  final int modifier;
  final bool disabled;
  final bool compact;
  final VoidCallback onTap;

  const _FieldButton({
    required this.field,
    required this.modifier,
    required this.disabled,
    this.compact = false,
    required this.onTap,
  });

  /// Background color for the current modifier and disabled state.
  Color _bg(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (disabled) return cs.surfaceContainerLow;
    return switch (modifier) {
      2 => cs.secondaryContainer,
      3 => tripleContainerColor(context),
      _ => cs.surfaceContainerHigh,
    };
  }

  /// Foreground color for the current modifier and disabled state.
  Color _fg(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (disabled) return cs.onSurface.withValues(alpha: 0.35);
    return switch (modifier) {
      2 => cs.onSecondaryContainer,
      3 => onTripleContainerColor(context),
      _ => cs.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final prefix = modifier == 2 ? 'D' : modifier == 3 ? 'T' : '';

    final score = field * modifier;
    final notation = '$prefix$field';

    return Material(
      color: _bg(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: disabled ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (compact)
              // Compact: single line — notation (e.g. T20) or just the number
              Text(
                modifier > 1 ? notation : '$field',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _fg(context),
                ),
              )
            else ...[
              // Normal: field number + score for doubles/triples
              Text(
                '$field',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _fg(context),
                ),
              ),
              if (modifier > 1)
                Text(
                  '$score',
                  style: t.labelSmall?.copyWith(
                    color: _fg(context).withValues(alpha: 0.65),
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

/// A labeled icon button used for the Miss / Bull / Done row below the grid.
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool disabled;
  final double verticalPadding;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.disabled,
    this.verticalPadding = 11,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final effectiveColor = disabled ? cs.surfaceContainerLow : color;
    final effectiveFg = disabled ? cs.onSurface.withValues(alpha: 0.35) : textColor;

    return Material(
      color: effectiveColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Column(
            children: [
              Icon(icon, size: 17, color: effectiveFg),
              const SizedBox(height: 2),
              Text(
                label,
                style: t.labelSmall?.copyWith(
                  color: effectiveFg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
