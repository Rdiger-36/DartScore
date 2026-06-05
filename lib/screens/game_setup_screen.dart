import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../providers/players_provider.dart';
import '../providers/game_provider.dart';
import 'game_screen.dart';
import '../utils/layout.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  int _startScore = 501;
  GameMode _gameMode = GameMode.straightIn;
  CheckoutMode _checkoutMode = CheckoutMode.doubleOut;
  int _legs = 3;
  int _sets = 1;
  final List<Player> _selectedPlayers = [];

  // ── Handicap ─────────────────────────────────────────────────────────────
  bool _handicapEnabled = false;
  final Map<Player, PlayerHandicap> _handicaps = {};

  // ── Team game ─────────────────────────────────────────────────────────────
  bool _teamGameEnabled = false;
  final Map<Player, int> _teamAssignment = {}; // player → team index
  final List<String> _teamNames = ['Team 1', 'Team 2'];
  final List<TextEditingController> _teamNameCtrl = [
    TextEditingController(text: 'Team 1'),
    TextEditingController(text: 'Team 2'),
  ];

  void _addTeam() {
    setState(() {
      final idx = _teamNames.length + 1;
      _teamNames.add('Team $idx');
      _teamNameCtrl.add(TextEditingController(text: 'Team $idx'));
    });
  }

  void _removeTeam(int ti) {
    if (_teamNames.length <= 2) return;
    setState(() {
      _teamNames.removeAt(ti);
      _teamNameCtrl.removeAt(ti);
      // Reassign players that were in removed team or have out-of-range index
      for (final p in _selectedPlayers) {
        final current = _teamAssignment[p] ?? 0;
        if (current == ti) {
          _teamAssignment[p] = 0;
        } else if (current > ti) {
          _teamAssignment[p] = current - 1;
        }
      }
    });
  }

  static const _scoreOptions = [101, 170, 201, 301, 501, 701, 1001];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allPlayers = context.watch<PlayersProvider>().players;

    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.gameSetup)),
      body: ListView(
        padding: contentPadding(context, top: 16, bottom: 16, innerH: 16),
        children: [
          _Section(
            title: l.startScore,
            child: Wrap(
              spacing: 8,
              children: _scoreOptions.map((s) {
                return ChoiceChip(
                  label: Text('$s'),
                  selected: _startScore == s,
                  onSelected: (_) => setState(() => _startScore = s),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: l.checkIn,
            child: Wrap(
              spacing: 8,
              children: const [
                (GameMode.straightIn, 'Straight'),
                (GameMode.doubleIn,   'Double'),
                (GameMode.masterIn,   'Master'),
              ].map((e) => ChoiceChip(
                label: Text(e.$2),
                selected: _gameMode == e.$1,
                onSelected: (_) => setState(() => _gameMode = e.$1),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: l.checkOut,
            child: Wrap(
              spacing: 8,
              children: const [
                (CheckoutMode.straightOut, 'Straight'),
                (CheckoutMode.doubleOut,   'Double'),
                (CheckoutMode.masterOut,   'Master'),
              ].map((e) => ChoiceChip(
                label: Text(e.$2),
                selected: _checkoutMode == e.$1,
                onSelected: (_) => setState(() => _checkoutMode = e.$1),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: l.players,
            child: allPlayers.isEmpty
                ? Column(
                    children: [
                      Text(l.noPlayersAvail),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l.addPlayerLink),
                      ),
                    ],
                  )
                : Column(
                    children: allPlayers.map((p) {
                      final selected = _selectedPlayers.any((s) => s.id == p.id);
                      final idx = _selectedPlayers.indexWhere((s) => s.id == p.id);
                      return CheckboxListTile(
                        title: Text(p.name),
                        subtitle: selected ? Text(l.playerN(idx + 1)) : null,
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedPlayers.add(p);
                            } else {
                              _selectedPlayers.removeWhere((s) => s.id == p.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          // ── Legs & Sets (nur bei ≥2 Spielern) ─────────────────────────
          if (_selectedPlayers.length >= 2) ...[
            const SizedBox(height: 16),
            _Section(
              title: l.legsSets,
              child: Row(
                children: [
                  Expanded(
                    child: _Stepper(
                      label: 'Legs',
                      value: _legs,
                      min: 1,
                      max: 9,
                      onChanged: (v) => setState(() => _legs = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _Stepper(
                      label: 'Sets',
                      value: _sets,
                      min: 1,
                      max: 9,
                      onChanged: (v) => setState(() => _sets = v),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selectedPlayers.length == 1) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    l.soloLegsHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // ── Handicap ──────────────────────────────────────────────────
          if (_selectedPlayers.length >= 2)
            _HandicapSection(
              enabled: _handicapEnabled,
              players: _selectedPlayers,
              handicaps: _handicaps,
              gameCheckIn: _gameMode,
              gameCheckOut: _checkoutMode,
              onToggle: (v) => setState(() {
                _handicapEnabled = v;
                if (v) {
                  // Pre-fill handicaps with game defaults
                  for (final p in _selectedPlayers) {
                    _handicaps.putIfAbsent(
                      p,
                      () => PlayerHandicap(
                          checkIn: _gameMode, checkOut: _checkoutMode),
                    );
                  }
                }
              }),
              onChanged: (p, h) => setState(() => _handicaps[p] = h),
            ),
          const SizedBox(height: 16),
          // ── Team game ──────────────────────────────────────────────────
          if (_selectedPlayers.length >= 2)
            _TeamSection(
              enabled: _teamGameEnabled,
              players: _selectedPlayers,
              teamAssignment: _teamAssignment,
              teamNames: _teamNames,
              teamNameCtrl: _teamNameCtrl,
              onToggle: (v) => setState(() {
                _teamGameEnabled = v;
                if (v) {
                  _handicapEnabled = false;
                  for (var i = 0; i < _selectedPlayers.length; i++) {
                    _teamAssignment[_selectedPlayers[i]] = i % _teamNames.length;
                  }
                }
              }),
              onAssignmentChanged: (p, t) =>
                  setState(() => _teamAssignment[p] = t),
              onNameChanged: (i, name) =>
                  setState(() => _teamNames[i] = name),
              onAddTeam: _addTeam,
              onRemoveTeam: _removeTeam,
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _selectedPlayers.isNotEmpty ? _startGame : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(_selectedPlayers.length == 1
                ? l.startOpenPlay
                : l.startGame),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: theme.textTheme.titleMedium,
            ),
          ),
          if (_selectedPlayers.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.minOnePLayer,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else if (_selectedPlayers.length == 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                l.openPlayHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startGame() async {
    final isSolo = _selectedPlayers.length == 1;
    final game = Game(
      startScore: _startScore,
      gameMode: _gameMode,
      checkoutMode: _checkoutMode,
      legs: isSolo ? 1 : _legs,
      sets: isSolo ? 1 : _sets,
      createdAt: DateTime.now(),
    );
    final players = List.of(_selectedPlayers)..shuffle(Random());

    // Build team config if team game is enabled
    List<TeamConfig>? teamConfigs;
    if (_teamGameEnabled && _selectedPlayers.length >= 2) {
      teamConfigs = List.generate(_teamNames.length, (ti) {
        final teamPlayers = players
            .where((p) => (_teamAssignment[p] ?? 0) == ti)
            .toList();
        return TeamConfig(
          name:      _teamNames[ti],
          playerIds: teamPlayers.map((p) => p.id!).toList(),
        );
      }).where((t) => t.playerIds.isNotEmpty).toList();
    }

    // Build handicap map (playerId → PlayerHandicap) if enabled
    final Map<int, PlayerHandicap>? handicapMap = _handicapEnabled && !_teamGameEnabled
        ? {
            for (final p in players)
              if (p.id != null && _handicaps.containsKey(p))
                p.id!: _handicaps[p]!,
          }
        : null;

    final gameWithTeams = Game(
      startScore:   game.startScore,
      gameMode:     game.gameMode,
      checkoutMode: game.checkoutMode,
      legs:         game.legs,
      sets:         game.sets,
      createdAt:    game.createdAt,
      teams:        teamConfigs,
    );

    final provider = context.read<GameProvider>();
    await provider.startGame(gameWithTeams, players, handicaps: handicapMap);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    }
  }
}

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
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Handicap section ──────────────────────────────────────────────────────────

class _HandicapSection extends StatelessWidget {
  final bool enabled;
  final List<Player> players;
  final Map<Player, PlayerHandicap> handicaps;
  final GameMode gameCheckIn;
  final CheckoutMode gameCheckOut;
  final ValueChanged<bool> onToggle;
  final void Function(Player, PlayerHandicap) onChanged;

  const _HandicapSection({
    required this.enabled,
    required this.players,
    required this.handicaps,
    required this.gameCheckIn,
    required this.gameCheckOut,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle row
            Row(
              children: [
                Icon(Icons.tune_rounded,
                    size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.handicap,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(value: enabled, onChanged: onToggle),
              ],
            ),
            if (enabled) ...[
              Text(
                context.l10n.handicapDesc,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ...players.map((p) {
                final h = handicaps[p] ??
                    PlayerHandicap(
                        checkIn: gameCheckIn, checkOut: gameCheckOut);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              p.name.isNotEmpty
                                  ? p.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(p.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _ModeDropdown<GameMode>(
                              label: 'Check-In',
                              value: h.checkIn,
                              items: const [
                                (GameMode.straightIn, 'Straight'),
                                (GameMode.doubleIn,   'Double'),
                                (GameMode.masterIn,   'Master'),
                              ],
                              onChanged: (v) => onChanged(
                                p, h.copyWith(checkIn: v)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ModeDropdown<CheckoutMode>(
                              label: 'Check-Out',
                              value: h.checkOut,
                              items: const [
                                (CheckoutMode.straightOut, 'Straight'),
                                (CheckoutMode.doubleOut,   'Double'),
                                (CheckoutMode.masterOut,   'Master'),
                              ],
                              onChanged: (v) => onChanged(
                                p, h.copyWith(checkOut: v)),
                            ),
                          ),
                        ],
                      ),
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

class _ModeDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  const _ModeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          isDense: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e.$1,
                    child: Text(e.$2),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

// ── Team section ──────────────────────────────────────────────────────────────

class _TeamSection extends StatelessWidget {
  final bool enabled;
  final List<Player> players;
  final Map<Player, int> teamAssignment;
  final List<String> teamNames;
  final List<TextEditingController> teamNameCtrl;
  final ValueChanged<bool> onToggle;
  final void Function(Player, int) onAssignmentChanged;
  final void Function(int, String) onNameChanged;
  final VoidCallback onAddTeam;
  final void Function(int) onRemoveTeam;

  const _TeamSection({
    required this.enabled,
    required this.players,
    required this.teamAssignment,
    required this.teamNames,
    required this.teamNameCtrl,
    required this.onToggle,
    required this.onAssignmentChanged,
    required this.onNameChanged,
    required this.onAddTeam,
    required this.onRemoveTeam,
  });

  static const List<Color> _teamColors = [
    Color(0xFF1565C0), // blue
    Color(0xFF2E7D32), // green
    Color(0xFFC62828), // red
    Color(0xFF6A1B9A), // purple
    Color(0xFFE65100), // orange
    Color(0xFF00695C), // teal
  ];

  Color _teamColor(int ti) => _teamColors[ti % _teamColors.length];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_rounded, size: 20, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(context.l10n.teamGame,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
                Switch(value: enabled, onChanged: onToggle),
              ],
            ),
            if (enabled) ...[
              Text(
                context.l10n.teamGameDesc,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              // Team name inputs + remove buttons
              ...List.generate(teamNames.length, (ti) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _teamColor(ti),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: teamNameCtrl[ti],
                        decoration: InputDecoration(
                          labelText: 'Team ${ti + 1}',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        onChanged: (v) => onNameChanged(ti, v),
                      ),
                    ),
                    if (teamNames.length > 2) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        color: cs.error,
                        onPressed: () => onRemoveTeam(ti),
                        tooltip: 'Team entfernen',
                      ),
                    ],
                  ],
                ),
              )),
              // Add team button
              if (teamNames.length < players.length)
                TextButton.icon(
                  onPressed: onAddTeam,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Team hinzufügen'),
                ),
              const SizedBox(height: 4),
              const Divider(),
              const SizedBox(height: 4),
              // Player assignment via dropdown
              ...players.map((p) {
                final assigned = teamAssignment[p] ?? 0;
                final clampedAssigned = assigned.clamp(0, teamNames.length - 1);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: _teamColor(clampedAssigned).withValues(alpha: 0.2),
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _teamColor(clampedAssigned),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(p.name, style: theme.textTheme.bodyMedium),
                      ),
                      DropdownButton<int>(
                        value: clampedAssigned,
                        underline: const SizedBox(),
                        isDense: true,
                        items: List.generate(teamNames.length, (ti) =>
                          DropdownMenuItem(
                            value: ti,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _teamColor(ti),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  teamNames[ti],
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) onAssignmentChanged(p, v);
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}
