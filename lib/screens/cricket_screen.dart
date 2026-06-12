import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/cricket_game.dart';
import '../providers/cricket_provider.dart';
import '../utils/layout.dart';
import '../utils/triple_color.dart';
import '../widgets/cricket_marks_widget.dart';
import 'cricket_summary_screen.dart';

/// Live Cricket game screen. Watches the provider and routes to the summary
/// when the game ends, otherwise shows the play view.
class CricketScreen extends StatelessWidget {
  const CricketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CricketProvider>(
      builder: (context, provider, _) {
        if (provider.game == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.gameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CricketSummaryScreen()),
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _CricketGameView(provider: provider);
      },
    );
  }
}

// ── Main game view ────────────────────────────────────────────────────────────

/// The in-play layout: the marks/score board plus the dart input area.
class _CricketGameView extends StatelessWidget {
  final CricketProvider provider;
  const _CricketGameView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final game = provider.game!;
    final states = provider.playerStates;
    final currentIdx = provider.currentPlayerIndex;
    final current = provider.currentPlayerState;

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
                states: states,
                currentIdx: currentIdx,
                throwCount: provider.throwCount,
                game: game,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current player/team + dart counter
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              current.displayName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            if (current.isTeamSlot)
                              Text(
                                current.player.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        _DartDots(count: provider.dartsInVisit),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _CricketInput(
                      provider: provider,
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

  /// Asks the user to confirm leaving the game, popping back if they accept.
  void _confirmQuit(BuildContext context) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.quitTitle),
        content: Text(l.quitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
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

const double _kLabelColumnWidth = 52;
const double _kPlayerColumnWidth = 92;
const double _kHeaderHeight = 52;

/// Horizontally scrollable grid of Cricket fields by player, showing marks and
/// scores and auto-scrolling to keep the active player's column in view.
class _CricketBoard extends StatefulWidget {
  final List<CricketPlayerState> states;
  final int currentIdx;
  final int throwCount;
  final CricketGame game;

  const _CricketBoard({
    required this.states,
    required this.currentIdx,
    required this.throwCount,
    required this.game,
  });

  @override
  State<_CricketBoard> createState() => _CricketBoardState();
}

class _CricketBoardState extends State<_CricketBoard> {
  final ScrollController _hController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrentPlayer());
  }

  @override
  void didUpdateWidget(covariant _CricketBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refocus on every turn change AND every recorded dart (including undo),
    // so the active player's column is always scrolled into view.
    if (oldWidget.currentIdx != widget.currentIdx ||
        oldWidget.throwCount != widget.throwCount) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusCurrentPlayer(),
      );
    }
  }

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  /// Smoothly scrolls the active player's column to the center of the viewport.
  void _focusCurrentPlayer() {
    if (!_hController.hasClients) return;

    final viewport = _hController.position.viewportDimension;
    final columnLeft = widget.currentIdx * _kPlayerColumnWidth;
    final target = (columnLeft - (viewport - _kPlayerColumnWidth) / 2).clamp(
      0.0,
      _hController.position.maxScrollExtent,
    );

    _hController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    final states = widget.states;
    final currentIdx = widget.currentIdx;
    final headerHeight = widget.game.isTeamGame
        ? _kHeaderHeight + 14
        : _kHeaderHeight;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fixed field-label column ────────────────────────────────────
            SizedBox(
              width: _kLabelColumnWidth,
              child: Column(
                children: [
                  SizedBox(height: headerHeight), // header spacer
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  ...cricketFields.map((field) {
                    final allClosed = states.every(
                      (s) => s.hasClosedField(field),
                    );
                    final label = field == 25 ? l.bull : '$field';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: SizedBox(
                        height: 40,
                        child: Center(
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
                      ),
                    );
                  }),
                ],
              ),
            ),
            // ── Scrollable player columns (focused on the active player) ────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridWidth = (_kPlayerColumnWidth * states.length).clamp(
                    constraints.maxWidth,
                    double.infinity,
                  );
                  return SingleChildScrollView(
                    controller: _hController,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: player names + scores
                        Row(
                          children: states.indexed.map((e) {
                            final i = e.$1;
                            final s = e.$2;
                            final isActive = i == currentIdx;
                            return SizedBox(
                              width: _kPlayerColumnWidth,
                              height: headerHeight,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    s.displayName,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: isActive
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isActive
                                              ? cs.primary
                                              : cs.onSurface,
                                        ),
                                  ),
                                  if (s.isTeamSlot)
                                    Text(
                                      s.player.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: isActive
                                                ? cs.primary.withValues(
                                                    alpha: 0.75,
                                                  )
                                                : cs.onSurfaceVariant,
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
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: gridWidth,
                          child: const Divider(height: 1),
                        ),
                        const SizedBox(height: 4),
                        // Field rows
                        ...cricketFields.map((field) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: states.map((s) {
                                final marks = s.marks[field] ?? 0;
                                return SizedBox(
                                  width: _kPlayerColumnWidth,
                                  height: 40,
                                  child: Center(
                                    child: CricketMarksWidget(marks: marks),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Marks widget: shows /, X, or ⊗ ──────────────────────────────────────────

// ── Dart dot indicator ────────────────────────────────────────────────────────

/// Three dots showing how many darts of the current visit have been thrown.
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

/// Cricket dart input: a field grid where, in standard scoring, tapping a field
/// reveals a single/double/triple selector; simple scoring records a single hit
/// directly. Includes a miss button.
class _CricketInput extends StatefulWidget {
  final CricketProvider provider;
  final CricketScoringMode scoringMode;

  const _CricketInput({required this.provider, required this.scoringMode});

  @override
  State<_CricketInput> createState() => _CricketInputState();
}

class _CricketInputState extends State<_CricketInput> {
  int? _selectedField;

  bool get _isStandard => widget.scoringMode == CricketScoringMode.standard;

  /// Handles a field tap: records a single in simple mode, or opens the
  /// multiplier selector in standard mode.
  Future<void> _onFieldTap(int field) async {
    if (!_isStandard) {
      // Simple mode: always single
      await widget.provider.recordDart(field, 1);
      setState(() => _selectedField = null);
    } else {
      setState(() => _selectedField = field);
    }
  }

  /// Records the selected field with the chosen multiplier (standard mode).
  Future<void> _onMultiplierTap(int multiplier) async {
    if (_selectedField == null) return;
    final field = _selectedField!;
    setState(() => _selectedField = null);
    await widget.provider.recordDart(field, multiplier);
  }

  /// Records a missed dart and clears any field selection.
  Future<void> _onMiss() async {
    setState(() => _selectedField = null);
    await widget.provider.recordDart(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    final states = widget.provider.playerStates;
    final l = context.l10n;

    if (_selectedField != null && _isStandard) {
      // Show multiplier selector
      return _MultiplierRow(
        field: _selectedField!,
        onSelected: _onMultiplierTap,
        onCancel: () => setState(() => _selectedField = null),
        l: l,
      );
    }

    // Show field grid
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ...cricketFields.map((field) {
              final allClosed = states.every((s) => s.hasClosedField(field));
              final label = field == 25 ? l.bull : '$field';
              return _FieldButton(
                label: label,
                allClosed: allClosed,
                onTap: allClosed ? null : () => _onFieldTap(field),
              );
            }),
            _MissButton(onTap: _onMiss, l: l),
          ],
        ),
      ],
    );
  }
}

/// A Cricket field button, disabled and dimmed once every player has closed it.
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

/// The miss button that records a non-scoring dart.
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

/// Single/double/triple selector shown after a field is tapped in standard mode.
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
    final cs = theme.colorScheme;
    final label = field == 25 ? l.bull : '$field';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _MultBtn(
              label: l.single,
              sub: '×1',
              multiplier: 1,
              onTap: () => onSelected(1),
            ),
            const SizedBox(width: 10),
            _MultBtn(
              label: l.double_,
              sub: '×2',
              multiplier: 2,
              onTap: () => onSelected(2),
            ),
            const SizedBox(width: 10),
            if (field != 25) // Bull has no triple
              _MultBtn(
                label: l.triple,
                sub: '×3',
                multiplier: 3,
                onTap: () => onSelected(3),
              ),
          ],
        ),
        const SizedBox(height: 6),
        TextButton(onPressed: onCancel, child: Text(l.cancel)),
      ],
    );
  }
}

/// A single/double/triple input button, colored to match its multiplier.
class _MultBtn extends StatelessWidget {
  final String label;
  final String sub;
  final int multiplier;
  final VoidCallback onTap;
  const _MultBtn({
    required this.label,
    required this.sub,
    required this.multiplier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;
    switch (multiplier) {
      case 2:
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        break;
      case 3:
        bg = tripleContainerColor(context);
        fg = onTripleContainerColor(context);
        break;
      default:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurface;
    }
    return SizedBox(
      width: 80,
      height: 64,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
              Text(
                sub,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
