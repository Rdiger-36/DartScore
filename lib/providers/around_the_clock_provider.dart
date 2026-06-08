import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/around_the_clock_game.dart';
import '../models/player.dart';

// ── AroundTheClockPlayerState ─────────────────────────────────────────────────

class AroundTheClockPlayerState {
  final String displayName;
  final Player player;
  /// Index into [aroundTheClockOrder] of the number this player must hit next.
  final int progress;
  /// Full-segment variant only: multipliers (1/2/3) already hit on the current target.
  final Set<int> hitSegments;
  /// Total darts thrown once the player completed the Bull's Eye.
  final int? finishedAtDart;

  const AroundTheClockPlayerState({
    required this.displayName,
    required this.player,
    this.progress = 0,
    this.hitSegments = const {},
    this.finishedAtDart,
  });

  int get currentTarget => aroundTheClockOrder[progress.clamp(0, aroundTheClockOrder.length - 1)];
  bool get isFinished => finishedAtDart != null;

  AroundTheClockPlayerState copyWith({
    int? progress,
    Set<int>? hitSegments,
    int? finishedAtDart,
  }) =>
      AroundTheClockPlayerState(
        displayName: displayName,
        player: player,
        progress: progress ?? this.progress,
        hitSegments: hitSegments ?? this.hitSegments,
        finishedAtDart: finishedAtDart ?? this.finishedAtDart,
      );
}

// ── AroundTheClockProvider ────────────────────────────────────────────────────

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

  // ── Resume / Start ─────────────────────────────────────────────────────────

  Future<void> resumeGame(AroundTheClockGame game, List<Player> players) async {
    _game = game;
    _resetPlayerStates(players);
    _currentPlayerIndex = 0;
    _gameOver = false;
    _winnerId = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    await _replayState();
    notifyListeners();
  }

  Future<void> startGame(AroundTheClockGame game, List<Player> players) async {
    final gameId = await _db.insertAroundTheClockGame(game);
    _game = AroundTheClockGame(
      id:        gameId,
      variant:   game.variant,
      legs:      game.legs,
      sets:      game.sets,
      createdAt: game.createdAt,
      playerIds: game.playerIds,
    );

    _resetPlayerStates(players);
    _currentPlayerIndex = 0;
    _gameOver = false;
    _winnerId = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    notifyListeners();
  }

  void _resetPlayerStates(List<Player> players) {
    _playerStates = players
        .map((p) => AroundTheClockPlayerState(displayName: p.name, player: p))
        .toList();
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
      final dartsThrown = _throwHistory.where((h) => h.playerId == state.player.id).length;
      updated = updated.copyWith(finishedAtDart: dartsThrown);
    }

    _playerStates[playerIdx] = updated;
  }

  // ── End of visit ──────────────────────────────────────────────────────────

  Future<void> _endVisit() async {
    _visitBuffer.clear();
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
    notifyListeners();
  }

  Future<void> _handleWin(int playerIdx) async {
    _gameOver = true;
    _winnerId = _playerStates[playerIdx].player.id;
    await _db.updateAroundTheClockGame(_game!.copyWith(finishedAt: DateTime.now()));
    notifyListeners();
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

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
      );
      await _db.updateAroundTheClockGame(_game!);
    }

    await _replayState();
    notifyListeners();
  }

  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getAroundTheClockThrowsForGame(_game!.id!);

    _playerStates = _playerStates
        .map((s) => AroundTheClockPlayerState(displayName: s.displayName, player: s.player))
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
        _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
      }
    }
  }
}
