import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../models/player.dart';
import '../widgets/player_dialog.dart';
import 'player_stats_screen.dart';
import 'sync_screen.dart';
import '../utils/layout.dart';

/// Player management screen: the primary profile plus all other players, with
/// add, edit, delete, stats, and sync actions.
class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wideScreen = screenWidth >= 500;

    final cs = Theme.of(context).colorScheme;
    final syncFab = FloatingActionButton.extended(
      heroTag: 'sync',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SyncScreen()),
      ),
      backgroundColor: cs.secondary,
      foregroundColor: cs.onSecondary,
      icon: const Icon(Icons.sync_rounded),
      label: Text(l.syncProfile),
    );
    final addFab = FloatingActionButton.extended(
      heroTag: 'addPlayer',
      onPressed: () => _addPlayer(context),
      icon: const Icon(Icons.person_add),
      label: Text(l.addPlayer),
    );

    final listContent = Consumer<PlayersProvider>(
      builder: (context, provider, _) {
        if (provider.players.isEmpty) {
          return Center(child: Text(l.noPlayers));
        }

        final primary = provider.primaryPlayer;
        final others =
            provider.players.where((p) => !p.isPrimary).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            // ── Primary user card ──────────────────────────────────────
            if (primary != null) ...[
              _PrimaryPlayerCard(
                player: primary,
                onEdit: () => _editPlayer(context, primary),
                onStats: () => _openStats(context, primary),
                onShare: () => _openSync(context, primary),
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    l.players,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],

            // ── Other players ──────────────────────────────────────────
            ...others.map((p) => _OtherPlayerTile(
                  player: p,
                  onEdit: () => _editPlayer(context, p),
                  onStats: () => _openStats(context, p),
                  onShare: () => _openSync(context, p),
                )),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l.playersTitle),
      ),
      // On wide screens the sync FAB stays bottom-left via Positioned.
      body: wideScreen
          ? Stack(children: [
              Center(child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
                child: listContent,
              )),
              Positioned(
                left: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
                child: syncFab,
              ),
            ])
          : Center(child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
              child: listContent,
            )),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: wideScreen
          ? addFab
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [addFab, const SizedBox(height: 12), syncFab],
            ),
    );
  }

  /// Opens the lifetime stats screen for [player].
  void _openStats(BuildContext context, Player player) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PlayerStatsScreen(player: player)));
  }

  /// Opens the device-to-device sync screen for [player].
  void _openSync(BuildContext context, Player player) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => SyncScreen(initialPlayer: player)));
  }

  /// Opens the create-player dialog, rejecting names that already exist.
  void _addPlayer(BuildContext context) {
    final existing = context
        .read<PlayersProvider>()
        .players
        .map((p) => p.name.toLowerCase())
        .toList();
    showDialog(
      context: context,
      builder: (_) => PlayerDialog(
        existingNames: existing,
        onSave: (name, doubles) {
          final provider = context.read<PlayersProvider>();
          provider.addPlayer(name).then(
            (player) =>
                provider.updatePlayer(player.copyWith(favoriteDoubles: doubles)),
          );
        },
      ),
    );
  }

  /// Opens the edit dialog for [player] with options to rename, set the favorite
  /// double, make primary, or delete.
  void _editPlayer(BuildContext context, Player player) {
    final existing = context
        .read<PlayersProvider>()
        .players
        .where((p) => p.id != player.id)
        .map((p) => p.name.toLowerCase())
        .toList();
    showDialog(
      context: context,
      builder: (_) => PlayerDialog(
        initialName: player.name,
        initialDouble: player.favoriteDouble,
        isPrimary: player.isPrimary,
        existingNames: existing,
        onSave: (name, doubles) async {
          await context
              .read<PlayersProvider>()
              .updatePlayer(player.copyWith(name: name, favoriteDoubles: doubles));
        },
        onDelete: () => _confirmDelete(
            context, context.read<PlayersProvider>(), player),
        onSetPrimary: player.isPrimary
            ? null
            : () => context.read<PlayersProvider>().setPrimary(player),
      ),
    );
  }

  /// Confirms and deletes [player].
  void _confirmDelete(
      BuildContext context, PlayersProvider provider, Player player) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.deletePlayerTitle),
        content: Text(context.l10n.deletePlayerConfirm(player.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              provider.deletePlayer(player.id!);
              Navigator.pop(context);
            },
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }
}

// ── Primary player card ───────────────────────────────────────────────────────

/// Highlighted card for the primary player with edit, stats, and sync actions.
class _PrimaryPlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback onEdit;
  final VoidCallback onStats;
  final VoidCallback onShare;

  const _PrimaryPlayerCard({
    required this.player,
    required this.onEdit,
    required this.onStats,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;

    return Card(
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
        child: Row(
          children: [
            // Avatar with star badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: cs.primary,
                  child: Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : "?",
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primaryContainer, width: 2),
                    ),
                    child: Icon(Icons.star_rounded, size: 11, color: cs.onPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Name + label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.myProfile,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    player.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  if (player.favoriteDouble != null)
                    Text(
                      '${l.favDoublesPrefix}${player.favoriteDouble}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons in a row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.bar_chart_rounded, color: cs.onPrimaryContainer),
                  tooltip: context.l10n.statsTooltip,
                  onPressed: onStats,
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: cs.onPrimaryContainer),
                  tooltip: context.l10n.edit,
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(Icons.share_rounded, color: cs.onPrimaryContainer),
                  tooltip: context.l10n.sharePlayerTooltip,
                  onPressed: onShare,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Other player tile ─────────────────────────────────────────────────────────

/// List tile for a non-primary player with edit, stats, and sync actions.
class _OtherPlayerTile extends StatelessWidget {
  final Player player;
  final VoidCallback onEdit;
  final VoidCallback onStats;
  final VoidCallback onShare;

  const _OtherPlayerTile({
    required this.player,
    required this.onEdit,
    required this.onStats,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest,
          child: Text(
            player.name.isNotEmpty ? player.name[0].toUpperCase() : "?",
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(player.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: player.favoriteDouble == null
            ? Text(l.noFavDoubles)
            : Text('${l.favDoublesPrefix}${player.favoriteDouble}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: context.l10n.statsTooltip,
              onPressed: onStats,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l.edit,
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.share_rounded, color: cs.primary),
              tooltip: l.sharePlayerTooltip,
              onPressed: onShare,
            ),
          ],
        ),
      ),
    );
  }
}
