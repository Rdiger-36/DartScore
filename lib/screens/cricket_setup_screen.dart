import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/cricket_game.dart';
import '../models/player.dart';
import '../providers/players_provider.dart';
import '../providers/cricket_provider.dart';
import '../widgets/player_dialog.dart';
import '../utils/layout.dart';
import 'cricket_screen.dart';

class CricketSetupScreen extends StatefulWidget {
  const CricketSetupScreen({super.key});

  @override
  State<CricketSetupScreen> createState() => _CricketSetupScreenState();
}

class _CricketSetupScreenState extends State<CricketSetupScreen> {
  CricketVariant     _variant     = CricketVariant.normal;
  CricketScoringMode _scoringMode = CricketScoringMode.standard;
  final List<Player> _selectedPlayers = [];

  @override
  Widget build(BuildContext context) {
    final l          = context.l10n;
    final theme      = Theme.of(context);
    final allPlayers = context.watch<PlayersProvider>().players;

    return Scaffold(
      appBar: AppBar(title: Text(l.cricketSetup)),
      body: ListView(
        padding: contentPadding(context, top: 16, bottom: 16, innerH: 16),
        children: [
          // ── Variant ──────────────────────────────────────────────────────
          _Section(
            title: l.cricketVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l.cricketNormal),
                      selected: _variant == CricketVariant.normal,
                      onSelected: (_) =>
                          setState(() => _variant = CricketVariant.normal),
                    ),
                    ChoiceChip(
                      label: Text(l.cricketCutThroat),
                      selected: _variant == CricketVariant.cutThroat,
                      onSelected: (_) =>
                          setState(() => _variant = CricketVariant.cutThroat),
                    ),
                  ],
                ),
                if (_variant == CricketVariant.cutThroat) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.cricketCutThroatDesc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Scoring Mode ─────────────────────────────────────────────────
          _Section(
            title: l.cricketScoringMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l.cricketStandard),
                      selected: _scoringMode == CricketScoringMode.standard,
                      onSelected: (_) => setState(
                          () => _scoringMode = CricketScoringMode.standard),
                    ),
                    ChoiceChip(
                      label: Text(l.cricketSimple),
                      selected: _scoringMode == CricketScoringMode.simple,
                      onSelected: (_) => setState(
                          () => _scoringMode = CricketScoringMode.simple),
                    ),
                  ],
                ),
                if (_scoringMode == CricketScoringMode.simple) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.cricketSimpleDesc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
                l.cricketMinPlayers,
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

  Future<void> _startGame() async {
    final players = List.of(_selectedPlayers)..shuffle(Random());
    final game = CricketGame(
      variant:     _variant,
      scoringMode: _scoringMode,
      legs:        1,
      sets:        1,
      createdAt:   DateTime.now(),
      playerIds:   players.map((p) => p.id!).toList(),
    );

    await context.read<CricketProvider>().startGame(game, players);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CricketScreen()),
      );
    }
  }
}

// ── Shared helper widgets (mirrors game_setup_screen.dart) ────────────────────

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

