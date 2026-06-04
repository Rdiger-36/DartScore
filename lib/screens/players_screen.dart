import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../models/player.dart';
import 'player_stats_screen.dart';
import 'sync_screen.dart';
import '../utils/layout.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wideScreen = screenWidth >= 500;

    final syncFab = FloatingActionButton.extended(
      heroTag: 'sync',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SyncScreen()),
      ),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
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
                  onDelete: () => _confirmDelete(
                      context, context.read<PlayersProvider>(), p),
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
      // Narrow screens: stack both FABs (add player on top, sync below).
      // Wide screens: only add-player here; sync is Positioned on the left.
      floatingActionButton: wideScreen
          ? addFab
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [addFab, const SizedBox(height: 12), syncFab],
            ),
    );
  }

  void _openStats(BuildContext context, Player player) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => PlayerStatsScreen(player: player)));
  }

  void _addPlayer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _PlayerDialog(
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

  void _editPlayer(BuildContext context, Player player) {
    showDialog(
      context: context,
      builder: (_) => _PlayerDialog(
        initial: player,
        onSave: (name, doubles) async {
          await context
              .read<PlayersProvider>()
              .updatePlayer(player.copyWith(name: name, favoriteDoubles: doubles));
        },
      ),
    );
  }

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

class _PrimaryPlayerCard extends StatelessWidget {
  final Player player;
  final VoidCallback onEdit;
  final VoidCallback onStats;

  const _PrimaryPlayerCard({
    required this.player,
    required this.onEdit,
    required this.onStats,
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
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            // Avatar with crown badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primary,
                  child: Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : "?",
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cs.primaryContainer, width: 2),
                    ),
                    child: Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
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
                    style: theme.textTheme.titleLarge?.copyWith(
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
            // Action buttons
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.bar_chart_rounded,
                      color: cs.onPrimaryContainer),
                  tooltip: context.l10n.statsTooltip,
                  onPressed: onStats,
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: cs.onPrimaryContainer),
                  tooltip: context.l10n.edit,
                  onPressed: onEdit,
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

class _OtherPlayerTile extends StatelessWidget {
  final Player player;
  final VoidCallback onEdit;
  final VoidCallback onStats;
  final VoidCallback onDelete;

  const _OtherPlayerTile({
    required this.player,
    required this.onEdit,
    required this.onStats,
    required this.onDelete,
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
              icon: Icon(Icons.delete_outline, color: cs.error),
              tooltip: l.delete,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Player dialog ─────────────────────────────────────────────────────────────

class _PlayerDialog extends StatefulWidget {
  final Player? initial;
  final void Function(String name, String doubles) onSave;

  const _PlayerDialog({this.initial, required this.onSave});

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  late final TextEditingController _nameCtrl;
  String? _selectedDouble;

  static const _allDoubles = [
    'D1','D2','D3','D4','D5','D6','D7','D8','D9','D10',
    'D11','D12','D13','D14','D15','D16','D17','D18','D19','D20',
    'Bull',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _selectedDouble = widget.initial?.favoriteDouble;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
      child: AlertDialog(
      title: Text(
          widget.initial == null ? l.addPlayerTitle : l.editPlayerTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: l.nameLabel,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Text(l.favDoublesTitle,
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _allDoubles.map((d) {
                final selected = _selectedDouble == d;
                return FilterChip(
                  label: Text(d),
                  selected: selected,
                  onSelected: (v) => setState(() =>
                      _selectedDouble = selected ? null : d),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l.save),
        ),
      ],
    ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    widget.onSave(name, _selectedDouble ?? '');
    Navigator.pop(context);
  }
}
