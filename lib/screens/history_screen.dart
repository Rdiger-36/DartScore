import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database/db_helper.dart';
import '../l10n/app_localizations.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';
import 'history_game_summary_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<_GameEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_GameEntry>> _load() async {
    final db = DbHelper.instance;
    final games = await db.getGames();
    final entries = <_GameEntry>[];
    for (final g in games) {
      final ids = await db.getGamePlayerIds(g.id!);
      final players = <Player>[];
      for (final id in ids) {
        final p = await db.getPlayer(id);
        if (p != null) players.add(p);
      }
      entries.add(_GameEntry(game: g, players: players));
    }
    return entries;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _deleteGame(int gameId) async {
    await DbHelper.instance.snapshotGameStats(gameId);
    await DbHelper.instance.deleteGame(gameId);
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
      // Save stats permanently before erasing throw history
      await DbHelper.instance.snapshotPlayerStats();
      await DbHelper.instance.clearAllGames();
      _reload();
    }
  }

  Future<void> _resumeGame(BuildContext context, _GameEntry entry) async {
    final players = entry.players;
    if (players.isEmpty) return;

    final provider = context.read<GameProvider>();
    await provider.resumeGame(entry.game, players);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GameScreen()),
      ).then((_) => _reload());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.historyTitle),
        actions: [
          FutureBuilder<List<_GameEntry>>(
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
      body: FutureBuilder<List<_GameEntry>>(
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

          // Separate open vs finished
          final open = entries.where((e) => e.game.finishedAt == null).toList();
          final finished = entries.where((e) => e.game.finishedAt != null).toList();

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
                      onDelete: () => _deleteGame(e.game.id!),
                      onResume: () => _resumeGame(context, e),
                    )),
                const SizedBox(height: 8),
              ],
              if (finished.isNotEmpty) ...[
                _SectionHeader(label: context.l10n.finished, count: finished.length),
                ...finished.map((e) => _GameTile(
                      entry: e,
                      onDelete: () => _deleteGame(e.game.id!),
                      onShowSummary: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryGameSummaryScreen(
                            game: e.game,
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
    );
  }
}

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

class _GameEntry {
  final Game game;
  final List<Player> players;
  const _GameEntry({required this.game, required this.players});
}

class _GameTile extends StatelessWidget {
  final _GameEntry entry;
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
    final g = entry.game;
    final fmt = DateFormat('dd.MM.yy  HH:mm');
    final playerNames = entry.players.map((p) => p.name).join(' vs ');
    final finished = g.finishedAt != null;
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(g.id),
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
                // Status icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: finished
                        ? cs.primaryContainer
                        : cs.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    finished ? Icons.check : Icons.play_arrow_rounded,
                    size: 18,
                    color: finished ? cs.onPrimaryContainer : cs.onTertiaryContainer,
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
                      Text(
                        context.l10n.gameSummaryInfo(g.startScore, g.legs, g.sets),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        fmt.format(g.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                // Resume chip or done
                if (!finished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.tertiary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      context.l10n.resume,
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
