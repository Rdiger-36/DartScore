import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/cricket_game.dart';
import '../models/player.dart';

// ── CricketPlayerState ────────────────────────────────────────────────────────

/// Immutable Cricket state for one scoreboard slot: their marks per field and
/// total score.
///
/// A slot is either a single player or a whole team. For teams, [players]
/// holds every member and [currentPlayerIdx] tracks whose turn it is within
/// the team; marks and score are shared by the whole team (real cricket
/// doubles rules). [displayName] is the team or player name shown on the
/// scoreboard.
class CricketPlayerState {
  final String displayName;
  /// All players in this slot — 1 for individual, N for team.
  final List<Player> players;
  /// Which player in [players] throws NEXT (rotates after each team visit).
  final int currentPlayerIdx;
  /// Whether this slot represents a team rather than a single player.
  final bool isTeamSlot;
  /// Total marks per field (never decremented; 3 = closed, >3 possible via Double/Triple).
  final Map<int, int> marks;
  final int score;

  const CricketPlayerState({
    required this.displayName,
    required this.players,
    this.currentPlayerIdx = 0,
    this.isTeamSlot = false,
    required this.marks,
    required this.score,
  });

  /// The player who throws next (backward-compatible accessor).
  Player get player => players[currentPlayerIdx];

  /// Whether this slot has closed [field] (three or more marks).
  bool hasClosedField(int field) => (marks[field] ?? 0) >= 3;

  /// Whether this slot has closed every Cricket field.
  bool get hasClosedAll => cricketFields.every(hasClosedField);

  /// Returns a copy with marks, score, and/or the active player index
  /// replaced; identity is preserved.
  CricketPlayerState copyWith({
    Map<int, int>? marks,
    int? score,
    int? currentPlayerIdx,
  }) =>
      CricketPlayerState(
        displayName:      displayName,
        players:          players,
        currentPlayerIdx: currentPlayerIdx ?? this.currentPlayerIdx,
        isTeamSlot:       isTeamSlot,
        marks:            marks ?? Map.of(this.marks),
        score:            score ?? this.score,
      );
}

// ── CricketProvider ────────────────────────────────────────────────────────────

/// Active-game state machine for Cricket (normal and cut-throat).
///
/// Records darts one at a time into a three-dart visit buffer, applies marks and
/// scoring, and detects a win as soon as a player closes their last field while
/// ahead (or via score once all fields are closed). Every dart is persisted, so
/// undo simply deletes the last throw and replays the remaining ones.
class CricketProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  CricketGame?              _game;
  List<CricketPlayerState>  _playerStates = [];
  int                       _currentPlayerIndex = 0;
  bool                      _gameOver    = false;
  int?                      _winnerId;

  /// Darts thrown so far in the current visit (max 3).
  final List<CricketThrow>  _visitBuffer = [];
  /// All persisted throws for undo (newest last).
  final List<CricketThrow>  _throwHistory = [];

  CricketGame?             get game               => _game;
  List<CricketPlayerState> get playerStates       => _playerStates;
  int                      get currentPlayerIndex => _currentPlayerIndex;
  CricketPlayerState       get currentPlayerState => _playerStates[_currentPlayerIndex];
  bool                     get gameOver           => _gameOver;
  int?                     get winnerId           => _winnerId;
  List<CricketThrow>       get visitBuffer        => List.unmodifiable(_visitBuffer);
  int                      get dartsInVisit       => _visitBuffer.length;
  int                      get throwCount         => _throwHistory.length;
  bool                     get canUndo            => _throwHistory.isNotEmpty;

  // ── Slot construction ────────────────────────────────────────────────────

  /// Builds one scoreboard slot per team (if [teams] is set) or one slot per
  /// player (individual game), each with empty marks and zero score.
  List<CricketPlayerState> _buildSlots(List<Player> players, List<TeamConfig>? teams) {
    if (teams != null && teams.isNotEmpty) {
      return teams.map((team) {
        final teamPlayers = team.playerIds
            .map((id) => players.firstWhere((p) => p.id == id))
            .toList();
        return CricketPlayerState(
          displayName: team.name,
          players:     teamPlayers,
          isTeamSlot:  true,
          marks:       {},
          score:       0,
        );
      }).toList();
    }
    return players.map((p) => CricketPlayerState(
      displayName: p.name,
      players:     [p],
      marks:       {},
      score:       0,
    )).toList();
  }

  // ── Resume ────────────────────────────────────────────────────────────────

  /// Restores an in-progress Cricket game and rebuilds marks/scores by
  /// replaying all stored darts.
  Future<void> resumeGame(CricketGame game, List<Player> players) async {
    _game = game;
    _playerStates = _buildSlots(players, game.teams);
    _currentPlayerIndex = 0;
    _gameOver           = false;
    _winnerId           = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    await _replayState();
    notifyListeners();
  }

  // ── Start ──────────────────────────────────────────────────────────────────

  /// Starts a new Cricket game: persists it, builds fresh zeroed player states,
  /// and resets the visit buffer and history.
  Future<void> startGame(CricketGame game, List<Player> players) async {
    final gameId = await _db.insertCricketGame(game);
    // Re-read to get the auto-generated id
    _game = CricketGame(
      id:          gameId,
      variant:     game.variant,
      scoringMode: game.scoringMode,
      legs:        game.legs,
      sets:        game.sets,
      createdAt:   game.createdAt,
      playerIds:   game.playerIds,
      teams:       game.teams,
    );

    _playerStates = _buildSlots(players, game.teams);

    _currentPlayerIndex = 0;
    _gameOver           = false;
    _winnerId           = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    notifyListeners();
  }

  // ── Record a dart ──────────────────────────────────────────────────────────

  /// Records one dart. [field]=0 / [multiplier]=0 means miss.
  Future<void> recordDart(int field, int multiplier) async {
    if (_game == null || _gameOver) return;
    if (_visitBuffer.length >= 3) return;

    final t = CricketThrow(
      gameId:     _game!.id!,
      playerId:   currentPlayerState.player.id!,
      field:      field,
      multiplier: multiplier,
      leg:        1,
      set_:       1,
      thrownAt:   DateTime.now(),
    );
    final id  = await _db.insertCricketThrow(t);
    final saved = CricketThrow(
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
      _applyDart(_currentPlayerIndex, field, multiplier);

      // A leg ends the instant a player closes the last field while leading
      // (or level) - no need to finish the rest of the visit.
      if (_checkWin(_currentPlayerIndex)) {
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

  /// Applies one scoring dart to [slotIdx]: adds marks toward closing [field]
  /// and awards points for any marks beyond closing, routing points to the
  /// slot (normal) or to opponent slots who have not closed the field
  /// (cut-throat).
  void _applyDart(int slotIdx, int field, int multiplier) {
    final state  = _playerStates[slotIdx];
    final isCutThroat = _game!.variant == CricketVariant.cutThroat;
    final isSimple    = _game!.scoringMode == CricketScoringMode.simple;

    final effectiveMarks = isSimple ? 1 : multiplier;
    final currentMarks   = state.marks[field] ?? 0;
    final newTotalMarks  = currentMarks + effectiveMarks;

    // How many marks go towards closing, how many score?
    final marksToClose  = (3 - currentMarks).clamp(0, effectiveMarks);
    final scoringMarks  = effectiveMarks - marksToClose;

    // Update marks for this slot (cap at 3 for display, but track excess via score)
    final updatedMarks = Map<int, int>.of(state.marks);
    updatedMarks[field] = newTotalMarks.clamp(0, 3); // visual: max 3

    _playerStates[slotIdx] = state.copyWith(marks: updatedMarks);

    if (scoringMarks <= 0) return;

    // The field is now open (or was already open) — handle scoring
    final fieldValue = field == 25 ? 25 : field;
    final points     = scoringMarks * fieldValue;

    if (isCutThroat) {
      // Distribute points to opponent slots who haven't closed this field
      for (var i = 0; i < _playerStates.length; i++) {
        if (i == slotIdx) continue;
        if (!_playerStates[i].hasClosedField(field)) {
          _playerStates[i] = _playerStates[i].copyWith(
            score: _playerStates[i].score + points,
          );
        }
      }
    } else {
      // Score for current slot — only if at least one opponent hasn't closed it
      final fieldAlive = _playerStates
          .indexed
          .any((e) => e.$1 != slotIdx && !e.$2.hasClosedField(field));
      if (fieldAlive) {
        _playerStates[slotIdx] = _playerStates[slotIdx].copyWith(
          score: _playerStates[slotIdx].score + points,
        );
      }
    }
  }

  // ── End of visit ──────────────────────────────────────────────────────────

  /// Ends the current three-dart visit: resolves a score-based win if everyone
  /// has closed all fields, otherwise advances to the next slot.
  Future<void> _endVisit() async {
    _visitBuffer.clear();

    // A win for the current slot is already handled right after the dart
    // that closes their last field (see recordDart), so only the "stalemate"
    // case remains here.

    // All slots have closed all fields — nobody can score anymore, decide by score
    if (_playerStates.every((s) => s.hasClosedAll)) {
      await _handleWin(_scoreWinnerIndex());
      return;
    }

    _advanceSlot();
    notifyListeners();
  }

  /// Advances to the next slot. In team mode, also rotates the player within
  /// the team that just threw, so its next visit is taken by the next member.
  void _advanceSlot() {
    final s = _playerStates[_currentPlayerIndex];
    if (s.isTeamSlot) {
      final nextIdx = (s.currentPlayerIdx + 1) % s.players.length;
      _playerStates[_currentPlayerIndex] = s.copyWith(currentPlayerIdx: nextIdx);
    }
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
  }

  /// Whether [slotIdx] has won: all fields closed and a non-losing score
  /// (highest in normal, lowest in cut-throat) compared to every other slot.
  bool _checkWin(int slotIdx) {
    final state = _playerStates[slotIdx];
    if (!state.hasClosedAll) return false;

    final isCutThroat = _game!.variant == CricketVariant.cutThroat;
    for (var i = 0; i < _playerStates.length; i++) {
      if (i == slotIdx) continue;
      final other = _playerStates[i];
      final ahead = isCutThroat ? state.score <= other.score : state.score >= other.score;
      if (!ahead) return false;
    }
    return true;
  }

  /// Returns the index of the slot that wins when all fields are closed.
  int _scoreWinnerIndex() {
    final isCutThroat = _game!.variant == CricketVariant.cutThroat;
    int best = 0;
    for (var i = 1; i < _playerStates.length; i++) {
      final challenger = _playerStates[i].score;
      final current    = _playerStates[best].score;
      if (isCutThroat ? challenger < current : challenger > current) {
        best = i;
      }
    }
    return best;
  }

  /// Marks the game over with [slotIdx] as the winner and persists the finish time.
  Future<void> _handleWin(int slotIdx) async {
    _gameOver = true;
    _winnerId = _playerStates[slotIdx].player.id;
    await _db.updateCricketGame(_game!.copyWith(finishedAt: DateTime.now()));
    notifyListeners();
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

  /// Undoes the last dart: deletes it from the database, un-finishes the game if
  /// it was the winning dart, and replays the remaining darts to rebuild state.
  Future<void> undoLastDart() async {
    if (_game == null || _throwHistory.isEmpty) return;

    final last = _throwHistory.removeLast();
    await _db.deleteCricketThrow(last.id!);

    // Remove from visit buffer if it's still in there
    if (_visitBuffer.isNotEmpty &&
        _visitBuffer.last.id == last.id) {
      _visitBuffer.removeLast();
    }

    // Undoing the winning dart un-finishes the game (recordDart blocks any
    // dart from being recorded once the game is over, so the last dart in
    // history can only be the winning one if the game was over).
    if (_gameOver) {
      _gameOver = false;
      _winnerId = null;
      _game = CricketGame(
        id:           _game!.id,
        variant:      _game!.variant,
        scoringMode:  _game!.scoringMode,
        legs:         _game!.legs,
        sets:         _game!.sets,
        createdAt:    _game!.createdAt,
        finishedAt:   null,
        playerIds:    _game!.playerIds,
        teams:        _game!.teams,
      );
      await _db.updateCricketGame(_game!);
    }

    // Replay from scratch for this leg/set
    await _replayState();
    notifyListeners();
  }

  /// Rebuilds all slot states from the persisted darts: zeroes marks/scores,
  /// replays every dart chronologically, then restores the current slot, its
  /// active player (for teams), and the in-progress visit buffer.
  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getCricketThrowsForGame(_game!.id!);

    // Reset marks and scores to zero, keep slot identity
    _playerStates = _playerStates
        .map((s) => CricketPlayerState(
              displayName: s.displayName,
              players:     s.players,
              isTeamSlot:  s.isTeamSlot,
              marks:       {},
              score:       0,
            ))
        .toList();

    // Replay all darts in chronological order, routing each to its slot
    for (final t in allThrows) {
      if (t.isMiss) continue;
      final slotIdx = _playerStates
          .indexWhere((s) => s.players.any((p) => p.id == t.playerId));
      if (slotIdx < 0) continue;
      _applyDart(slotIdx, t.field, t.multiplier);
    }

    // Throws per slot, chronological, used to determine turn order
    final slotThrows = _playerStates.map((s) {
      final ids = s.players.map((p) => p.id).toSet();
      return allThrows.where((t) => ids.contains(t.playerId)).toList()
        ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt));
    }).toList();

    // Determine current slot: fewest completed visits (groups of 3)
    final visitsPerSlot = slotThrows.map((t) => t.length ~/ 3).toList();
    final minVisits = visitsPerSlot.fold(999, (a, b) => a < b ? a : b);
    _currentPlayerIndex = visitsPerSlot.indexWhere((v) => v == minVisits);
    if (_currentPlayerIndex < 0) _currentPlayerIndex = 0;

    // Restore the active player within the current slot (team rotation)
    final currentSlot   = _playerStates[_currentPlayerIndex];
    final currentThrows = slotThrows[_currentPlayerIndex];
    if (currentSlot.isTeamSlot) {
      final visits = visitsPerSlot[_currentPlayerIndex];
      _playerStates[_currentPlayerIndex] = currentSlot.copyWith(
        currentPlayerIdx: visits % currentSlot.players.length,
      );
    }

    // Rebuild visit buffer for the current slot
    final dartsInCurrentVisit = currentThrows.length % 3;
    _visitBuffer
      ..clear()
      ..addAll(currentThrows.reversed
          .take(dartsInCurrentVisit)
          .toList()
          .reversed);

    _throwHistory
      ..clear()
      ..addAll(allThrows);
  }
}
