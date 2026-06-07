import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../models/cricket_game.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/shanghai_game.dart';
import '../providers/cricket_provider.dart';
import '../providers/game_provider.dart';
import '../providers/shanghai_provider.dart';
import 'cricket_history_summary_screen.dart';
import 'cricket_screen.dart';
import 'game_screen.dart';
import 'history_game_summary_screen.dart';
import 'shanghai_history_summary_screen.dart';
import 'shanghai_screen.dart';
import '../utils/layout.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<_HistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_HistoryEntry>> _load() async {
    final db      = DbHelper.instance;
    final entries = <_HistoryEntry>[];

    // X01 games
    for (final g in await db.getGames()) {
      final ids     = await db.getGamePlayerIds(g.id!);
      final players = <Player>[];
      for (final id in ids) {
        final p = await db.getPlayer(id);
        if (p != null) players.add(p);
      }
      entries.add(_HistoryEntry.x01(g, players));
    }

    // Cricket games
    for (final g in await db.getCricketGames()) {
      final players = <Player>[];
      for (final id in g.playerIds) {
        final p = await db.getPlayer(id);
        if (p != null) players.add(p);
      }
      entries.add(_HistoryEntry.cricket(g, players));
    }

    // Shanghai games
    for (final g in await db.getShanghaiGames()) {
      final players = <Player>[];
      for (final id in g.playerIds) {
        final p = await db.getPlayer(id);
        if (p != null) players.add(p);
      }
      entries.add(_HistoryEntry.shanghai(g, players));
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _deleteEntry(_HistoryEntry entry) async {
    final db = DbHelper.instance;
    if (entry.isCricket) {
      await db.deleteCricketGame(entry.cricketGame!.id!);
    } else if (entry.isShanghai) {
      await db.deleteShanghaiGame(entry.shanghaiGame!.id!);
    } else {
      await db.snapshotGameStats(entry.x01Game!.id!);
      await db.deleteGame(entry.x01Game!.id!);
    }
    _reload();
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.clearAllTitle),
        content: Text(l.clearAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.clearAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DbHelper.instance.snapshotPlayerStats();
      await DbHelper.instance.clearAllGames();
      _reload();
    }
  }

  Future<void> _resumeX01(BuildContext context, _HistoryEntry entry) async {
    if (entry.players.isEmpty) return;
    final provider = context.read<GameProvider>();
    await provider.resumeGame(entry.x01Game!, entry.players);
    if (context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const GameScreen()))
        .then((_) => _reload());
    }
  }

  Future<void> _resumeCricket(BuildContext context, _HistoryEntry entry) async {
    if (entry.players.isEmpty) return;
    final provider = context.read<CricketProvider>();
    await provider.resumeGame(entry.cricketGame!, entry.players);
    if (context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CricketScreen()))
        .then((_) => _reload());
    }
  }

  Future<void> _resumeShanghai(BuildContext context, _HistoryEntry entry) async {
    if (entry.players.isEmpty) return;
    final provider = context.read<ShanghaiProvider>();
    await provider.resumeGame(entry.shanghaiGame!, entry.players);
    if (context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ShanghaiScreen()))
        .then((_) => _reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.historyTitle),
        actions: [
          FutureBuilder<List<_HistoryEntry>>(
            future: _future,
            builder: (context, snap) {
              if ((snap.data ?? []).isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: context.l10n.clearAll,
                onPressed: () => _confirmClearAll(context),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: FutureBuilder<List<_HistoryEntry>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snap.data ?? [];
              if (entries.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history,
                          size: 48,
                          color: Theme.of(context).colorScheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text(context.l10n.noHistory),
                    ],
                  ),
                );
              }

              final open     = entries.where((e) => e.finishedAt == null).toList();
              final finished = entries.where((e) => e.finishedAt != null).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  if (open.isNotEmpty) ...[
                    _SectionHeader(
                      label: context.l10n.open,
                      count: open.length,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    ...open.map((e) => _GameTile(
                          entry: e,
                          onDelete: () => _deleteEntry(e),
                          onResume: () => e.isCricket
                              ? _resumeCricket(context, e)
                              : e.isShanghai
                                  ? _resumeShanghai(context, e)
                                  : _resumeX01(context, e),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (finished.isNotEmpty) ...[
                    _SectionHeader(
                        label: context.l10n.finished, count: finished.length),
                    ...finished.map((e) => _GameTile(
                          entry: e,
                          onDelete: () => _deleteEntry(e),
                          onShowSummary: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => e.isCricket
                                  ? CricketHistorySummaryScreen(
                                      game: e.cricketGame!,
                                      players: e.players,
                                    )
                                  : e.isShanghai
                                      ? ShanghaiHistorySummaryScreen(
                                          game: e.shanghaiGame!,
                                          players: e.players,
                                        )
                                      : HistoryGameSummaryScreen(
                                          game: e.x01Game!,
                                          players: e.players,
                                        ),
                            ),
                          ),
                        )),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _shanghaiVariantLabel(AppLocalizations l, ShanghaiVariant variant) {
  switch (variant) {
    case ShanghaiVariant.classic:
      return l.shanghaiClassic;
    case ShanghaiVariant.clockwise:
      return l.shanghaiClockwise;
    case ShanghaiVariant.sequential:
      return l.shanghaiSequential;
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _HistoryEntry {
  final Game?          x01Game;
  final CricketGame?   cricketGame;
  final ShanghaiGame?  shanghaiGame;
  final List<Player>   players;

  const _HistoryEntry._({
    this.x01Game,
    this.cricketGame,
    this.shanghaiGame,
    required this.players,
  });

  factory _HistoryEntry.x01(Game g, List<Player> players) =>
      _HistoryEntry._(x01Game: g, players: players);

  factory _HistoryEntry.cricket(CricketGame g, List<Player> players) =>
      _HistoryEntry._(cricketGame: g, players: players);

  factory _HistoryEntry.shanghai(ShanghaiGame g, List<Player> players) =>
      _HistoryEntry._(shanghaiGame: g, players: players);

  bool      get isCricket  => cricketGame != null;
  bool      get isShanghai => shanghaiGame != null;

  DateTime get createdAt {
    if (isCricket) return cricketGame!.createdAt;
    if (isShanghai) return shanghaiGame!.createdAt;
    return x01Game!.createdAt;
  }

  DateTime? get finishedAt {
    if (isCricket) return cricketGame!.finishedAt;
    if (isShanghai) return shanghaiGame!.finishedAt;
    return x01Game!.finishedAt;
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color? color;

  const _SectionHeader({required this.label, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color ?? cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: (color ?? cs.onSurfaceVariant).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color ?? cs.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final _HistoryEntry entry;
  final VoidCallback onDelete;
  final VoidCallback? onResume;
  final VoidCallback? onShowSummary;

  const _GameTile({
    required this.entry,
    required this.onDelete,
    this.onResume,
    this.onShowSummary,
  });

  @override
  Widget build(BuildContext context) {
    final l          = context.l10n;
    final fmt        = DateFormat('dd.MM.yy  HH:mm');
    final finished   = entry.finishedAt != null;
    final cs         = Theme.of(context).colorScheme;
    final playerNames = entry.players.map((p) => p.name).join(' vs ');

    final subtitle = entry.isCricket
        ? l.cricketGameInfo(
            entry.cricketGame!.variant == CricketVariant.cutThroat
                ? l.cricketVariantCutThroat
                : l.cricketVariantNormal,
          )
        : entry.isShanghai
            ? l.shanghaiGameInfo(_shanghaiVariantLabel(l, entry.shanghaiGame!.variant))
            : l.gameSummaryInfo(
                entry.x01Game!.startScore,
                entry.x01Game!.legs,
                entry.x01Game!.sets,
              );

    final entryId = entry.x01Game?.id ?? entry.cricketGame?.id ?? entry.shanghaiGame?.id;
    final entryPrefix = entry.isCricket ? 'c' : (entry.isShanghai ? 's' : 'x');

    return Dismissible(
      key: ValueKey('$entryPrefix$entryId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onResume ?? onShowSummary,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Mode icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: finished ? cs.primaryContainer : cs.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    entry.isCricket
                        ? Icons.sports_cricket_rounded
                        : entry.isShanghai
                            ? Icons.layers_rounded
                            : (finished ? Icons.check : Icons.play_arrow_rounded),
                    size: 18,
                    color: finished
                        ? cs.onPrimaryContainer
                        : cs.onTertiaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerNames,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              )),
                      Text(
                        fmt.format(entry.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                // Resume chip
                if (!finished)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.tertiary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l.resume,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onTertiary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
