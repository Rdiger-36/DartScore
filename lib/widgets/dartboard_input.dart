import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/game.dart';

class DartEntry {
  final int field;    // 1-20, 25=bull, 0=miss
  final int modifier; // 1=single, 2=double, 3=triple
  final int score;

  const DartEntry({required this.field, required this.modifier, required this.score});

  String get label {
    if (field == 0) return 'Miss';
    if (field == 25) return modifier == 2 ? 'Bull' : '25';
    final prefix = modifier == 2 ? 'D' : modifier == 3 ? 'T' : '';
    return '$prefix$field';
  }
}

class DartboardInput extends StatefulWidget {
  final int remaining;
  final CheckoutMode checkoutMode;
  /// Check-in rule for the current player. In [GameMode.doubleIn] the player
  /// must hit a double before any score is registered this leg.
  final GameMode gameMode;
  /// True once the player has already scored at least one point this leg.
  /// When false and [gameMode] is doubleIn, only doubles count.
  final bool hasCheckedIn;
  /// Fired after every dart / undo / redo so scoreboard + checkout update live.
  /// [dartsInVisit] = darts thrown so far in current visit (1–3).
  final void Function(int runningRemaining, bool isBust, int dartsInVisit) onScoreUpdate;
  /// Fired when the visit (≤3 darts) is complete.
  final void Function(int visitScore, int dartsUsed, bool bust, List<DartEntry> hits) onVisitComplete;

  const DartboardInput({
    super.key,
    required this.remaining,
    required this.checkoutMode,
    this.gameMode = GameMode.straightIn,
    this.hasCheckedIn = true,
    required this.onScoreUpdate,
    required this.onVisitComplete,
  });

  @override
  State<DartboardInput> createState() => _DartboardInputState();
}

class _DartboardInputState extends State<DartboardInput> {
  int _modifier = 1;
  final List<DartEntry> _darts = [];
  final List<DartEntry> _redoStack = [];
  /// Tracks if a check-in double was hit within the current visit.
  bool _checkedInThisVisit = false;

  static const _fields = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  ];

  int get _visitScoreSoFar => _darts.fold(0, (s, d) => s + d.score);
  int get _runningRemaining => widget.remaining - _visitScoreSoFar;
  bool get _isNegative => _runningRemaining < 0;
  bool get _isDoubleIn => widget.gameMode == GameMode.doubleIn;
  bool get _isCheckedIn => widget.hasCheckedIn || _checkedInThisVisit;

  void _notify() {
    // Remaining 1 is unfinishable in double/master-out (no D/T = 1).
    // Only valid if the player is actually in scoring state (checked in).
    final stuck = _runningRemaining == 1 &&
        widget.checkoutMode != CheckoutMode.straightOut &&
        _isCheckedIn;
    final bust = _isNegative || stuck;
    widget.onScoreUpdate(
        bust ? widget.remaining : _runningRemaining, bust, _darts.length);
  }

  void _tapField(int field) {
    if (_darts.length >= 3) return;
    final mod = _modifier;

    int score;
    if (field == 0) {
      score = 0;
    } else if (field == 25) {
      score = mod == 2 ? 50 : 25;
    } else {
      score = field * mod;
    }

    // ── Double-In enforcement ────────────────────────────────────────────
    // Non-double darts before check-in count as thrown (use a dart) but score 0.
    final bool isDouble = field != 0 && mod == 2;
    bool dartScores = true;
    if (_isDoubleIn && !_isCheckedIn) {
      if (isDouble) {
        _checkedInThisVisit = true; // check-in achieved with this dart
      } else {
        dartScores = false;
        score = 0;
      }
    }

    final entry          = DartEntry(field: field, modifier: field == 0 ? 1 : mod, score: score);
    final newVisitTotal  = _visitScoreSoFar + score;
    final newRemaining   = widget.remaining - newVisitTotal;

    setState(() {
      _darts.add(entry);
      _redoStack.clear();
      _modifier = 1;
    });
    _notify();

    bool bust     = false;
    bool endVisit = false;

    if (!dartScores) {
      // Wasted pre-check-in dart — just count the throw, no score impact.
      if (_darts.length == 3) endVisit = true;
    } else if (newRemaining < 0) {
      bust     = true;
      endVisit = true;
    } else if (newRemaining == 0) {
      bool valid = true;
      if (widget.checkoutMode == CheckoutMode.doubleOut) {
        valid = mod == 2 || (field == 25 && mod == 2);
      } else if (widget.checkoutMode == CheckoutMode.masterOut) {
        valid = mod == 2 || mod == 3 || (field == 25 && mod != 3);
      }
      bust     = !valid;
      endVisit = true;
    } else if (newRemaining == 1 &&
               widget.checkoutMode != CheckoutMode.straightOut &&
               _isCheckedIn) {
      bust     = true;
      endVisit = true;
    } else if (_darts.length == 3) {
      endVisit = true;
    }

    if (endVisit) {
      final dartsUsed  = _darts.length;
      final finalScore = bust ? 0 : newVisitTotal;
      final hits = List<DartEntry>.from(_darts);
      setState(() {
        _darts.clear();
        _redoStack.clear();
        _checkedInThisVisit = false; // reset for next visit
      });
      widget.onVisitComplete(finalScore, dartsUsed, bust, hits);
    }
  }

  void _undo() {
    if (_darts.isEmpty) return;
    setState(() {
      _redoStack.add(_darts.removeLast());
    });
    _notify();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _darts.add(_redoStack.removeLast());
    });
    _notify();
  }

  void _finishEarly() {
    if (_darts.isEmpty) return;
    final dartsUsed = _darts.length;
    final score = _visitScoreSoFar;
    final hits = List<DartEntry>.from(_darts);
    setState(() {
      _darts.clear();
      _redoStack.clear();
    });
    widget.onVisitComplete(score, dartsUsed, false, hits);
  }

  @override
  void didUpdateWidget(DartboardInput old) {
    super.didUpdateWidget(old);
    if (old.remaining != widget.remaining && _darts.isNotEmpty) {
      setState(() {
        _darts.clear();
        _redoStack.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dartCount = _darts.length;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
          // Dart progress row with undo/redo
          _DartProgressRow(
            darts: _darts,
            isNegative: _isNegative,
            canUndo: _darts.isNotEmpty,
            canRedo: _redoStack.isNotEmpty,
            onUndo: _undo,
            onRedo: _redo,
          ),
          const SizedBox(height: 10),
          // Modifier
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Single')),
                ButtonSegment(value: 2, label: Text('Double')),
                ButtonSegment(value: 3, label: Text('Triple')),
              ],
              selected: {_modifier},
              onSelectionChanged: (s) => setState(() => _modifier = s.first),
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: 8)),
                textStyle: WidgetStateProperty.all(theme.textTheme.labelMedium),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Number grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.4,
              children: _fields.map((f) => _FieldButton(
                field: f,
                modifier: _modifier,
                disabled: dartCount >= 3,
                onTap: () => _tapField(f),
              )).toList(),
            ),
          ),
          const SizedBox(height: 6),
          // Miss | Bull | Fertig
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Miss',
                    icon: Icons.close,
                    color: cs.errorContainer,
                    textColor: cs.onErrorContainer,
                    disabled: dartCount >= 3,
                    onTap: () => _tapField(0),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _ActionButton(
                    label: _modifier == 2 ? 'Bull (50)' : 'Bull (25)',
                    icon: Icons.adjust,
                    color: cs.secondaryContainer,
                    textColor: cs.onSecondaryContainer,
                    disabled: dartCount >= 3 || _modifier == 3,
                    onTap: () => _tapField(25),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ActionButton(
                    label: context.l10n.done_,
                    icon: Icons.check,
                    color: cs.primaryContainer,
                    textColor: cs.onPrimaryContainer,
                    disabled: dartCount == 0,
                    onTap: _finishEarly,
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
  }
}

// ── Dart progress row ────────────────────────────────────────────────────────

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

class _FieldButton extends StatelessWidget {
  final int field;
  final int modifier;
  final bool disabled;
  final VoidCallback onTap;

  const _FieldButton({
    required this.field,
    required this.modifier,
    required this.disabled,
    required this.onTap,
  });

  Color _bg(ColorScheme cs) {
    if (disabled) return cs.surfaceContainerLow;
    return switch (modifier) {
      2 => cs.secondaryContainer,
      3 => cs.tertiaryContainer,
      _ => cs.surfaceContainerHigh,
    };
  }

  Color _fg(ColorScheme cs) {
    if (disabled) return cs.onSurface.withValues(alpha: 0.35);
    return switch (modifier) {
      2 => cs.onSecondaryContainer,
      3 => cs.onTertiaryContainer,
      _ => cs.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final prefix = modifier == 2 ? 'D' : modifier == 3 ? 'T' : '';

    return Material(
      color: _bg(cs),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: disabled ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$field',
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _fg(cs),
              ),
            ),
            if (modifier > 1)
              Text(
                '$prefix$field',
                style: t.labelSmall?.copyWith(
                  color: _fg(cs).withValues(alpha: 0.65),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final bool disabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.disabled,
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
          padding: const EdgeInsets.symmetric(vertical: 11),
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
