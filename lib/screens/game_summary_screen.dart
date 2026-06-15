import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/game_provider.dart';
import '../models/dart_throw.dart';
import '../l10n/app_localizations.dart';
import '../utils/layout.dart';
import '../utils/placement.dart';

/// Post-game summary for X01: winner, per-player/team stats and throw history,
/// with options to save or share the result card as an image.
class GameSummaryScreen extends StatefulWidget {
  const GameSummaryScreen({super.key});

  @override
  State<GameSummaryScreen> createState() => _GameSummaryScreenState();
}

class _GameSummaryScreenState extends State<GameSummaryScreen> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  /// Rasterizes the result card widget to a high-resolution image.
  Future<ui.Image> _renderCard() async {
    final ctx = _cardKey.currentContext;
    if (ctx == null) throw StateError('Card widget is not mounted');
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    return boundary.toImage(pixelRatio: 3.0);
  }

  /// Renders the result card and saves it to the device photo gallery.
  Future<void> _saveToPhotos() async {
    setState(() => _saving = true);
    try {
      final img = await _renderCard();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await Gal.putImageBytes(bytes!.buffer.asUint8List());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.savedToPhotos)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${context.l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Renders the result card to a temporary PNG and opens the share sheet.
  Future<void> _shareCard() async {
    setState(() => _saving = true);
    final shareSubject = context.l10n.shareSubject;
    try {
      final img = await _renderCard();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/dartscore_ergebnis.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: shareSubject),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${context.l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    final states = provider.playerStates;
    final winner = states.firstWhere(
      (s) => s.players.any((p) => p.id == provider.winnerId),
      orElse: () => states.first,
    );
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.gameOverview),
        automaticallyImplyLeading: false,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: l.saveToPhotos,
              onPressed: _saveToPhotos,
            ),
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: l.share,
              onPressed: _shareCard,
            ),
          ],
        ],
      ),
      body: ListView(
        padding: contentPadding(context, top: 16, bottom: 16, innerH: 16),
        children: [
          // The card that gets captured as image
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              color: cs.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  // Winner banner
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.emoji_events_rounded,
                              size: 52, color: cs.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.wins(winner.displayName),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // Perfect game badges
                  ...states.where((s) => s.perfectLegs > 0).map((s) {
                    final minDarts =
                        minimumDartsForScore[provider.game!.startScore];
                    final label = minDarts == 9
                        ? l.nineDarter
                        : l.perfectGameLabel(minDarts ?? 0);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            cs.tertiary,
                            cs.tertiary.withValues(alpha: 0.7),
                          ]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${s.player.name} – $label! 🏆',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  // Final ranking (placement mode only)
                  if (provider.game!.placementMode) ...[
                    _FinalRankingCard(states: states),
                    const SizedBox(height: 16),
                  ],
                  // Per-team or per-player stats
                  ...states.map((s) => s.isTeam
                      ? _TeamSummaryCard(
                          state: s, placementMode: provider.game!.placementMode)
                      : _PlayerSummaryCard(
                          state: s, placementMode: provider.game!.placementMode)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Throw history (outside captured area — too long for image)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.allThrows,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...provider.allThrows().map((t) {
                    final player = states
                        .firstWhere((s) => s.player.id == t.playerId)
                        .player;
                    return _ThrowRow(t: t, playerName: player.name);
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(l.backToHome),
          ),
        ],
      ),
    );
  }
}

// ── Final ranking (placement mode) ──────────────────────────────────────────

/// Final ranking card for placement-mode games: every slot sorted by legs
/// won (desc), tie-broken by the cumulative sum of per-leg finishing
/// positions (asc, lower is better).
class _FinalRankingCard extends StatelessWidget {
  final List<PlayerState> states;

  const _FinalRankingCard({required this.states});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;

    final throwsById = {
      for (var i = 0; i < states.length; i++) i: states[i].throws,
    };
    final maxLeg = throwsById.values
        .expand((t) => t)
        .map((t) => t.leg)
        .fold(0, (a, b) => b > a ? b : a);
    final legTable = legPlacementsTable(throwsById, maxLeg, 1);
    final points = placementPointsTotal(throwsById, maxLeg, 1);

    final ranked = List<int>.generate(states.length, (i) => i)
      ..sort((a, b) {
        final pa = points[a] ?? 0, pb = points[b] ?? 0;
        if (pa != pb) return pb.compareTo(pa);
        if (states[a].legsWon != states[b].legsWon) {
          return states[b].legsWon.compareTo(states[a].legsWon);
        }
        return states[a].placementSum.compareTo(states[b].placementSum);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.finalRanking,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...ranked.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final i = entry.value;
              final s = states[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '$rank.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(s.displayName,
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      '${l.legs}: ${s.legsWon}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${l.points}: ${points[i] ?? 0}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            if (maxLeg > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                l.legByLegPlacements,
                style: theme.textTheme.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                l.placementPointsHint,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(40),
                  columnWidths: {
                    0: const FixedColumnWidth(100),
                    maxLeg + 1: const FixedColumnWidth(56),
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(color: cs.outlineVariant, width: 0.5),
                  ),
                  children: [
                    TableRow(children: [
                      const SizedBox.shrink(),
                      for (var leg = 1; leg <= maxLeg; leg++)
                        _RankCell(l.legAbbr(leg), bold: true, alignment: Alignment.center),
                      _RankCell(l.points, bold: true, alignment: Alignment.center),
                    ]),
                    ...ranked.map((i) {
                      final s = states[i];
                      return TableRow(children: [
                        _RankCell(s.displayName, alignment: Alignment.centerLeft),
                        for (var leg = 1; leg <= maxLeg; leg++)
                          _RankCell(
                            legTable[leg]?[i] != null ? '${legTable[leg]![i]}.' : '-',
                            alignment: Alignment.center,
                          ),
                        _RankCell('${points[i] ?? 0}', bold: true, alignment: Alignment.center),
                      ]);
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single padded, optionally bold cell used in the per-leg placement table.
class _RankCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Alignment alignment;

  const _RankCell(this.text, {this.bold = false, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: bold ? FontWeight.bold : null,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Team summary card ─────────────────────────────────────────────────────────

/// Summary card for one team: members, legs/sets won, and combined stats.
class _TeamSummaryCard extends StatelessWidget {
  final PlayerState state;
  final bool placementMode;
  const _TeamSummaryCard({required this.state, required this.placementMode});

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final cs      = theme.colorScheme;
    final l       = context.l10n;
    final throws  = state.throws;
    final busts   = throws.where((t) => t.bust).length;
    final highScore = throws.isEmpty ? 0 : throws.map((t) => t.score).reduce((a, b) => a > b ? a : b);
    // Total legs won across the whole match (every checkout), not just the
    // current set; sets are already a running total in state.setsWon. In
    // placement mode every slot checks out every leg, so legs won must come
    // from the provider's tally instead of counting checkout throws.
    final legsWon = placementMode
        ? state.legsWon
        : throws.where((t) => !t.bust && t.remainingBefore - t.score == 0).length;

    // Per-player breakdown
    final byPlayer = <int, List<DartThrow>>{};
    for (final t in throws) {
      byPlayer.putIfAbsent(t.playerId, () => []).add(t);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.groups_rounded,
                      color: cs.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.displayName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(l.setsLegsWon(state.setsWon, legsWon),
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Team combined stats
            _StatRow(l.totalDarts,   '${state.totalDarts}'),
            _StatRow(l.visits,       '${state.totalVisits}'),
            _StatRow(l.threeDartAvg, state.average.toStringAsFixed(2)),
            _StatRow(l.highestVisit, '$highScore'),
            _StatRow(l.busts,        '$busts'),
            // Per-player breakdown
            if (byPlayer.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(context.l10n.teamPlayers, style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold,
                             color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              ...state.players.map((p) {
                final pt = byPlayer[p.id!] ?? [];
                if (pt.isEmpty) return const SizedBox.shrink();
                final pd     = pt.fold(0, (s, t) => s + t.dartsUsed);
                final ps     = pt.fold(0, (s, t) => t.bust ? s : s + t.score);
                final pavg   = pd == 0 ? 0.0 : (ps / pd) * 3;
                final phigh  = pt.isEmpty ? 0 : pt.map((t) => t.score).reduce((a, b) => a > b ? a : b);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: cs.surfaceContainerHighest,
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.name,
                          style: theme.textTheme.bodySmall)),
                      Text('Ø ${pavg.toStringAsFixed(1)}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Text('${context.l10n.highAbbr} $phigh',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      Text(context.l10n.dartsShort(pd),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Individual summary card ───────────────────────────────────────────────────

/// Summary card for one player: legs/sets won and key stats (darts, visits,
/// average, highest visit, busts).
class _PlayerSummaryCard extends StatelessWidget {
  final PlayerState state;
  final bool placementMode;

  const _PlayerSummaryCard({required this.state, required this.placementMode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final throws = state.throws;
    final busts = throws.where((t) => t.bust).length;
    final highScore =
        throws.isEmpty ? 0 : throws.map((t) => t.score).reduce((a, b) => a > b ? a : b);
    // Total legs won across the whole match (every checkout); sets are already
    // a running total in state.setsWon. In placement mode every slot checks
    // out every leg, so legs won must come from the provider's tally instead
    // of counting checkout throws.
    final legsWon = placementMode
        ? state.legsWon
        : throws.where((t) => !t.bust && t.remainingBefore - t.score == 0).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(state.player.name.isNotEmpty ? state.player.name[0].toUpperCase() : '?')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.player.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        context.l10n.setsLegsWon(state.setsWon, legsWon),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _StatRow(context.l10n.totalDarts, '${state.totalDarts}'),
            _StatRow(context.l10n.visits, '${state.totalVisits}'),
            _StatRow(context.l10n.threeDartAvg, state.average.toStringAsFixed(2)),
            _StatRow(context.l10n.highestVisit, '$highScore'),
            _StatRow(context.l10n.busts, '$busts'),
          ],
        ),
      ),
    );
  }
}

/// A label/value row in a summary card's stats list.
class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// A single row in the throw history: the visit's score and resulting remaining.
class _ThrowRow extends StatelessWidget {
  final DartThrow t;
  final String playerName;

  const _ThrowRow({required this.t, required this.playerName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              playerName,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              t.bust ? context.l10n.bust.toUpperCase() : '${t.score}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: t.bust ? theme.colorScheme.error : null,
              ),
            ),
          ),
          Text(
            '→ ${t.remainingBefore - (t.bust ? 0 : t.score)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            '${context.l10n.setLabel(t.set)} · ${context.l10n.legLabel(t.leg)} · ${context.l10n.dartsN(t.dartsUsed)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
