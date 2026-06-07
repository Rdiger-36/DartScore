import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/shanghai_game.dart';
import '../providers/shanghai_provider.dart';
import '../utils/layout.dart';
import '../utils/triple_color.dart';
import 'shanghai_summary_screen.dart';

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
          // ── Fixed target card ─────────────────────────────────────────────
          Padding(
            padding: contentPadding(
              context,
              fraction: kGameWidthFraction,
              maxWidth: kMaxGameWidth,
              top: 8,
              innerH: 12,
            ),
            child: SizedBox(width: double.infinity, child: _TargetCard(provider: provider)),
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
              child: _ShanghaiBoard(provider: provider, states: states),
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
                      children: [
                        Text(
                          current.displayName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                        ),
                        const Spacer(),
                        _DartDots(count: provider.dartsInVisit, total: provider.visitDartLimit),
                      ],
                    ),
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

// ── Active target display ─────────────────────────────────────────────────────

class _TargetCard extends StatelessWidget {
  final ShanghaiProvider provider;
  const _TargetCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l     = context.l10n;
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final target = provider.activeTarget;
    final label = target == 25 ? l.bull : '$target';

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Text(
              l.shanghaiTarget,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Scoreboard ────────────────────────────────────────────────────────────────

class _ShanghaiBoard extends StatelessWidget {
  final ShanghaiProvider provider;
  final List<ShanghaiPlayerState> states;

  const _ShanghaiBoard({required this.provider, required this.states});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;
    final isSequential = provider.game!.variant == ShanghaiVariant.sequential;
    final currentIdx   = provider.currentPlayerIndex;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: states.indexed.map((e) {
            final i = e.$1;
            final s = e.$2;
            final isActive = i == currentIdx;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? cs.primary : cs.onSurface,
                      ),
                    ),
                  ),
                  if (isSequential)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Text(
                        '${l.shanghaiTarget}: ${s.progress > 20 ? '✓' : s.progress}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Text(
                    '${s.score}',
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
      ),
    );
  }
}

// ── Dart dot indicator ────────────────────────────────────────────────────────

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

// ── Input ─────────────────────────────────────────────────────────────────────

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
