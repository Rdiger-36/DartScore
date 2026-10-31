import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/capital_game.dart';
import '../models/player.dart';
import '../providers/capital_provider.dart';
import '../providers/players_provider.dart';
import '../widgets/bot_select_section.dart';
import '../widgets/player_dialog.dart';
import '../widgets/player_select_section.dart';
import '../widgets/starting_order_section.dart';
import '../utils/layout.dart';
import '../utils/player_label.dart';
import 'capital_screen.dart';

/// Setup screen for Capital: pick the players and the throwing order.
///
/// Simpler than the other modes by design. Capital has no teams, because a
/// player named for a team covers that, and only one variant so far, so
/// neither gets a section.
class CapitalSetupScreen extends StatefulWidget {
  const CapitalSetupScreen({super.key});

  @override
  State<CapitalSetupScreen> createState() => _CapitalSetupScreenState();
}

class _CapitalSetupScreenState extends State<CapitalSetupScreen> {
  final List<Player> _selectedPlayers = [];

  /// Whether the computer opponent card is open. Off drops every bot.
  bool _botEnabled = false;

  StartingOrder _startingOrder = StartingOrder.random;

  /// Whether a game can start: one person in it is enough.
  ///
  /// Capital is scored on nothing but your own fifteen rounds, so a solo game
  /// is a practice round against your own last capital rather than a game
  /// missing an opponent.
  bool get _canStart => _selectedPlayers.any((p) => !p.isBot);

  /// The slots the starting order section reorders, one per player.
  ///
  /// The player id identifies an entry across reorders; the index does not,
  /// because it is exactly what the drag changes.
  List<StartingOrderEntry> _startingOrderEntries() => _selectedPlayers
      .map((p) => StartingOrderEntry(
            key: ValueKey(p.id),
            label: p.label(context.l10n),
          ))
      .toList();

  void _reorderStartingOrder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      _selectedPlayers.insert(newIndex, _selectedPlayers.removeAt(oldIndex));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final allPlayers = context.watch<PlayersProvider>().players;

    return Scaffold(
      appBar: AppBar(title: Text(l.capitalSetup)),
      body: ListView(
        padding: contentPadding(context, top: 16, bottom: 16, innerH: 16),
        children: [
          PlayerSelectSection(
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
          const SizedBox(height: 16),
          _botCard(context),

          if (_selectedPlayers.length >= 2) ...[
            const SizedBox(height: 16),
            StartingOrderSection(
              order: _startingOrder,
              entries: _startingOrderEntries(),
              teamMode: false,
              onOrderChanged: (o) => setState(() => _startingOrder = o),
              onReorder: _reorderStartingOrder,
            ),
          ],

          const SizedBox(height: 24),
          if (!_canStart)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l.minOnePlayer,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: _canStart ? _startGame : null,
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

  /// The computer opponent card, which numbers each bot of a tier in turn.
  Widget _botCard(BuildContext context) {
    return BotSelectSection(
      enabled: _botEnabled,
      selectedPlayers: _selectedPlayers,
      onEnabledChanged: (v) => setState(() {
        _botEnabled = v;
        if (!v) _selectedPlayers.removeWhere((p) => p.isBot);
      }),
      onAdd: (level) async {
        final taken = {
          for (final p in _selectedPlayers)
            if (p.botLevel == level) p.botOrdinal!,
        };
        var ordinal = 1;
        while (taken.contains(ordinal)) {
          ordinal++;
        }
        final bot =
            await context.read<PlayersProvider>().botFor(level, ordinal: ordinal);
        if (!mounted) return;
        setState(() => _selectedPlayers.add(bot));
      },
      onRemove: (bot) =>
          setState(() => _selectedPlayers.removeWhere((p) => p.id == bot.id)),
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

  /// Builds the game with the chosen throwing order and navigates to the play
  /// screen.
  Future<void> _startGame() async {
    final players = _startingOrder == StartingOrder.random
        ? (List.of(_selectedPlayers)..shuffle(Random()))
        : List.of(_selectedPlayers);

    final game = CapitalGame(
      legs: 1,
      sets: 1,
      createdAt: DateTime.now(),
      playerIds: players.map((p) => p.id!).toList(),
      startingOrder: _startingOrder,
    );

    await context.read<CapitalProvider>().startGame(game, players);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CapitalScreen()),
      );
    }
  }
}
