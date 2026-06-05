import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/cricket_game.dart';
import '../providers/cricket_provider.dart';
import '../utils/layout.dart';
import 'cricket_summary_screen.dart';

class CricketScreen extends StatelessWidget {
  const CricketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CricketProvider>(
      builder: (context, provider, _) {
        if (provider.game == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (provider.gameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CricketSummaryScreen()),
            );
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return _CricketGameView(provider: provider);
      },
    );
  }
}

// ── Main game view ────────────────────────────────────────────────────────────

class _CricketGameView extends StatelessWidget {
  final CricketProvider provider;
  const _CricketGameView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l          = context.l10n;
    final theme      = Theme.of(context);
    final cs         = theme.colorScheme;
    final game       = provider.game!;
    final states     = provider.playerStates;
    final currentIdx = provider.currentPlayerIndex;
    final current    = provider.currentPlayerState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cricket'),
        actions: [
          if (provider.canUndo)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: l.undo,
              onPressed: () => provider.undoLastDart(),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l.cricketQuit,
            onPressed: () => _confirmQuit(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Scoreboard ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: contentPadding(context, top: 8, bottom: 8, innerH: 12),
              child: _CricketBoard(
                states:     states,
                currentIdx: currentIdx,
                game:       game,
              ),
            ),
          ),
          // ── Input area ────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current player + dart counter
                    Row(
                      children: [
                        Text(
                          current.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        const Spacer(),
                        _DartDots(count: provider.dartsInVisit),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _CricketInput(
                      provider:    provider,
                      scoringMode: game.scoringMode,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmQuit(BuildContext context) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.quitTitle),
        content: Text(l.quitBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(l.leave),
          ),
        ],
      ),
    );
  }
}

// ── Cricket Board ─────────────────────────────────────────────────────────────

class _CricketBoard extends StatelessWidget {
  final List<CricketPlayerState> states;
  final int currentIdx;
  final CricketGame game;

  const _CricketBoard({
    required this.states,
    required this.currentIdx,
    required this.game,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ── Header row: player names + scores ──────────────────────────
            Row(
              children: [
                const SizedBox(width: 52),
                ...states.indexed.map((e) {
                  final i = e.$1;
                  final s = e.$2;
                  final isActive = i == currentIdx;
                  return Expanded(
                    child: Column(
                      children: [
                        Text(
                          s.displayName,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isActive ? cs.primary : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.score}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isActive ? cs.primary : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            // ── Field rows ─────────────────────────────────────────────────
            ...cricketFields.map((field) {
              final allClosed =
                  states.every((s) => s.hasClosedField(field));
              return _FieldRow(
                field:     field,
                states:    states,
                allClosed: allClosed,
                l:         l,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final int field;
  final List<CricketPlayerState> states;
  final bool allClosed;
  final AppLocalizations l;

  const _FieldRow({
    required this.field,
    required this.states,
    required this.allClosed,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final label = field == 25 ? l.bull : '$field';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: allClosed
                    ? cs.onSurface.withValues(alpha: 0.3)
                    : cs.onSurface,
              ),
            ),
          ),
          ...states.map((s) {
            final marks = s.marks[field] ?? 0;
            return Expanded(
              child: Center(child: _MarksWidget(marks: marks)),
            );
          }),
        ],
      ),
    );
  }
}

// ── Marks widget: shows /, X, or ⊗ ──────────────────────────────────────────

class _MarksWidget extends StatelessWidget {
  final int marks;
  const _MarksWidget({required this.marks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (marks == 0) {
      return const SizedBox(width: 36, height: 36);
    }

    if (marks >= 3) {
      // Closed: circle with X
      return SizedBox(
        width: 36,
        height: 36,
        child: CustomPaint(painter: _ClosedPainter(color: cs.primary)),
      );
    }

    // 1 or 2 marks: slash(es)
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(
          painter: _MarksPainter(marks: marks, color: cs.onSurface)),
    );
  }
}

class _MarksPainter extends CustomPainter {
  final int marks;
  final Color color;
  const _MarksPainter({required this.marks, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.38;

    // First slash: bottom-left to top-right
    canvas.drawLine(
      Offset(cx - r, cy + r),
      Offset(cx + r, cy - r),
      paint,
    );
    if (marks >= 2) {
      // Second slash: top-left to bottom-right → forms X
      canvas.drawLine(
        Offset(cx - r, cy - r),
        Offset(cx + r, cy + r),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) =>
      old.marks != marks || old.color != color;
}

class _ClosedPainter extends CustomPainter {
  final Color color;
  const _ClosedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.42;

    // Circle
    canvas.drawCircle(Offset(cx, cy), r, paint);

    // X inside
    final xi = r * 0.6;
    canvas.drawLine(Offset(cx - xi, cy + xi), Offset(cx + xi, cy - xi), paint);
    canvas.drawLine(Offset(cx - xi, cy - xi), Offset(cx + xi, cy + xi), paint);
  }

  @override
  bool shouldRepaint(_ClosedPainter old) => old.color != color;
}

// ── Dart dot indicator ────────────────────────────────────────────────────────

class _DartDots extends StatelessWidget {
  final int count;
  const _DartDots({required this.count});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final filled = i < count;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? cs.primary : cs.outlineVariant,
          ),
        );
      }),
    );
  }
}

// ── Cricket Input ─────────────────────────────────────────────────────────────

class _CricketInput extends StatefulWidget {
  final CricketProvider provider;
  final CricketScoringMode scoringMode;

  const _CricketInput({
    required this.provider,
    required this.scoringMode,
  });

  @override
  State<_CricketInput> createState() => _CricketInputState();
}

class _CricketInputState extends State<_CricketInput> {
  int? _selectedField;

  bool get _isStandard =>
      widget.scoringMode == CricketScoringMode.standard;

  Future<void> _onFieldTap(int field) async {
    if (!_isStandard) {
      // Simple mode: always single
      await widget.provider.recordDart(field, 1);
      setState(() => _selectedField = null);
    } else {
      setState(() => _selectedField = field);
    }
  }

  Future<void> _onMultiplierTap(int multiplier) async {
    if (_selectedField == null) return;
    final field = _selectedField!;
    setState(() => _selectedField = null);
    await widget.provider.recordDart(field, multiplier);
  }

  Future<void> _onMiss() async {
    setState(() => _selectedField = null);
    await widget.provider.recordDart(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final states = widget.provider.playerStates;
    final l      = context.l10n;

    if (_selectedField != null && _isStandard) {
      // Show multiplier selector
      return _MultiplierRow(
        field:      _selectedField!,
        onSelected: _onMultiplierTap,
        onCancel:   () => setState(() => _selectedField = null),
        l:          l,
      );
    }

    // Show field grid
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing:     8,
          runSpacing:  8,
          alignment:   WrapAlignment.center,
          children: [
            ...cricketFields.map((field) {
              final allClosed =
                  states.every((s) => s.hasClosedField(field));
              final label = field == 25 ? l.bull : '$field';
              return _FieldButton(
                label:      label,
                allClosed:  allClosed,
                onTap:      allClosed ? null : () => _onFieldTap(field),
              );
            }),
            _MissButton(onTap: _onMiss, l: l),
          ],
        ),
      ],
    );
  }
}

class _FieldButton extends StatelessWidget {
  final String label;
  final bool allClosed;
  final VoidCallback? onTap;

  const _FieldButton({
    required this.label,
    required this.allClosed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: allClosed
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: allClosed
                        ? cs.onSurface.withValues(alpha: 0.3)
                        : cs.onSecondaryContainer,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissButton extends StatelessWidget {
  final VoidCallback onTap;
  final AppLocalizations l;
  const _MissButton({required this.onTap, required this.l});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 56,
      child: Material(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              l.cricketMiss,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onErrorContainer,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiplierRow extends StatelessWidget {
  final int field;
  final void Function(int) onSelected;
  final VoidCallback onCancel;
  final AppLocalizations l;

  const _MultiplierRow({
    required this.field,
    required this.onSelected,
    required this.onCancel,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final label = field == 25 ? l.bull : '$field';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MultBtn(label: l.single, sub: '×1', onTap: () => onSelected(1)),
            const SizedBox(width: 10),
            _MultBtn(label: l.double_, sub: '×2', onTap: () => onSelected(2)),
            const SizedBox(width: 10),
            if (field != 25) // Bull has no triple
              _MultBtn(label: l.triple, sub: '×3', onTap: () => onSelected(3)),
          ],
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: onCancel,
          child: Text(l.cancel),
        ),
      ],
    );
  }
}

class _MultBtn extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _MultBtn({required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 80,
      height: 64,
      child: Material(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      )),
              Text(sub,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSecondaryContainer.withValues(alpha: 0.7),
                      )),
            ],
          ),
        ),
      ),
    );
  }
}
