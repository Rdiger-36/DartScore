import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/shanghai_game.dart';
import '../providers/shanghai_provider.dart';
import '../utils/layout.dart';
import '../utils/triple_color.dart';
import '../widgets/dartboard_target_painter.dart';
import 'shanghai_summary_screen.dart';

/// Live Shanghai game screen. Watches the provider and routes to the summary
/// when the game ends, otherwise shows the play view.
class ShanghaiScreen extends StatelessWidget {
  const ShanghaiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ShanghaiProvider>(
      builder: (context, provider, _) {
        if (provider.game == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (provider.gameOver) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ShanghaiSummaryScreen()),
            );
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        return _ShanghaiGameView(provider: provider);
      },
    );
  }
}

// ── Main game view ────────────────────────────────────────────────────────────

/// The in-play layout: target dartboard, scoreboard, Shanghai hint, and input.
class _ShanghaiGameView extends StatelessWidget {
  final ShanghaiProvider provider;
  const _ShanghaiGameView({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l       = context.l10n;
    final theme   = Theme.of(context);
    final cs      = theme.colorScheme;
    final states  = provider.playerStates;
    final current = provider.currentPlayerState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shanghai'),
        actions: [
          if (provider.canUndo)
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              tooltip: l.undo,
              onPressed: () => provider.undoLastDart(),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l.shanghaiQuit,
            onPressed: () => _confirmQuit(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Fixed target dartboard ────────────────────────────────────────
          Padding(
            padding: contentPadding(
              context,
              fraction: kGameWidthFraction,
              maxWidth: kMaxGameWidth,
              top: 8,
              innerH: 12,
            ),
            child: Column(
              children: [
                SizedBox(width: double.infinity, child: _TargetDartboard(provider: provider)),
              ],
            ),
          ),
          // ── Scrollable player list ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: contentPadding(
                context,
                fraction: kGameWidthFraction,
                maxWidth: kMaxGameWidth,
                top: 12,
                bottom: 8,
                innerH: 12,
              ),
              child: _ShanghaiBoard(
                provider:     provider,
                states:       states,
                currentIdx:   provider.currentPlayerIndex,
                dartsInVisit: provider.dartsInVisit,
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
                        _DartDots(count: provider.dartsInVisit, total: provider.visitDartLimit),
                      ],
                    ),
                    _ShanghaiHint(provider: provider),
                    const SizedBox(height: 10),
                    _ShanghaiInput(provider: provider),
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

// ── Active target dartboard ───────────────────────────────────────────────────

/// Dartboard highlighting the current round's target number.
class _TargetDartboard extends StatelessWidget {
  final ShanghaiProvider provider;
  const _TargetDartboard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final target = provider.activeTarget;

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: DartboardTargetPainter(
          target: target,
          highlightColor: cs.primary,
          onSurfaceColor: cs.onSurface,
        ),
      ),
    );
  }
}

// ── Scoreboard ────────────────────────────────────────────────────────────────

/// Scrollable scoreboard listing each player's score and round target,
/// auto-scrolling to keep the active player in view.
class _ShanghaiBoard extends StatefulWidget {
  final ShanghaiProvider provider;
  final List<ShanghaiPlayerState> states;
  final int currentIdx;
  final int dartsInVisit;

  const _ShanghaiBoard({
    required this.provider,
    required this.states,
    required this.currentIdx,
    required this.dartsInVisit,
  });

  @override
  State<_ShanghaiBoard> createState() => _ShanghaiBoardState();
}

class _ShanghaiBoardState extends State<_ShanghaiBoard> {
  late List<GlobalKey> _keys;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.states.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(covariant _ShanghaiBoard old) {
    super.didUpdateWidget(old);
    if (old.states.length != widget.states.length) {
      _keys = List.generate(widget.states.length, (_) => GlobalKey());
    }
    if (old.currentIdx != widget.currentIdx || old.dartsInVisit != widget.dartsInVisit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  /// Smoothly scrolls the active player's row to the center of the viewport.
  void _scrollToCurrent() {
    final key = _keys[widget.currentIdx];
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;
    final isSequential = widget.provider.game!.variant == ShanghaiVariant.sequential;
    final currentIdx   = widget.currentIdx;
    final pendingIdx   = widget.provider.pendingShanghaiIdx;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: widget.states.indexed.map((e) {
            final i = e.$1;
            final s = e.$2;
            final isActive = i == currentIdx;
            return Padding(
              key: _keys[i],
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                  color: isActive ? cs.primary : cs.onSurface,
                                ),
                              ),
                              if (s.isTeamSlot)
                                Text(
                                  s.player.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isActive
                                        ? cs.primary.withValues(alpha: 0.75)
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (i == pendingIdx) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: l.shanghaiPending,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'S',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSequential)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '→ ${s.progress > 20 ? '✓' : s.progress}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    '${s.score}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isActive ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Dart dot indicator ────────────────────────────────────────────────────────

/// Dots showing how many darts of the current visit have been thrown.
class _DartDots extends StatelessWidget {
  final int count;
  final int total;
  const _DartDots({required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
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

// ── Shanghai hint ─────────────────────────────────────────────────────────────

/// Hint showing what is still needed this visit to complete a Shanghai.
class _ShanghaiHint extends StatelessWidget {
  final ShanghaiProvider provider;
  const _ShanghaiHint({required this.provider});

  static const _multiplierLabels = {1: 'S', 2: 'D', 3: 'T'};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final bg = tripleContainerColor(context);
    final fg = onTripleContainerColor(context);

    final needed = provider.shanghaiNeededMultipliers;
    final streakNeeded = provider.shanghaiStreakNeeded;

    Widget? content;
    if (needed != null && needed.isNotEmpty) {
      final target = provider.activeTarget;
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < needed.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward_rounded, size: 13, color: fg.withValues(alpha: 0.7)),
              ),
            Text(
              '${_multiplierLabels[needed[i]]}$target',
              style: theme.textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      );
    } else if (streakNeeded != null && streakNeeded > 0) {
      content = Text(
        l.shanghaiHintStreak(streakNeeded),
        style: theme.textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.bold),
      );
    }

    if (content == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.shanghaiHintTitle,
            style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 4),
          content,
        ],
      ),
    );
  }
}

// ── Input ─────────────────────────────────────────────────────────────────────

/// Input row of single/double/triple and miss buttons that record a dart for
/// the active target.
class _ShanghaiInput extends StatelessWidget {
  final ShanghaiProvider provider;
  const _ShanghaiInput({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final target = provider.activeTarget;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MultBtn(label: l.single, sub: '×1', multiplier: 1, onTap: () => provider.recordDart(1)),
        const SizedBox(width: 10),
        _MultBtn(label: l.double_, sub: '×2', multiplier: 2, onTap: () => provider.recordDart(2)),
        const SizedBox(width: 10),
        if (target != 25)
          _MultBtn(label: l.triple, sub: '×3', multiplier: 3, onTap: () => provider.recordDart(3)),
        const SizedBox(width: 10),
        _MissBtn(label: l.shanghaiMiss, onTap: () => provider.recordDart(0)),
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
      width: 72,
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
              Text(label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: fg,
                      )),
              Text(sub,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.7),
                      )),
            ],
          ),
        ),
      ),
    );
  }
}

/// The miss button that records a non-scoring dart.
class _MissBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MissBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 64,
      child: Material(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Text(
              label,
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
