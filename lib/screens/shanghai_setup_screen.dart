import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/shanghai_game.dart';
import '../models/player.dart';
import '../providers/players_provider.dart';
import '../providers/shanghai_provider.dart';
import '../widgets/player_dialog.dart';
import '../utils/layout.dart';
import 'shanghai_screen.dart';

/// Setup screen for Shanghai: pick the rule variant and the players, then start
/// the game.
class ShanghaiSetupScreen extends StatefulWidget {
  const ShanghaiSetupScreen({super.key});

  @override
  State<ShanghaiSetupScreen> createState() => _ShanghaiSetupScreenState();
}

class _ShanghaiSetupScreenState extends State<ShanghaiSetupScreen> {
  ShanghaiVariant _variant = ShanghaiVariant.classic;
  final List<Player> _selectedPlayers = [];

  /// Localized description of the currently selected rule variant.
  String _variantDesc(AppLocalizations l) {
    switch (_variant) {
      case ShanghaiVariant.classic:
        return l.shanghaiClassicDesc;
      case ShanghaiVariant.clockwise:
        return l.shanghaiClockwiseDesc;
      case ShanghaiVariant.sequential:
        return l.shanghaiSequentialDesc;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l          = context.l10n;
    final theme      = Theme.of(context);
    final allPlayers = context.watch<PlayersProvider>().players;

    return Scaffold(
      appBar: AppBar(title: Text(l.shanghaiSetup)),
      body: ListView(
        padding: contentPadding(context, top: 16, bottom: 16, innerH: 16),
        children: [
          // ── Variant ──────────────────────────────────────────────────────
          _Section(
            title: l.shanghaiVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l.shanghaiClassic),
                      selected: _variant == ShanghaiVariant.classic,
                      onSelected: (_) =>
                          setState(() => _variant = ShanghaiVariant.classic),
                    ),
                    ChoiceChip(
                      label: Text(l.shanghaiClockwise),
                      selected: _variant == ShanghaiVariant.clockwise,
                      onSelected: (_) =>
                          setState(() => _variant = ShanghaiVariant.clockwise),
                    ),
                    ChoiceChip(
                      label: Text(l.shanghaiSequential),
                      selected: _variant == ShanghaiVariant.sequential,
                      onSelected: (_) =>
                          setState(() => _variant = ShanghaiVariant.sequential),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _variantDesc(l),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Players ───────────────────────────────────────────────────────
          _PlayersSection(
            allPlayers: allPlayers,
            selectedPlayers: _selectedPlayers,
            onToggle: (p, selected) {
              setState(() {
                if (selected) {
                  _selectedPlayers.add(p);
                } else {
                  _selectedPlayers.removeWhere((s) => s.id == p.id);
                }
              });
            },
            onAddPlayer: () => _showAddPlayerDialog(context),
          ),

          const SizedBox(height: 24),
          if (_selectedPlayers.length < 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l.shanghaiMinPlayers,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed:
                _selectedPlayers.length >= 2 ? _startGame : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l.startGame),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the create-player dialog and adds the new player to the selection.
  void _showAddPlayerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => PlayerDialog(
        onSave: (name, doubles) async {
          final provider = context.read<PlayersProvider>();
          final player = await provider.addPlayer(name);
          final updated = player.copyWith(favoriteDoubles: doubles);
          await provider.updatePlayer(updated);
          setState(() => _selectedPlayers.add(updated));
        },
      ),
    );
  }

  /// Builds the game with a randomized player order and navigates to the play screen.
  Future<void> _startGame() async {
    final players = List.of(_selectedPlayers)..shuffle(Random());
    final game = ShanghaiGame(
      variant:   _variant,
      legs:      1,
      sets:      1,
      createdAt: DateTime.now(),
      playerIds: players.map((p) => p.id!).toList(),
    );

    await context.read<ShanghaiProvider>().startGame(game, players);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ShanghaiScreen()),
      );
    }
  }
}

// ── Shared helper widgets (mirrors cricket_setup_screen.dart) ─────────────────

/// A titled card grouping a block of setup options.
class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Player picker listing all players with selection toggles and an add button.
class _PlayersSection extends StatelessWidget {
  final List<Player> allPlayers;
  final List<Player> selectedPlayers;
  final void Function(Player, bool) onToggle;
  final VoidCallback onAddPlayer;

  const _PlayersSection({
    required this.allPlayers,
    required this.selectedPlayers,
    required this.onToggle,
    required this.onAddPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l     = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.players,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: onAddPlayer,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: Text(l.addPlayer),
                  style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (allPlayers.isEmpty)
              Text(l.noPlayersAvail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant))
            else
              ...allPlayers.map((p) {
                final selected = selectedPlayers.any((s) => s.id == p.id);
                final idx =
                    selectedPlayers.indexWhere((s) => s.id == p.id);
                return CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  subtitle: selected ? Text(l.playerN(idx + 1)) : null,
                  value: selected,
                  onChanged: (v) => onToggle(p, v == true),
                );
              }),
          ],
        ),
      ),
    );
  }
}
