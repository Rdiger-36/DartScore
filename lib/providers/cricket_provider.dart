import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/cricket_game.dart';
import '../models/player.dart';

// ── CricketPlayerState ────────────────────────────────────────────────────────

class CricketPlayerState {
  final String displayName;
  final Player player;
  /// Total marks per field (never decremented; 3 = closed, >3 possible via Double/Triple).
  final Map<int, int> marks;
  final int score;

  const CricketPlayerState({
    required this.displayName,
    required this.player,
    required this.marks,
    required this.score,
  });

  bool hasClosedField(int field) => (marks[field] ?? 0) >= 3;

  bool get hasClosedAll => cricketFields.every(hasClosedField);

  CricketPlayerState copyWith({
    Map<int, int>? marks,
    int? score,
  }) =>
      CricketPlayerState(
        displayName: displayName,
        player:      player,
        marks:       marks ?? Map.of(this.marks),
        score:       score ?? this.score,
      );
}

// ── CricketProvider ────────────────────────────────────────────────────────────

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

  // ── Resume ────────────────────────────────────────────────────────────────

  Future<void> resumeGame(CricketGame game, List<Player> players) async {
    _game = game;
    _playerStates = players.map((p) => CricketPlayerState(
      displayName: p.name,
      player:      p,
      marks:       {},
      score:       0,
    )).toList();
    _currentPlayerIndex = 0;
    _gameOver           = false;
    _winnerId           = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    await _replayState();
    notifyListeners();
  }

  // ── Start ──────────────────────────────────────────────────────────────────

  Future<void> startGame(CricketGame game, List<Player> players) async {
    final gameId = await _db.insertCricketGame(game);
    _game = game.copyWith(); // captures the inserted ID via fromMap below
    // Re-read to get the auto-generated id
    _game = CricketGame(
      id:          gameId,
      variant:     game.variant,
      scoringMode: game.scoringMode,
      legs:        game.legs,
      sets:        game.sets,
      createdAt:   game.createdAt,
      playerIds:   game.playerIds,
    );

    _playerStates = players.map((p) => CricketPlayerState(
      displayName: p.name,
      player:      p,
      marks:       {},
      score:       0,
    )).toList();

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

  void _applyDart(int playerIdx, int field, int multiplier) {
    final state  = _playerStates[playerIdx];
    final isCutThroat = _game!.variant == CricketVariant.cutThroat;
    final isSimple    = _game!.scoringMode == CricketScoringMode.simple;

    final effectiveMarks = isSimple ? 1 : multiplier;
    final currentMarks   = state.marks[field] ?? 0;
    final newTotalMarks  = currentMarks + effectiveMarks;

    // How many marks go towards closing, how many score?
    final marksToClose  = (3 - currentMarks).clamp(0, effectiveMarks);
    final scoringMarks  = effectiveMarks - marksToClose;

    // Update marks for this player (cap at 3 for display, but track excess via score)
    final updatedMarks = Map<int, int>.of(state.marks);
    updatedMarks[field] = newTotalMarks.clamp(0, 3); // visual: max 3

    _playerStates[playerIdx] = state.copyWith(marks: updatedMarks);

    if (scoringMarks <= 0) return;

    // The field is now open (or was already open) — handle scoring
    final fieldValue = field == 25 ? 25 : field;
    final points     = scoringMarks * fieldValue;

    if (isCutThroat) {
      // Distribute points to opponents who haven't closed this field
      for (var i = 0; i < _playerStates.length; i++) {
        if (i == playerIdx) continue;
        if (!_playerStates[i].hasClosedField(field)) {
          _playerStates[i] = _playerStates[i].copyWith(
            score: _playerStates[i].score + points,
          );
        }
      }
    } else {
      // Score for current player — only if at least one opponent hasn't closed it
      final fieldAlive = _playerStates
          .where((_, ) => true)
          .indexed
          .any((e) => e.$1 != playerIdx && !e.$2.hasClosedField(field));
      if (fieldAlive) {
        _playerStates[playerIdx] = _playerStates[playerIdx].copyWith(
          score: _playerStates[playerIdx].score + points,
        );
      }
    }
  }

  // ── End of visit ──────────────────────────────────────────────────────────

  Future<void> _endVisit() async {
    _visitBuffer.clear();

    // A win for the current player is already handled right after the dart
    // that closes their last field (see recordDart), so only the "stalemate"
    // case remains here.

    // All players have closed all fields — nobody can score anymore, decide by score
    if (_playerStates.every((s) => s.hasClosedAll)) {
      await _handleWin(_scoreWinnerIndex());
      return;
    }

    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
    notifyListeners();
  }

  bool _checkWin(int playerIdx) {
    final state = _playerStates[playerIdx];
    if (!state.hasClosedAll) return false;

    final isCutThroat = _game!.variant == CricketVariant.cutThroat;
    if (isCutThroat) {
      return _playerStates
          .where((s) => s.player.id != state.player.id)
          .every((s) => state.score <= s.score);
    } else {
      return _playerStates
          .where((s) => s.player.id != state.player.id)
          .every((s) => state.score >= s.score);
    }
  }

  /// Returns the index of the player who wins when all fields are closed.
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

  Future<void> _handleWin(int playerIdx) async {
    _gameOver = true;
    _winnerId = _playerStates[playerIdx].player.id;
    await _db.updateCricketGame(_game!.copyWith(finishedAt: DateTime.now()));
    notifyListeners();
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

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
      );
      await _db.updateCricketGame(_game!);
    }

    // Replay from scratch for this leg/set
    await _replayState();
    notifyListeners();
  }

  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getCricketThrowsForGame(_game!.id!);

    // Reset marks and scores to zero, keep player identity
    _playerStates = _playerStates
        .map((s) => CricketPlayerState(
              displayName: s.displayName,
              player:      s.player,
              marks:       {},
              score:       0,
            ))
        .toList();

    // Replay all darts in chronological order
    for (final t in allThrows) {
      if (t.isMiss) continue;
      final playerIdx =
          _playerStates.indexWhere((s) => s.player.id == t.playerId);
      if (playerIdx < 0) continue;
      _applyDart(playerIdx, t.field, t.multiplier);
    }

    // Determine current player: fewest completed visits (groups of 3)
    final visitsPerPlayer = <int, int>{
      for (final s in _playerStates) s.player.id!: 0
    };
    for (final s in _playerStates) {
      visitsPerPlayer[s.player.id!] =
          allThrows.where((t) => t.playerId == s.player.id).length ~/ 3;
    }
    final minVisits =
        visitsPerPlayer.values.fold(999, (a, b) => a < b ? a : b);
    _currentPlayerIndex = _playerStates
        .indexWhere((s) => (visitsPerPlayer[s.player.id] ?? 0) == minVisits);
    if (_currentPlayerIndex < 0) _currentPlayerIndex = 0;

    // Rebuild visit buffer for current player
    final pid = currentPlayerState.player.id!;
    final myThrows = allThrows.where((t) => t.playerId == pid).toList();
    final dartsInCurrentVisit = myThrows.length % 3;
    _visitBuffer
      ..clear()
      ..addAll(myThrows.reversed
          .take(dartsInCurrentVisit)
          .toList()
          .reversed);

    _throwHistory
      ..clear()
      ..addAll(allThrows);
  }
}
