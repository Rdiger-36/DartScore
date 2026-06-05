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
  final int legsWon;
  final int setsWon;

  const CricketPlayerState({
    required this.displayName,
    required this.player,
    required this.marks,
    required this.score,
    required this.legsWon,
    required this.setsWon,
  });

  bool hasClosedField(int field) => (marks[field] ?? 0) >= 3;

  bool get hasClosedAll => cricketFields.every(hasClosedField);

  CricketPlayerState copyWith({
    Map<int, int>? marks,
    int? score,
    int? legsWon,
    int? setsWon,
  }) =>
      CricketPlayerState(
        displayName: displayName,
        player:      player,
        marks:       marks  ?? Map.of(this.marks),
        score:       score  ?? this.score,
        legsWon:     legsWon ?? this.legsWon,
        setsWon:     setsWon ?? this.setsWon,
      );
}

// ── CricketProvider ────────────────────────────────────────────────────────────

class CricketProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  CricketGame?              _game;
  List<CricketPlayerState>  _playerStates = [];
  int                       _currentPlayerIndex = 0;
  int                       _currentLeg  = 1;
  int                       _currentSet  = 1;
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
  int                      get currentLeg         => _currentLeg;
  int                      get currentSet         => _currentSet;
  bool                     get gameOver           => _gameOver;
  int?                     get winnerId           => _winnerId;
  List<CricketThrow>       get visitBuffer        => List.unmodifiable(_visitBuffer);
  int                      get dartsInVisit       => _visitBuffer.length;
  bool                     get canUndo            => _throwHistory.isNotEmpty;

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
      legsWon:     0,
      setsWon:     0,
    )).toList();

    _currentPlayerIndex = 0;
    _currentLeg         = 1;
    _currentSet         = 1;
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
      leg:        _currentLeg,
      set_:       _currentSet,
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

    // Check win condition for current player
    if (_checkWin(_currentPlayerIndex)) {
      await _handleWin(_currentPlayerIndex);
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
      // Win if my score <= all opponents' scores
      return _playerStates
          .where((s) => s.player.id != state.player.id)
          .every((s) => state.score <= s.score);
    } else {
      // Win if my score >= all opponents' scores
      return _playerStates
          .where((s) => s.player.id != state.player.id)
          .every((s) => state.score >= s.score);
    }
  }

  Future<void> _handleWin(int playerIdx) async {
    final state     = _playerStates[playerIdx];
    int legsWon     = state.legsWon + 1;
    int setsWon     = state.setsWon;

    final legsToWinSet = _game!.legs;
    if (legsWon >= legsToWinSet) {
      setsWon += 1;
      legsWon  = 0;
      final setsToWin = _game!.sets;
      if (setsWon >= setsToWin) {
        _playerStates[playerIdx] =
            state.copyWith(legsWon: legsWon, setsWon: setsWon);
        _gameOver = true;
        _winnerId = state.player.id;
        await _db.updateCricketGame(
            _game!.copyWith(finishedAt: DateTime.now()));
        notifyListeners();
        return;
      }
      _currentSet += 1;
      _currentLeg  = 1;
    } else {
      _currentLeg += 1;
    }

    _playerStates[playerIdx] =
        state.copyWith(legsWon: legsWon, setsWon: setsWon);
    _resetForNewLeg();
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
    notifyListeners();
  }

  void _resetForNewLeg() {
    _playerStates = _playerStates
        .map((s) => CricketPlayerState(
              displayName: s.displayName,
              player:      s.player,
              marks:       {},
              score:       0,
              legsWon:     s.legsWon,
              setsWon:     s.setsWon,
            ))
        .toList();
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

    // Replay from scratch for this leg/set
    await _replayState();
    notifyListeners();
  }

  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getCricketThrowsForGame(_game!.id!);

    // Find max leg/set
    int maxLeg = 1, maxSet = 1;
    for (final t in allThrows) {
      if (t.set_ > maxSet) maxSet = t.set_;
      if (t.leg > maxLeg) maxLeg = t.leg;
    }

    // Recompute legs/sets won per player (all completed legs/sets)
    final legsWon = <int, int>{
      for (final s in _playerStates) s.player.id!: 0
    };
    final setsWon = <int, int>{
      for (final s in _playerStates) s.player.id!: 0
    };

    // Determine who won each completed leg
    for (var s = 1; s <= maxSet; s++) {
      for (var l = 1; l <= (s == maxSet ? maxLeg - 1 : maxLeg); l++) {
        final legThrows = allThrows
            .where((t) => t.set_ == s && t.leg == l)
            .toList();
        final winner = _findLegWinner(legThrows, s, l);
        if (winner != null) {
          legsWon[winner] = (legsWon[winner] ?? 0) + 1;
          if ((legsWon[winner] ?? 0) >= _game!.legs) {
            setsWon[winner] = (setsWon[winner] ?? 0) + 1;
            legsWon[winner] = 0;
          }
        }
      }
    }

    // Rebuild current leg state
    final currentLegThrows = allThrows
        .where((t) => t.set_ == maxSet && t.leg == maxLeg)
        .toList();

    _playerStates = _playerStates.map((s) {
      final pid      = s.player.id!;
      final myThrows = currentLegThrows
          .where((t) => t.playerId == pid && !t.isMiss)
          .toList();

      final marks = <int, int>{};
      for (final t in myThrows) {
        final eff = _game!.scoringMode == CricketScoringMode.simple
            ? 1
            : t.multiplier;
        marks[t.field] = ((marks[t.field] ?? 0) + eff).clamp(0, 3);
      }

      return CricketPlayerState(
        displayName: s.displayName,
        player:      s.player,
        marks:       marks,
        score:       0, // recalculated below
        legsWon:     legsWon[pid] ?? 0,
        setsWon:     setsWon[pid] ?? 0,
      );
    }).toList();

    // Replay scoring dart-by-dart in chronological order
    for (final t in currentLegThrows) {
      if (t.isMiss) continue;
      final playerIdx = _playerStates
          .indexWhere((s) => s.player.id == t.playerId);
      if (playerIdx < 0) continue;
      _applyDart(playerIdx, t.field, t.multiplier);
    }

    // Determine current player (who has fewer completed visits)
    final visitsPerPlayer = <int, int>{
      for (final s in _playerStates) s.player.id!: 0
    };
    // Count completed visits = throws completed in full groups of 3 per player
    for (final s in _playerStates) {
      final myCount = currentLegThrows
          .where((t) => t.playerId == s.player.id)
          .length;
      visitsPerPlayer[s.player.id!] = myCount ~/ 3;
    }
    final minVisits = visitsPerPlayer.values
        .fold(999, (a, b) => a < b ? a : b);
    _currentPlayerIndex = _playerStates
        .indexWhere((s) => (visitsPerPlayer[s.player.id] ?? 0) == minVisits);
    if (_currentPlayerIndex < 0) _currentPlayerIndex = 0;

    _currentLeg = maxLeg;
    _currentSet = maxSet;

    // Rebuild visit buffer (remaining darts in current visit for current player)
    final pid = currentPlayerState.player.id!;
    final myCurrentThrows = currentLegThrows
        .where((t) => t.playerId == pid)
        .toList();
    final dartsInCurrentVisit = myCurrentThrows.length % 3;
    _visitBuffer
      ..clear()
      ..addAll(myCurrentThrows.reversed
          .take(dartsInCurrentVisit)
          .toList()
          .reversed);

    _throwHistory
      ..clear()
      ..addAll(allThrows);
  }

  // Find who won a completed leg (simplified: last player to satisfy win condition)
  int? _findLegWinner(List<CricketThrow> legThrows, int set_, int leg) {
    // Rebuild state for this leg and find who satisfied win condition
    final marks   = <int, Map<int, int>>{};
    final scores  = <int, int>{};

    for (final s in _playerStates) {
      marks[s.player.id!]  = {};
      scores[s.player.id!] = 0;
    }

    for (final t in legThrows) {
      if (t.isMiss) continue;
      final pid        = t.playerId;
      final eff        = _game!.scoringMode == CricketScoringMode.simple
          ? 1 : t.multiplier;
      final cur        = marks[pid]?[t.field] ?? 0;
      final newM       = cur + eff;
      marks[pid]![t.field] = newM.clamp(0, 3);

      final scoringM   = (newM - 3).clamp(0, eff);
      if (scoringM <= 0) continue;
      final fieldValue = t.field == 25 ? 25 : t.field;
      final points     = scoringM * fieldValue;

      if (_game!.variant == CricketVariant.cutThroat) {
        for (final s in _playerStates) {
          if (s.player.id == pid) continue;
          final oMarks = marks[s.player.id!]?[t.field] ?? 0;
          if (oMarks < 3) scores[s.player.id!] = (scores[s.player.id!] ?? 0) + points;
        }
      } else {
        final fieldAlive = _playerStates
            .where((s) => s.player.id != pid)
            .any((s) => (marks[s.player.id!]?[t.field] ?? 0) < 3);
        if (fieldAlive) scores[pid] = (scores[pid] ?? 0) + points;
      }

      // Check if this player won
      final closedAll = cricketFields.every((f) => (marks[pid]![f] ?? 0) >= 3);
      if (!closedAll) continue;
      final isCT = _game!.variant == CricketVariant.cutThroat;
      final won  = _playerStates
          .where((s) => s.player.id != pid)
          .every((s) => isCT
              ? (scores[pid] ?? 0) <= (scores[s.player.id!] ?? 0)
              : (scores[pid] ?? 0) >= (scores[s.player.id!] ?? 0));
      if (won) return pid;
    }
    return null;
  }
}
