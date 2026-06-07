import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/shanghai_game.dart';
import '../models/player.dart';

// ── ShanghaiPlayerState ───────────────────────────────────────────────────────

class ShanghaiPlayerState {
  final String displayName;
  final Player player;
  final int score;
  /// Sequential variant only: the number this player is currently aiming for (1-20).
  final int progress;
  /// Sequential variant only: total darts thrown once the player completed target 20.
  final int? finishedAtDart;

  const ShanghaiPlayerState({
    required this.displayName,
    required this.player,
    required this.score,
    this.progress = 1,
    this.finishedAtDart,
  });

  ShanghaiPlayerState copyWith({
    int? score,
    int? progress,
    int? finishedAtDart,
  }) =>
      ShanghaiPlayerState(
        displayName: displayName,
        player: player,
        score: score ?? this.score,
        progress: progress ?? this.progress,
        finishedAtDart: finishedAtDart ?? this.finishedAtDart,
      );
}

// ── Variant constants ─────────────────────────────────────────────────────────

const int _classicMaxRound = 9;
const int _clockwiseMaxTarget = 7;
const int _sequentialMaxTarget = 20;

// ── ShanghaiProvider ──────────────────────────────────────────────────────────

class ShanghaiProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  ShanghaiGame? _game;
  List<ShanghaiPlayerState> _playerStates = [];
  int _currentPlayerIndex = 0;
  int _currentRound = 1;
  bool _gameOver = false;
  int? _winnerId;

  /// Darts thrown so far in the current visit.
  final List<ShanghaiThrow> _visitBuffer = [];
  /// All persisted throws for undo (newest last).
  final List<ShanghaiThrow> _throwHistory = [];

  /// Index of a player who threw a Shanghai and is awaiting confirmation
  /// (voided if the very next player also throws a Shanghai).
  int? _pendingShanghaiIdx;

  ShanghaiGame? get game => _game;
  List<ShanghaiPlayerState> get playerStates => _playerStates;
  int get currentPlayerIndex => _currentPlayerIndex;
  ShanghaiPlayerState get currentPlayerState => _playerStates[_currentPlayerIndex];
  int get currentRound => _currentRound;
  bool get gameOver => _gameOver;
  int? get winnerId => _winnerId;
  List<ShanghaiThrow> get visitBuffer => List.unmodifiable(_visitBuffer);
  int get dartsInVisit => _visitBuffer.length;
  bool get canUndo => _throwHistory.isNotEmpty;

  ShanghaiVariant get _variant => _game!.variant;

  /// The number the next dart in the current visit aims at.
  int get activeTarget {
    switch (_variant) {
      case ShanghaiVariant.classic:
        return _currentRound;
      case ShanghaiVariant.clockwise:
        return _visitBuffer.length + 1;
      case ShanghaiVariant.sequential:
        return currentPlayerState.progress;
    }
  }

  int get maxTarget {
    switch (_variant) {
      case ShanghaiVariant.classic:
        return _classicMaxRound;
      case ShanghaiVariant.clockwise:
        return _clockwiseMaxTarget;
      case ShanghaiVariant.sequential:
        return _sequentialMaxTarget;
    }
  }

  int get visitDartLimit => _variant == ShanghaiVariant.clockwise ? _clockwiseMaxTarget : 3;

  // ── Resume / Start ─────────────────────────────────────────────────────────

  Future<void> resumeGame(ShanghaiGame game, List<Player> players) async {
    _game = game;
    _resetPlayerStates(players);
    _currentPlayerIndex = 0;
    _currentRound = 1;
    _gameOver = false;
    _winnerId = null;
    _pendingShanghaiIdx = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    await _replayState();
    notifyListeners();
  }

  Future<void> startGame(ShanghaiGame game, List<Player> players) async {
    final gameId = await _db.insertShanghaiGame(game);
    _game = ShanghaiGame(
      id: gameId,
      variant: game.variant,
      legs: game.legs,
      sets: game.sets,
      createdAt: game.createdAt,
      playerIds: game.playerIds,
    );

    _resetPlayerStates(players);
    _currentPlayerIndex = 0;
    _currentRound = 1;
    _gameOver = false;
    _winnerId = null;
    _pendingShanghaiIdx = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    notifyListeners();
  }

  void _resetPlayerStates(List<Player> players) {
    _playerStates = players
        .map((p) => ShanghaiPlayerState(displayName: p.name, player: p, score: 0))
        .toList();
  }

  // ── Record a dart ──────────────────────────────────────────────────────────

  /// Records one dart for the active target. [multiplier]=0 means miss.
  Future<void> recordDart(int multiplier) async {
    if (_game == null || _gameOver) return;
    if (_visitBuffer.length >= visitDartLimit) return;

    final target = activeTarget;
    final t = ShanghaiThrow(
      gameId: _game!.id!,
      playerId: currentPlayerState.player.id!,
      target: target,
      multiplier: multiplier,
      round: _currentRound,
      leg: 1,
      set_: 1,
      thrownAt: DateTime.now(),
    );
    final id = await _db.insertShanghaiThrow(t);
    final saved = ShanghaiThrow(
      id: id,
      gameId: t.gameId,
      playerId: t.playerId,
      target: t.target,
      multiplier: t.multiplier,
      round: t.round,
      leg: t.leg,
      set_: t.set_,
      thrownAt: t.thrownAt,
    );

    _visitBuffer.add(saved);
    _throwHistory.add(saved);

    if (!saved.isMiss) {
      _applyDart(_currentPlayerIndex, saved);
    }

    await _maybeEndVisit();
    notifyListeners();
  }

  void _applyDart(int playerIdx, ShanghaiThrow t) {
    final state = _playerStates[playerIdx];
    final points = t.multiplier * t.target;
    var updated = state.copyWith(score: state.score + points);

    if (_variant == ShanghaiVariant.sequential && t.target == updated.progress) {
      final nextProgress = updated.progress + 1;
      updated = updated.copyWith(progress: nextProgress);
      if (updated.progress > _sequentialMaxTarget) {
        final dartsThrown = _throwHistory.where((h) => h.playerId == state.player.id).length;
        updated = updated.copyWith(finishedAtDart: dartsThrown);
      }
    }

    _playerStates[playerIdx] = updated;
  }

  // ── Visit completion ───────────────────────────────────────────────────────

  Future<void> _maybeEndVisit() async {
    final visitComplete = _isVisitComplete();
    if (!visitComplete) return;
    await _endVisit();
  }

  bool _isVisitComplete() {
    if (_visitBuffer.length >= visitDartLimit) return true;
    if (_variant == ShanghaiVariant.sequential &&
        currentPlayerState.progress > _sequentialMaxTarget) {
      return true;
    }
    return false;
  }

  Future<void> _endVisit() async {
    final visitDarts = List<ShanghaiThrow>.of(_visitBuffer);
    _visitBuffer.clear();

    final shanghai = _isShanghai(visitDarts, _currentPlayerIndex);
    // True if no further visit will follow (classic/clockwise reach their
    // scheduled end on this very visit) — there is no "next player" left
    // who could cancel a Shanghai, so it must be confirmed immediately.
    final isLastScheduledVisit = _isGameComplete();

    if (_pendingShanghaiIdx != null) {
      final pendingIdx = _pendingShanghaiIdx!;
      _pendingShanghaiIdx = null;
      if (!shanghai) {
        await _handleWin(pendingIdx);
        return;
      }
      // Both threw a Shanghai back-to-back: voided, game continues.
    } else if (shanghai) {
      if (isLastScheduledVisit) {
        await _handleWin(_currentPlayerIndex);
        return;
      }
      _pendingShanghaiIdx = _currentPlayerIndex;
    }

    // Sequential: first to complete target 20 wins outright (no pending check).
    if (_variant == ShanghaiVariant.sequential &&
        currentPlayerState.finishedAtDart != null) {
      _pendingShanghaiIdx = null;
      await _handleWin(_currentPlayerIndex);
      return;
    }

    if (isLastScheduledVisit) {
      await _handleWin(_scoreWinnerIndex());
      return;
    }

    _advanceTurn();
    notifyListeners();
  }

  bool _isShanghai(List<ShanghaiThrow> visitDarts, int playerIdx) {
    final hits = visitDarts.where((d) => !d.isMiss).toList();
    switch (_variant) {
      case ShanghaiVariant.classic:
        if (hits.length < 3) return false;
        final mults = hits.map((d) => d.multiplier).toSet();
        final sameTarget = hits.every((d) => d.target == hits.first.target);
        return sameTarget && mults.containsAll([1, 2, 3]);
      case ShanghaiVariant.clockwise:
        return _hasThreeConsecutiveHits(visitDarts);
      case ShanghaiVariant.sequential:
        return _hasThreeConsecutiveHits(visitDarts);
    }
  }

  /// True if the visit contains 3 consecutive darts that each hit their
  /// (distinct, consecutive) target.
  bool _hasThreeConsecutiveHits(List<ShanghaiThrow> visitDarts) {
    for (var i = 0; i + 2 < visitDarts.length; i++) {
      final a = visitDarts[i];
      final b = visitDarts[i + 1];
      final c = visitDarts[i + 2];
      if (a.isMiss || b.isMiss || c.isMiss) continue;
      if (b.target == a.target + 1 && c.target == b.target + 1) {
        return true;
      }
    }
    return false;
  }

  bool _isGameComplete() {
    switch (_variant) {
      case ShanghaiVariant.classic:
        return _currentRound == _classicMaxRound &&
            _currentPlayerIndex == _playerStates.length - 1;
      case ShanghaiVariant.clockwise:
        return _currentPlayerIndex == _playerStates.length - 1;
      case ShanghaiVariant.sequential:
        return false; // ends only via outright win (handled in _endVisit)
    }
  }

  void _advanceTurn() {
    final isLastPlayer = _currentPlayerIndex == _playerStates.length - 1;
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;

    if (_variant == ShanghaiVariant.classic && isLastPlayer) {
      _currentRound++;
    }
  }

  int _scoreWinnerIndex() {
    int best = 0;
    for (var i = 1; i < _playerStates.length; i++) {
      if (_playerStates[i].score > _playerStates[best].score) {
        best = i;
      }
    }
    return best;
  }

  Future<void> _handleWin(int playerIdx) async {
    _gameOver = true;
    _winnerId = _playerStates[playerIdx].player.id;
    await _db.updateShanghaiGame(_game!.copyWith(finishedAt: DateTime.now()));
    notifyListeners();
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

  Future<void> undoLastDart() async {
    if (_game == null || _throwHistory.isEmpty) return;

    final last = _throwHistory.removeLast();
    await _db.deleteShanghaiThrow(last.id!);

    if (_visitBuffer.isNotEmpty && _visitBuffer.last.id == last.id) {
      _visitBuffer.removeLast();
    }

    await _replayState();
    notifyListeners();
  }

  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getShanghaiThrowsForGame(_game!.id!);

    _playerStates = _playerStates
        .map((s) => ShanghaiPlayerState(displayName: s.displayName, player: s.player, score: 0))
        .toList();

    _gameOver = false;
    _winnerId = null;
    _pendingShanghaiIdx = null;
    _currentPlayerIndex = 0;
    _currentRound = 1;
    _visitBuffer.clear();
    _throwHistory.clear();

    for (final t in allThrows) {
      _visitBuffer.add(t);
      _throwHistory.add(t);
      if (!t.isMiss) {
        _applyDart(_currentPlayerIndex, t);
      }
      if (_isVisitComplete()) {
        await _replayEndVisit();
      }
      if (_gameOver) break;
    }
  }

  /// Like [_endVisit] but used during replay: never persists, only updates turn state.
  Future<void> _replayEndVisit() async {
    final visitDarts = List<ShanghaiThrow>.of(_visitBuffer);
    _visitBuffer.clear();

    final shanghai = _isShanghai(visitDarts, _currentPlayerIndex);
    final isLastScheduledVisit = _isGameComplete();

    if (_pendingShanghaiIdx != null) {
      final pendingIdx = _pendingShanghaiIdx!;
      _pendingShanghaiIdx = null;
      if (!shanghai) {
        _gameOver = true;
        _winnerId = _playerStates[pendingIdx].player.id;
        return;
      }
    } else if (shanghai) {
      if (isLastScheduledVisit) {
        _gameOver = true;
        _winnerId = currentPlayerState.player.id;
        return;
      }
      _pendingShanghaiIdx = _currentPlayerIndex;
    }

    if (_variant == ShanghaiVariant.sequential &&
        currentPlayerState.finishedAtDart != null) {
      _pendingShanghaiIdx = null;
      _gameOver = true;
      _winnerId = currentPlayerState.player.id;
      return;
    }

    if (isLastScheduledVisit) {
      _gameOver = true;
      _winnerId = _playerStates[_scoreWinnerIndex()].player.id;
      return;
    }

    _advanceTurn();
  }
}
