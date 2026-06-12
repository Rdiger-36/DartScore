import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/around_the_clock_game.dart';
import '../models/player.dart';

// ── AroundTheClockPlayerState ─────────────────────────────────────────────────

/// Immutable Around the Clock state for one scoreboard slot: how far it has
/// advanced through the target order, the segments hit on the current target
/// (full-segment variant), and when it finished.
///
/// A slot is either a single player or a whole team. For teams, [players]
/// holds every member and [currentPlayerIdx] tracks whose turn it is within
/// the team; progress and hit segments are shared by the whole team,
/// relay-style. [displayName] is the team or player name shown on the
/// scoreboard.
class AroundTheClockPlayerState {
  final String displayName;
  /// All players in this slot - 1 for individual, N for team.
  final List<Player> players;
  /// Which player in [players] throws NEXT (rotates after each team visit).
  final int currentPlayerIdx;
  /// Whether this slot represents a team rather than a single player.
  final bool isTeamSlot;
  /// Index into [aroundTheClockOrder] of the number this slot must hit next.
  final int progress;
  /// Full-segment variant only: multipliers (1/2/3) already hit on the current target.
  final Set<int> hitSegments;
  /// Total darts thrown once the slot completed the Bull's Eye.
  final int? finishedAtDart;

  const AroundTheClockPlayerState({
    required this.displayName,
    required this.players,
    this.currentPlayerIdx = 0,
    this.isTeamSlot = false,
    this.progress = 0,
    this.hitSegments = const {},
    this.finishedAtDart,
  });

  /// The player who throws next (backward-compatible accessor).
  Player get player => players[currentPlayerIdx];

  /// The number this slot must currently hit.
  int get currentTarget => aroundTheClockOrder[progress.clamp(0, aroundTheClockOrder.length - 1)];

  /// Whether this slot has completed the final target (the Bull).
  bool get isFinished => finishedAtDart != null;

  /// Returns a copy with progress/segments/finish/active player replaced;
  /// identity is preserved.
  AroundTheClockPlayerState copyWith({
    int? progress,
    Set<int>? hitSegments,
    int? finishedAtDart,
    int? currentPlayerIdx,
  }) =>
      AroundTheClockPlayerState(
        displayName: displayName,
        players: players,
        currentPlayerIdx: currentPlayerIdx ?? this.currentPlayerIdx,
        isTeamSlot: isTeamSlot,
        progress: progress ?? this.progress,
        hitSegments: hitSegments ?? this.hitSegments,
        finishedAtDart: finishedAtDart ?? this.finishedAtDart,
      );
}

// ── AroundTheClockProvider ────────────────────────────────────────────────────

/// Active-game state machine for Around the Clock (basic, full-segments, skip).
///
/// Each player works through [aroundTheClockOrder] one target at a time; the
/// first to complete the final Bull target wins instantly. Darts are recorded
/// into a three-dart visit buffer and persisted, so undo deletes the last dart
/// and replays the rest.
class AroundTheClockProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  AroundTheClockGame? _game;
  List<AroundTheClockPlayerState> _playerStates = [];
  int _currentPlayerIndex = 0;
  bool _gameOver = false;
  int? _winnerId;

  /// Darts thrown so far in the current visit (max 3).
  final List<AroundTheClockThrow> _visitBuffer = [];
  /// All persisted throws for undo (newest last).
  final List<AroundTheClockThrow> _throwHistory = [];

  AroundTheClockGame?              get game               => _game;
  List<AroundTheClockPlayerState>  get playerStates       => _playerStates;
  int                              get currentPlayerIndex => _currentPlayerIndex;
  AroundTheClockPlayerState        get currentPlayerState => _playerStates[_currentPlayerIndex];
  bool                             get gameOver           => _gameOver;
  int?                             get winnerId           => _winnerId;
  List<AroundTheClockThrow>        get visitBuffer        => List.unmodifiable(_visitBuffer);
  int                              get dartsInVisit       => _visitBuffer.length;
  bool                             get canUndo            => _throwHistory.isNotEmpty;

  /// The active game's rule variant.
  AroundTheClockVariant get _variant => _game!.variant;

  /// The number the current player must hit next.
  int get activeTarget => currentPlayerState.currentTarget;

  /// Full-segment variant only: multipliers still missing on the active
  /// target before the player can advance.
  List<int>? get neededSegments {
    if (_game == null || _variant != AroundTheClockVariant.fullSegments) return null;
    final target = activeTarget;
    final hit = currentPlayerState.hitSegments;
    // The Bull only has Single (25) and Double (50) - no Triple.
    final segments = target == 25 ? const [1, 2] : const [1, 2, 3];
    return segments.where((m) => !hit.contains(m)).toList();
  }

  // ── Slot construction ────────────────────────────────────────────────────

  /// Builds one scoreboard slot per team (if [teams] is set) or one slot per
  /// player (individual game), each with fresh progress.
  List<AroundTheClockPlayerState> _buildSlots(List<Player> players, List<TeamConfig>? teams) {
    if (teams != null && teams.isNotEmpty) {
      return teams.map((team) {
        final teamPlayers = team.playerIds
            .map((id) => players.firstWhere((p) => p.id == id))
            .toList();
        return AroundTheClockPlayerState(
          displayName: team.name,
          players:     teamPlayers,
          isTeamSlot:  true,
        );
      }).toList();
    }
    return players
        .map((p) => AroundTheClockPlayerState(displayName: p.name, players: [p]))
        .toList();
  }

  // ── Resume / Start ─────────────────────────────────────────────────────────

  /// Restores an in-progress game and rebuilds progress/turn state by replaying
  /// all stored darts.
  Future<void> resumeGame(AroundTheClockGame game, List<Player> players) async {
    _game = game;
    _playerStates = _buildSlots(players, game.teams);
    _currentPlayerIndex = 0;
    _gameOver = false;
    _winnerId = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    await _replayState();
    notifyListeners();
  }

  /// Starts a new game: persists it, builds fresh player states, and resets the
  /// visit buffer and history.
  Future<void> startGame(AroundTheClockGame game, List<Player> players) async {
    final gameId = await _db.insertAroundTheClockGame(game);
    _game = AroundTheClockGame(
      id:        gameId,
      variant:   game.variant,
      legs:      game.legs,
      sets:      game.sets,
      createdAt: game.createdAt,
      playerIds: game.playerIds,
      teams:     game.teams,
    );

    _playerStates = _buildSlots(players, game.teams);
    _currentPlayerIndex = 0;
    _gameOver = false;
    _winnerId = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    notifyListeners();
  }

  // ── Record a dart ──────────────────────────────────────────────────────────

  /// Records one dart. [field]=0 / [multiplier]=0 means miss.
  Future<void> recordDart(int field, int multiplier) async {
    if (_game == null || _gameOver) return;
    if (_visitBuffer.length >= 3) return;

    final t = AroundTheClockThrow(
      gameId:     _game!.id!,
      playerId:   currentPlayerState.player.id!,
      field:      field,
      multiplier: multiplier,
      leg:        1,
      set_:       1,
      thrownAt:   DateTime.now(),
    );
    final id = await _db.insertAroundTheClockThrow(t);
    final saved = AroundTheClockThrow(
      id:         id,
      gameId:     t.gameId,
      playerId:   t.playerId,
      field:      t.field,
      multiplier: t.multiplier,
      leg:        t.leg,
      set_:       t.set_,
      thrownAt:   t.thrownAt,
    );

    _visitBuffer.add(saved);
    _throwHistory.add(saved);

    if (!saved.isMiss) {
      _applyDart(_currentPlayerIndex, saved);

      if (currentPlayerState.isFinished) {
        _visitBuffer.clear();
        await _handleWin(_currentPlayerIndex);
        return;
      }
    }

    if (_visitBuffer.length == 3) {
      await _endVisit();
    } else {
      notifyListeners();
    }
  }

  // ── Apply dart to state ────────────────────────────────────────────────────

  /// Applies one dart to [playerIdx]'s progress per the active variant: advance
  /// on a hit (basic), collect single/double/triple before advancing (full
  /// segments), or skip ahead by the multiplier and via the Bull joker (skip
  /// rules). Records the finishing dart when the final target is completed.
  void _applyDart(int playerIdx, AroundTheClockThrow t) {
    final state  = _playerStates[playerIdx];
    final target = state.currentTarget;

    var newProgress    = state.progress;
    var newHitSegments = state.hitSegments;

    if (t.field == target) {
      switch (_variant) {
        case AroundTheClockVariant.basic:
          newProgress = state.progress + 1;
          break;

        case AroundTheClockVariant.fullSegments:
          // The Bull only has Single (25) and Double (50) - no Triple.
          final required = target == 25 ? const [1, 2] : const [1, 2, 3];
          newHitSegments = {...state.hitSegments, t.multiplier};
          if (newHitSegments.containsAll(required)) {
            newProgress    = state.progress + 1;
            newHitSegments = const {};
          }
          break;

        case AroundTheClockVariant.skipRules:
          final skip = switch (t.multiplier) {
            3 => 3,
            2 => 2,
            _ => 1,
          };
          newProgress = state.progress + skip;
          break;
      }
    } else if (_variant == AroundTheClockVariant.skipRules &&
        t.field == 25 &&
        target != 25) {
      // Bull's Eye joker: skip the current field, advance by one.
      newProgress = state.progress + 1;
    }

    newProgress = newProgress.clamp(0, aroundTheClockOrder.length);

    var updated = state.copyWith(progress: newProgress, hitSegments: newHitSegments);
    if (newProgress >= aroundTheClockOrder.length) {
      final slotPlayerIds = state.players.map((p) => p.id).toSet();
      final dartsThrown = _throwHistory.where((h) => slotPlayerIds.contains(h.playerId)).length;
      updated = updated.copyWith(finishedAtDart: dartsThrown);
    }

    _playerStates[playerIdx] = updated;
  }

  // ── End of visit ──────────────────────────────────────────────────────────

  /// Ends the current three-dart visit and advances to the next slot, rotating
  /// the active player within a team slot first.
  Future<void> _endVisit() async {
    _visitBuffer.clear();
    _advanceSlot();
    notifyListeners();
  }

  /// Advances to the next slot. In team mode, also rotates the player within
  /// the slot that just threw, so its next visit is taken by the next member.
  void _advanceSlot() {
    final s = _playerStates[_currentPlayerIndex];
    if (s.isTeamSlot) {
      final nextIdx = (s.currentPlayerIdx + 1) % s.players.length;
      _playerStates[_currentPlayerIndex] = s.copyWith(currentPlayerIdx: nextIdx);
    }
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
  }

  /// Marks the game over with [playerIdx] as the winner and persists the finish time.
  Future<void> _handleWin(int playerIdx) async {
    _gameOver = true;
    _winnerId = _playerStates[playerIdx].player.id;
    await _db.updateAroundTheClockGame(_game!.copyWith(finishedAt: DateTime.now()));
    notifyListeners();
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

  /// Undoes the last dart: deletes it from the database, un-finishes the game if
  /// it was the winning dart, and replays the remaining darts to rebuild state.
  Future<void> undoLastDart() async {
    if (_game == null || _throwHistory.isEmpty) return;

    final last = _throwHistory.removeLast();
    await _db.deleteAroundTheClockThrow(last.id!);

    if (_visitBuffer.isNotEmpty && _visitBuffer.last.id == last.id) {
      _visitBuffer.removeLast();
    }

    if (_gameOver) {
      _gameOver = false;
      _winnerId = null;
      _game = AroundTheClockGame(
        id:         _game!.id,
        variant:    _game!.variant,
        legs:       _game!.legs,
        sets:       _game!.sets,
        createdAt:  _game!.createdAt,
        finishedAt: null,
        playerIds:  _game!.playerIds,
        teams:      _game!.teams,
      );
      await _db.updateAroundTheClockGame(_game!);
    }

    await _replayState();
    notifyListeners();
  }

  /// Rebuilds the full game state from the persisted darts: resets progress and
  /// turn counters, then replays every dart, advancing turns and detecting the
  /// winning dart along the way.
  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getAroundTheClockThrowsForGame(_game!.id!);

    _playerStates = _playerStates
        .map((s) => AroundTheClockPlayerState(
              displayName: s.displayName,
              players:     s.players,
              isTeamSlot:  s.isTeamSlot,
            ))
        .toList();
    _currentPlayerIndex = 0;
    _gameOver = false;
    _winnerId = null;
    _visitBuffer.clear();
    _throwHistory.clear();

    for (final t in allThrows) {
      _visitBuffer.add(t);
      _throwHistory.add(t);

      if (!t.isMiss) {
        _applyDart(_currentPlayerIndex, t);
        if (currentPlayerState.isFinished) {
          _visitBuffer.clear();
          _gameOver = true;
          _winnerId = currentPlayerState.player.id;
          break;
        }
      }

      if (_visitBuffer.length == 3) {
        _visitBuffer.clear();
        _advanceSlot();
      }
    }
  }
}
