import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/player.dart';
import '../models/dart_throw.dart';
import '../models/game.dart';
import '../providers/game_provider.dart' show minimumDartsForScore;
import '../services/sync_service.dart';
import '../l10n/app_localizations.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class _PlayerStats {
  final int gamesPlayed;
  final int gamesFinished;
  final int totalVisits;
  final int totalDarts;
  final int totalScored;          // excludes busts
  final int busts;
  final int legsWon;
  final int highestVisit;
  final int highestCheckout;      // highest score that reached 0
  final int count180;
  final int count140plus;
  final int count100plus;
  final double checkoutPercent;   // successful checkouts / attempts
  final List<DartThrow> recentThrows;
  final Map<int, int> scoreDistribution;
  final int perfectLegs;

  // ── Extended stats ───────────────────────────────────────────────────────
  /// field (1-20, 25=bull) → multiplier (1/2/3) → hit count
  final Map<int, Map<int, int>> segmentHits;
  final double scoreStdDev;
  /// throws per UTC-day key "yyyy-MM-dd" → count (live throws only)
  final Map<String, int> throwsPerDay;
  // Week comparison (Mon–today vs previous Mon–Sun)
  final double thisWeekAvg;
  final double lastWeekAvg;
  final int thisWeekVisits;
  final int lastWeekVisits;
  final int thisWeek180s;
  final int lastWeek180s;
  // Checkout breakdown by remaining-before bracket
  final int coAttemptSub40;   final int coSuccessSub40;
  final int coAttemptSub60;   final int coSuccessSub60;
  final int coAttemptSub100;  final int coSuccessSub100;
  final int coAttemptSub170;  final int coSuccessSub170;

  const _PlayerStats({
    required this.gamesPlayed,
    required this.gamesFinished,
    required this.totalVisits,
    required this.totalDarts,
    required this.totalScored,
    required this.busts,
    required this.legsWon,
    required this.highestVisit,
    required this.highestCheckout,
    required this.count180,
    required this.count140plus,
    required this.count100plus,
    required this.checkoutPercent,
    required this.recentThrows,
    required this.scoreDistribution,
    this.perfectLegs = 0,
    this.segmentHits = const {},
    this.scoreStdDev = 0,
    this.throwsPerDay = const {},
    this.thisWeekAvg = 0,
    this.lastWeekAvg = 0,
    this.thisWeekVisits = 0,
    this.lastWeekVisits = 0,
    this.thisWeek180s = 0,
    this.lastWeek180s = 0,
    this.coAttemptSub40 = 0,  this.coSuccessSub40 = 0,
    this.coAttemptSub60 = 0,  this.coSuccessSub60 = 0,
    this.coAttemptSub100 = 0, this.coSuccessSub100 = 0,
    this.coAttemptSub170 = 0, this.coSuccessSub170 = 0,
  });

  double get average3Dart =>
      totalDarts == 0 ? 0 : (totalScored / totalDarts) * 3;

  double get bustRate =>
      totalVisits == 0 ? 0 : (busts / totalVisits) * 100;
}

Future<_PlayerStats> _loadStats(Player player) async {
  final playerId = player.id!;
  final db = DbHelper.instance;

  final throws = await db.getThrowsForPlayer(playerId);
  final gameIds = await db.getGameIdsForPlayer(playerId);
  final games = <int, Game>{};
  for (final id in gameIds) {
    final rows = await db.getGames();
    for (final g in rows) {
      if (g.id == id) games[id] = g;
    }
  }

  int totalScored = 0, busts = 0, legsWon = 0;
  int highestVisit = 0, highestCheckout = 0;
  int count180 = 0, count140plus = 0, count100plus = 0;
  int checkoutAttempts = 0, checkoutSuccess = 0, perfectLegs = 0;
  final scoreDistribution = <int, int>{};

  // Extended stats accumulators
  final segmentHits = <int, Map<int, int>>{}; // field → multiplier → count
  final throwsPerDay = <String, int>{};
  final scoreValues = <int>[]; // non-bust scores for std-dev
  // Week windows (local time)
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final thisWeekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  final lastWeekEnd   = thisWeekStart;
  double thisWeekScored = 0; int thisWeekDarts = 0;
  double lastWeekScored = 0; int lastWeekDarts = 0;
  int thisWeekVisits = 0, lastWeekVisits = 0;
  int thisWeek180s = 0, lastWeek180s = 0;
  // Checkout bracket counters
  int coAtSub40 = 0, coOkSub40 = 0;
  int coAtSub60 = 0, coOkSub60 = 0;
  int coAtSub100 = 0, coOkSub100 = 0;
  int coAtSub170 = 0, coOkSub170 = 0;

  for (final t in throws) {
    // Parse individual dart hits for dartboard heatmap
    if (t.hitsJson != null) {
      try {
        final hits = jsonDecode(t.hitsJson!) as List<dynamic>;
        for (final h in hits) {
          final field = h['f'] as int;
          final mul   = h['m'] as int;
          segmentHits.putIfAbsent(field, () => {});
          segmentHits[field]![mul] = (segmentHits[field]![mul] ?? 0) + 1;
        }
      } catch (_) {}
    }

    // Activity heatmap — count every throw (bust or not) per local day
    final dayKey = '${t.thrownAt.year}-'
        '${t.thrownAt.month.toString().padLeft(2, '0')}-'
        '${t.thrownAt.day.toString().padLeft(2, '0')}';
    throwsPerDay[dayKey] = (throwsPerDay[dayKey] ?? 0) + 1;

    // Week comparison windows
    final inThisWeek = !t.thrownAt.isBefore(thisWeekStart);
    final inLastWeek = !t.thrownAt.isBefore(lastWeekStart) && t.thrownAt.isBefore(lastWeekEnd);

    if (t.bust) {
      busts++;
    } else {
      totalScored += t.score;
      scoreValues.add(t.score);
      if (t.score > highestVisit) highestVisit = t.score;
      if (t.score == 180) count180++;
      if (t.score >= 140) count140plus++;
      if (t.score >= 100) count100plus++;

      // Week comparison accumulation
      if (inThisWeek) {
        thisWeekScored += t.score;
        thisWeekDarts  += t.dartsUsed;
        thisWeekVisits++;
        if (t.score == 180) thisWeek180s++;
      } else if (inLastWeek) {
        lastWeekScored += t.score;
        lastWeekDarts  += t.dartsUsed;
        lastWeekVisits++;
        if (t.score == 180) lastWeek180s++;
      }

      // Any visit where remaining ≤ 170 is a checkout attempt
      if (t.remainingBefore <= 170) {
        checkoutAttempts++;
        final success = t.remainingBefore - t.score == 0;

        // Bracket counters
        if (t.remainingBefore <= 40)       { coAtSub40++;  if (success) coOkSub40++;  }
        else if (t.remainingBefore <= 60)  { coAtSub60++;  if (success) coOkSub60++;  }
        else if (t.remainingBefore <= 100) { coAtSub100++; if (success) coOkSub100++; }
        else                               { coAtSub170++; if (success) coOkSub170++; }

        if (success) {
          legsWon++;
          checkoutSuccess++;
          if (t.score > highestCheckout) highestCheckout = t.score;

          final legDarts = throws
              .where((x) => x.leg == t.leg && x.set == t.set && x.gameId == t.gameId)
              .fold(0, (s, x) => s + x.dartsUsed);
          final startForGame = games[t.gameId]?.startScore;
          final minD = startForGame != null
              ? minimumDartsForScore[startForGame]
              : null;
          if (minD != null && legDarts <= minD) perfectLegs++;
        }
      }
    }

    // Score distribution — bucket by 20
    if (!t.bust) {
      final bucket = (t.score ~/ 20) * 20;
      scoreDistribution[bucket] = (scoreDistribution[bucket] ?? 0) + 1;
    }
  }

  final gamesFinished = games.values.where((g) => g.finishedAt != null).length;

  // ── Merge in persistent stats from cleared games ──────────────────────────
  int persistentTotalDarts = 0;
  int persistentTotalVisits = 0;
  int persistentGamesPlayed = 0;
  if (player.localStatsJson != null && player.localStatsJson!.isNotEmpty) {
    try {
      final p = jsonDecode(player.localStatsJson!) as Map<String, dynamic>;
      int pi(String k) => p[k] as int? ?? 0;
      persistentTotalDarts  = pi('total_darts');
      persistentTotalVisits = pi('total_visits');
      persistentGamesPlayed = pi('games_played');
      totalScored      += pi('total_scored');
      busts            += pi('busts');
      legsWon          += pi('legs_won');
      highestVisit      = max(highestVisit, pi('highest_visit'));
      highestCheckout   = max(highestCheckout, pi('highest_checkout'));
      count180         += pi('count_180');
      count140plus     += pi('count_140_plus');
      count100plus     += pi('count_100_plus');
      checkoutAttempts += pi('checkout_attempts');
      checkoutSuccess  += pi('checkout_successes');
    } catch (_) {}
  }

  // recent visits, newest first (live throws only — for the recent-throws panel)
  final recentThrows = throws.reversed.take(20).toList();

  final checkoutPercent =
      checkoutAttempts == 0 ? 0.0 : (checkoutSuccess / checkoutAttempts) * 100;

  // Standard deviation
  double stdDev = 0;
  if (scoreValues.length > 1) {
    final mean = scoreValues.reduce((a, b) => a + b) / scoreValues.length;
    final variance = scoreValues
        .map((s) => (s - mean) * (s - mean))
        .reduce((a, b) => a + b) / scoreValues.length;
    stdDev = sqrt(variance);
  }

  final thisWeekAvg3 = thisWeekDarts == 0 ? 0.0 : (thisWeekScored / thisWeekDarts) * 3;
  final lastWeekAvg3 = lastWeekDarts == 0 ? 0.0 : (lastWeekScored / lastWeekDarts) * 3;

  return _PlayerStats(
    gamesPlayed: gameIds.length + persistentGamesPlayed,
    gamesFinished: gamesFinished,
    totalVisits: throws.length + persistentTotalVisits,
    totalDarts: throws.fold(0, (s, t) => s + t.dartsUsed) + persistentTotalDarts,
    totalScored: totalScored,
    busts: busts,
    legsWon: legsWon,
    highestVisit: highestVisit,
    highestCheckout: highestCheckout,
    count180: count180,
    count140plus: count140plus,
    count100plus: count100plus,
    checkoutPercent: checkoutPercent,
    recentThrows: recentThrows,
    scoreDistribution: scoreDistribution,
    perfectLegs: perfectLegs,
    segmentHits: segmentHits,
    scoreStdDev: stdDev,
    throwsPerDay: throwsPerDay,
    thisWeekAvg: thisWeekAvg3,
    lastWeekAvg: lastWeekAvg3,
    thisWeekVisits: thisWeekVisits,
    lastWeekVisits: lastWeekVisits,
    thisWeek180s: thisWeek180s,
    lastWeek180s: lastWeek180s,
    coAttemptSub40:  coAtSub40,  coSuccessSub40:  coOkSub40,
    coAttemptSub60:  coAtSub60,  coSuccessSub60:  coOkSub60,
    coAttemptSub100: coAtSub100, coSuccessSub100: coOkSub100,
    coAttemptSub170: coAtSub170, coSuccessSub170: coOkSub170,
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PlayerStatsScreen extends StatelessWidget {
  final Player player;

  const PlayerStatsScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${player.name} · ${context.l10n.statistics}'),
      ),
      body: FutureBuilder<_PlayerStats>(
        future: _loadStats(player),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          final stats = snap.data!;
          // No throws at all — show synced snapshot or empty state
          if (stats.totalVisits == 0 && player.syncedStats != null) {
            return _SyncedStatsView(player: player);
          }
          if (stats.totalVisits == 0) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart,
                      size: 56,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.noGamesFor(player.name),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }
          return _StatsBody(player: player, stats: stats);
        },
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  final Player player;
  final _PlayerStats stats;

  const _StatsBody({required this.player, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        // ── Hero average ────────────────────────────────────────────────
        _HeroCard(stats: stats),
        const SizedBox(height: 12),
        // ── Highlights row ──────────────────────────────────────────────
        _SectionTitle(context.l10n.highlights),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _HighlightTile(
                label: context.l10n.count180,
                value: '${stats.count180}',
                icon: Icons.star_rounded,
                highlight: stats.count180 > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HighlightTile(
                label: context.l10n.count140plus,
                value: '${stats.count140plus}',
                icon: Icons.trending_up,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HighlightTile(
                label: context.l10n.count100plus,
                value: '${stats.count100plus}',
                icon: Icons.bar_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Perfect games row
        if (stats.perfectLegs > 0) ...[
          Row(
            children: [
              Expanded(
                child: _HighlightTile(
                  label: context.l10n.perfectGames,
                  value: '${stats.perfectLegs}',
                  icon: Icons.emoji_events_rounded,
                  highlight: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Expanded(
              child: _HighlightTile(
                label: context.l10n.highestVisit,
                value: '${stats.highestVisit}',
                icon: Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HighlightTile(
                label: context.l10n.highestCheckout,
                value: stats.highestCheckout == 0
                    ? '—'
                    : '${stats.highestCheckout}',
                icon: Icons.flag_rounded,
                highlight: stats.highestCheckout >= 100,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // ── Overview ────────────────────────────────────────────────────
        _SectionTitle(context.l10n.overview),
        const SizedBox(height: 6),
        _StatCard(
          children: [
            _StatRow(context.l10n.gamesPlayed, '${stats.gamesPlayed}'),
            _StatRow(context.l10n.gamesWon, '${stats.gamesFinished}'),
            _StatRow(context.l10n.legsWon, '${stats.legsWon}'),
            _StatRow(context.l10n.totalVisits, '${stats.totalVisits}'),
            _StatRow(context.l10n.totalDarts, '${stats.totalDarts}'),
          ],
        ),
        const SizedBox(height: 14),
        // ── Accuracy ────────────────────────────────────────────────────
        _SectionTitle(context.l10n.accuracy),
        const SizedBox(height: 6),
        _StatCard(
          children: [
            _StatRow(context.l10n.threeDartAvg,
                stats.average3Dart.toStringAsFixed(2)),
            _StatRow(context.l10n.busts, '${stats.busts}'),
            _StatRow(context.l10n.bustRate,
                '${stats.bustRate.toStringAsFixed(1)} %'),
            _StatRow(context.l10n.checkoutRate,
                '${stats.checkoutPercent.toStringAsFixed(1)} %'),
          ],
        ),
        const SizedBox(height: 14),
        // ── Score Distribution ───────────────────────────────────────────
        if (stats.scoreDistribution.isNotEmpty) ...[
          _SectionTitle(context.l10n.scoreDistribution),
          const SizedBox(height: 6),
          _ScoreChart(distribution: stats.scoreDistribution),
          const SizedBox(height: 14),
        ],
        // ── Dartboard Heatmap ─────────────────────────────────────────────
        if (stats.segmentHits.isNotEmpty) ...[
          _SectionTitle(context.l10n.dartboardHeatmap),
          const SizedBox(height: 6),
          _DartboardHeatmap(segmentHits: stats.segmentHits),
          const SizedBox(height: 14),
        ],
        // ── Stabilität ───────────────────────────────────────────────────
        if (stats.scoreStdDev > 0) ...[
          _SectionTitle(context.l10n.stability),
          const SizedBox(height: 6),
          _StabilityCard(stats: stats),
          const SizedBox(height: 14),
        ],
        // ── Checkout Breakdown ───────────────────────────────────────────
        if (stats.coAttemptSub40 + stats.coAttemptSub60 +
            stats.coAttemptSub100 + stats.coAttemptSub170 > 0) ...[
          _SectionTitle(context.l10n.checkoutBreakdown),
          const SizedBox(height: 6),
          _CheckoutBreakdownCard(stats: stats),
          const SizedBox(height: 14),
        ],
        // ── Wochenvergleich ──────────────────────────────────────────────
        if (stats.thisWeekVisits > 0 || stats.lastWeekVisits > 0) ...[
          _SectionTitle(context.l10n.weekComparison),
          const SizedBox(height: 6),
          _WeekComparisonCard(stats: stats),
          const SizedBox(height: 14),
        ],
        // ── Recent Throws ────────────────────────────────────────────────
        if (stats.recentThrows.isNotEmpty) ...[
          _SectionTitle(context.l10n.recentThrows),
          const SizedBox(height: 6),
          _StatCard(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
            children: stats.recentThrows.map((t) => _ThrowRow(t: t)).toList(),
          ),
        ],
      ],
    );
  }
}

// ── Hero card (big average) ───────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final _PlayerStats stats;
  const _HeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '3-Dart Average',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  stats.average3Dart.toStringAsFixed(2),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HeroStat(
                  label: context.l10n.darts_, value: '${stats.totalDarts}', cs: cs),
              const SizedBox(height: 6),
              _HeroStat(
                  label: context.l10n.visits, value: '${stats.totalVisits}', cs: cs),
              const SizedBox(height: 6),
              _HeroStat(
                  label: 'Legs', value: '${stats.legsWon}', cs: cs),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  const _HeroStat({required this.label, required this.value, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.onPrimary.withValues(alpha: 0.7),
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

// ── Score distribution bar chart ──────────────────────────────────────────────

class _ScoreChart extends StatelessWidget {
  final Map<int, int> distribution;
  const _ScoreChart({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Build sorted buckets 0,20,40,…,180
    final buckets = List.generate(10, (i) => i * 20);
    final labels = [
      '0–19', '20–39', '40–59', '60–79', '80–99',
      '100–119', '120–139', '140–159', '160–179', '180',
    ];
    final counts = buckets.map((b) => distribution[b] ?? 0).toList();
    final maxCount = counts.reduce((a, b) => a > b ? a : b).clamp(1, 99999);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          children: List.generate(buckets.length, (i) {
            final count = counts[i];
            final frac = count / maxCount;
            final isTop = i >= 7; // 140+
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: Text(
                      labels[i],
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: frac,
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: isTop ? cs.tertiary : cs.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                        color: count > 0 ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Reusable building blocks ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets? padding;
  const _StatCard({required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: children
              .expand((w) => [
                    w,
                    if (w != children.last)
                      Divider(
                        height: 1,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                  ])
              .toList(),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _HighlightTile({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: highlight ? cs.tertiaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight ? cs.onTertiaryContainer : cs.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? cs.onTertiaryContainer : cs.onSurface,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: highlight
                  ? cs.onTertiaryContainer.withValues(alpha: 0.8)
                  : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThrowRow extends StatelessWidget {
  final DartThrow t;
  const _ThrowRow({required this.t});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fmt = DateFormat('dd.MM  HH:mm');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Score pill
          Container(
            width: 48,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: t.bust
                  ? cs.errorContainer
                  : t.score >= 140
                      ? cs.tertiaryContainer
                      : t.score >= 100
                          ? cs.secondaryContainer
                          : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              t.bust ? 'BUST' : '${t.score}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: t.bust
                    ? cs.onErrorContainer
                    : t.score >= 140
                        ? cs.onTertiaryContainer
                        : t.score >= 100
                            ? cs.onSecondaryContainer
                            : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Rest after
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.bust
                      ? context.l10n.restBleibt(t.remainingBefore)
                      : '→ ${t.remainingBefore - t.score} ${context.l10n.remaining}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${context.l10n.legLabel(t.leg)}  ·  ${context.l10n.dartsN(t.dartsUsed)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Date
          Text(
            fmt.format(t.thrownAt),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Dartboard Heatmap ─────────────────────────────────────────────────────────

class _DartboardHeatmap extends StatelessWidget {
  final Map<int, Map<int, int>> segmentHits;
  const _DartboardHeatmap({required this.segmentHits});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Total hits per field (all multipliers combined)
    final perField = <int, int>{};
    for (final entry in segmentHits.entries) {
      perField[entry.key] = entry.value.values.fold(0, (a, b) => a + b);
    }
    final maxHits = perField.values.fold(0, max).clamp(1, 999999);

    // Top hit fields for the legend
    final sorted = perField.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topFields = sorted.take(3).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _DartboardPainter(
                  perField: perField,
                  maxHits: maxHits,
                  primaryColor: cs.primary,
                  surfaceColor: cs.surfaceContainerHighest,
                  outlineColor: cs.outline.withValues(alpha: 0.4),
                  onSurfaceColor: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Legend: top 3 fields
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: topFields.map((e) {
                final fieldName = e.key == 25 ? 'Bull' : '${e.key}';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$fieldName · ${e.value}×',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DartboardPainter extends CustomPainter {
  final Map<int, int> perField;
  final int maxHits;
  final Color primaryColor;
  final Color surfaceColor;
  final Color outlineColor;
  final Color onSurfaceColor;

  // Standard dartboard segment order (clockwise from top)
  static const _order = [
    20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
    3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
  ];

  _DartboardPainter({
    required this.perField,
    required this.maxHits,
    required this.primaryColor,
    required this.surfaceColor,
    required this.outlineColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = min(cx, cy);

    // Radii (as fraction of r)
    final rBullInner  = r * 0.06;
    final rBull       = r * 0.13;
    final rInner      = r * 0.35; // inner single ring starts
    final rTriple1    = r * 0.53;
    final rTriple2    = r * 0.60;
    final rDouble1    = r * 0.84;
    final rDouble2    = r * 0.93;
    final rBoard      = r * 1.0;

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final segCount = _order.length;
    final angleStep = (2 * pi) / segCount;
    final halfStep  = angleStep / 2;
    // Start angle: top = -pi/2, offset by half a segment so segment 20 is centered at top
    final startAngle = -pi / 2 - halfStep;

    void drawArc(Canvas c, Offset center, double r1, double r2,
        double aStart, double aSweep, Color fill) {
      final path = Path();
      path.moveTo(center.dx + r1 * cos(aStart),
                  center.dy + r1 * sin(aStart));
      path.arcTo(
          Rect.fromCircle(center: center, radius: r2), aStart, aSweep, false);
      path.arcTo(
          Rect.fromCircle(center: center, radius: r1),
          aStart + aSweep, -aSweep, false);
      path.close();

      canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
      canvas.drawPath(path, outlinePaint);
    }

    final center = Offset(cx, cy);

    // Draw 20 segments × 3 rings (inner single, triple, outer single, double)
    for (var i = 0; i < segCount; i++) {
      final field = _order[i];
      final hits  = perField[field] ?? 0;
      final intensity = hits == 0 ? 0.0 : (hits / maxHits).clamp(0.08, 1.0);
      final heatColor = Color.lerp(
          primaryColor.withValues(alpha: 0.12), primaryColor, intensity)!;

      final a0 = startAngle + i * angleStep;
      final sweep = angleStep;

      // Outer single (between triple and double rings)
      drawArc(canvas, center, rTriple2, rDouble1, a0, sweep, heatColor);
      // Triple ring
      drawArc(canvas, center, rTriple1, rTriple2, a0, sweep,
          hits > 0 ? heatColor.withValues(alpha: (heatColor.a * 1.4).clamp(0, 1)) : surfaceColor);
      // Inner single
      drawArc(canvas, center, rInner, rTriple1, a0, sweep, heatColor);
      // Double ring
      drawArc(canvas, center, rDouble1, rDouble2, a0, sweep,
          hits > 0 ? heatColor.withValues(alpha: (heatColor.a * 1.4).clamp(0, 1)) : surfaceColor);
    }

    // Bull 25
    final bullHits25 = perField[25] ?? 0;
    final bullInt25  = bullHits25 == 0 ? 0.0 : (bullHits25 / maxHits).clamp(0.08, 1.0);
    canvas.drawCircle(
        center, rBull,
        Paint()..color = Color.lerp(primaryColor.withValues(alpha: 0.12), primaryColor, bullInt25)!);
    canvas.drawCircle(center, rBull, outlinePaint);

    // Bullseye 50
    canvas.drawCircle(
        center, rBullInner,
        Paint()..color = Color.lerp(primaryColor.withValues(alpha: 0.12), primaryColor, bullInt25)!
            .withValues(alpha: (bullInt25 + 0.2).clamp(0, 1)));
    canvas.drawCircle(center, rBullInner, outlinePaint);

    // Wire outer board boundary
    canvas.drawCircle(center, rBoard, outlinePaint);
    canvas.drawCircle(center, rDouble2, outlinePaint);

    // Number labels
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i < segCount; i++) {
      final field  = _order[i];
      final angle  = startAngle + i * angleStep + halfStep;
      final labelR = r * 0.975;
      final lx = cx + labelR * cos(angle);
      final ly = cy + labelR * sin(angle);

      tp.text = TextSpan(
        text: '$field',
        style: TextStyle(
          fontSize: r * 0.09,
          fontWeight: FontWeight.bold,
          color: onSurfaceColor.withValues(alpha: 0.85),
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DartboardPainter old) =>
      old.perField != perField || old.maxHits != maxHits;
}

// ── Stability Card ────────────────────────────────────────────────────────────

class _StabilityCard extends StatelessWidget {
  final _PlayerStats stats;
  const _StabilityCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final std = stats.scoreStdDev;

    final (label, color) = switch (std) {
      < 20  => (context.l10n.stabilityVeryHigh, cs.tertiary),
      < 35  => (context.l10n.stabilityHigh,     cs.primary),
      < 50  => (context.l10n.stabilityMedium,   cs.secondary),
      _     => (context.l10n.stabilityLow,      cs.error),
    };

    // Normalize: stdDev 0 → max consistency, 70 → minimum display
    final frac = (1 - (std / 70)).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: color)),
                Text(
                  'σ ${std.toStringAsFixed(1)}',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.stabilityHint(std.toStringAsFixed(1)),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Checkout Breakdown Card ───────────────────────────────────────────────────

class _CheckoutBreakdownCard extends StatelessWidget {
  final _PlayerStats stats;
  const _CheckoutBreakdownCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('≤ 40', stats.coAttemptSub40, stats.coSuccessSub40),
      ('41–60', stats.coAttemptSub60, stats.coSuccessSub60),
      ('61–100', stats.coAttemptSub100, stats.coSuccessSub100),
      ('101–170', stats.coAttemptSub170, stats.coSuccessSub170),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: rows
              .where((r) => r.$2 > 0)
              .expand((r) => [
                    _CheckoutBracketRow(
                        label: r.$1, attempts: r.$2, successes: r.$3),
                    if (r != rows.where((x) => x.$2 > 0).last)
                      Divider(
                          height: 1,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.5)),
                  ])
              .toList(),
        ),
      ),
    );
  }
}

class _CheckoutBracketRow extends StatelessWidget {
  final String label;
  final int attempts;
  final int successes;
  const _CheckoutBracketRow(
      {required this.label, required this.attempts, required this.successes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = attempts == 0 ? 0.0 : (successes / attempts) * 100;
    final frac = pct / 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: frac,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: pct >= 50 ? cs.tertiary : cs.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              '$successes/$attempts  ${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Week Comparison Card ──────────────────────────────────────────────────────

class _WeekComparisonCard extends StatelessWidget {
  final _PlayerStats stats;
  const _WeekComparisonCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;

    double delta(double current, double previous) => current - previous;

    Widget col(String title, String thisVal, String lastVal,
        {double? diff}) {
      final up = diff != null && diff > 0;
      final down = diff != null && diff < 0;
      return Expanded(
        child: Column(
          children: [
            Text(title,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            // This week
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(thisVal,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            // Last week
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(lastVal,
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ),
            if (diff != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    up
                        ? Icons.arrow_upward
                        : down
                            ? Icons.arrow_downward
                            : Icons.remove,
                    size: 12,
                    color: up
                        ? cs.tertiary
                        : down
                            ? cs.error
                            : cs.onSurfaceVariant,
                  ),
                  Text(
                    diff == 0
                        ? '—'
                        : '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: up
                          ? cs.tertiary
                          : down
                              ? cs.error
                              : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SizedBox()),
                SizedBox(
                  width: 90,
                  child: Text(l10n.thisWeek,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer)),
                ),
                SizedBox(
                  width: 90,
                  child: Text(l10n.lastWeek,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                col(
                  l10n.threeDartAvg,
                  stats.thisWeekAvg.toStringAsFixed(2),
                  stats.lastWeekAvg.toStringAsFixed(2),
                  diff: delta(stats.thisWeekAvg, stats.lastWeekAvg),
                ),
                const SizedBox(width: 8),
                col(
                  l10n.totalVisits,
                  '${stats.thisWeekVisits}',
                  '${stats.lastWeekVisits}',
                  diff: (stats.thisWeekVisits - stats.lastWeekVisits).toDouble(),
                ),
                const SizedBox(width: 8),
                col(
                  l10n.count180,
                  '${stats.thisWeek180s}',
                  '${stats.lastWeek180s}',
                  diff: (stats.thisWeek180s - stats.lastWeek180s).toDouble(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Synced stats view (no local data, shows snapshot from sender) ─────────────

class _SyncedStatsView extends StatelessWidget {
  final Player player;
  const _SyncedStatsView({required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final SyncStats s;
    try {
      s = SyncStats.fromJson(
          jsonDecode(player.syncedStats!) as Map<String, dynamic>);
    } catch (_) {
      return Center(child: Text(context.l10n.statsLoadError));
    }

    final fmt = player.lastSyncedAt != null
        ? DateFormat('dd.MM.yy HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(player.lastSyncedAt!))
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      children: [
        // Sync banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.sync, size: 16, color: cs.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fmt != null
                      ? '${context.l10n.syncedStatsFrom} $fmt'
                      : context.l10n.syncedStats,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Hero average
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('3-Dart Average',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onPrimary.withValues(alpha: 0.8))),
                    Text(
                      s.average.toStringAsFixed(2),
                      style: theme.textTheme.displaySmall?.copyWith(
                          color: cs.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SyncHeroStat(context.l10n.darts_, '${s.totalDarts}', cs),
                  const SizedBox(height: 4),
                  _SyncHeroStat(context.l10n.visits, '${s.totalVisits}', cs),
                  const SizedBox(height: 4),
                  _SyncHeroStat('Legs', '${s.legsWon}', cs),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Highlights
        _SyncHighlights(s: s),
        const SizedBox(height: 14),
        // Details
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                _SRow(context.l10n.highestVisit, '${s.highestVisit}'),
                const Divider(height: 1),
                _SRow(context.l10n.count180, '${s.count180}'),
                const Divider(height: 1),
                _SRow(context.l10n.busts, '${s.busts}'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncHeroStat extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  const _SyncHeroStat(this.label, this.value, this.cs);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: cs.onPrimary.withValues(alpha: 0.7))),
        Text(value, style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _SyncHighlights extends StatelessWidget {
  final SyncStats s;
  const _SyncHighlights({required this.s});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: _SyncTile(context.l10n.count180, '${s.count180}',
            Icons.star_rounded, s.count180 > 0, cs)),
        const SizedBox(width: 8),
        Expanded(child: _SyncTile(context.l10n.highestVisit, '${s.highestVisit}',
            Icons.arrow_upward, false, cs)),
        const SizedBox(width: 8),
        Expanded(child: _SyncTile('Legs', '${s.legsWon}',
            Icons.flag_rounded, s.legsWon > 0, cs)),
      ],
    );
  }
}

class _SyncTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool highlight;
  final ColorScheme cs;
  const _SyncTile(this.label, this.value, this.icon, this.highlight, this.cs);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: highlight ? cs.tertiaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16,
              color: highlight ? cs.onTertiaryContainer : cs.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? cs.onTertiaryContainer : cs.onSurface)),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(
              color: highlight
                  ? cs.onTertiaryContainer.withValues(alpha: 0.8)
                  : cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SRow extends StatelessWidget {
  final String l, v;
  const _SRow(this.l, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: Theme.of(context).textTheme.bodyMedium),
          Text(v, style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
