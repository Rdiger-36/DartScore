import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/shanghai_game.dart';
import '../models/player.dart';

// ── ShanghaiPlayerState ───────────────────────────────────────────────────────

/// Immutable Shanghai state for one scoreboard slot: their score plus, in the
/// sequential variant, the target they are working toward and when they
/// completed it.
///
/// A slot is either a single player or a whole team. For teams, [players]
/// holds every member and [currentPlayerIdx] tracks whose turn it is within
/// the team; score and (in the sequential variant) progress are shared by the
/// whole team, relay-style. [displayName] is the team or player name shown on
/// the scoreboard.
class ShanghaiPlayerState {
  final String displayName;
  /// All players in this slot — 1 for individual, N for team.
  final List<Player> players;
  /// Which player in [players] throws NEXT (rotates after each team visit).
  final int currentPlayerIdx;
  /// Whether this slot represents a team rather than a single player.
  final bool isTeamSlot;
  final int score;
  /// Sequential variant only: the number this slot is currently aiming for (1-20).
  final int progress;
  /// Sequential variant only: total darts thrown once the slot completed target 20.
  final int? finishedAtDart;

  const ShanghaiPlayerState({
    required this.displayName,
    required this.players,
    this.currentPlayerIdx = 0,
    this.isTeamSlot = false,
    required this.score,
    this.progress = 1,
    this.finishedAtDart,
  });

  /// The player who throws next (backward-compatible accessor).
  Player get player => players[currentPlayerIdx];

  /// Returns a copy with score/progress/finish/active player replaced;
  /// identity is preserved.
  ShanghaiPlayerState copyWith({
    int? score,
    int? progress,
    int? finishedAtDart,
    int? currentPlayerIdx,
  }) =>
      ShanghaiPlayerState(
        displayName: displayName,
        players: players,
        currentPlayerIdx: currentPlayerIdx ?? this.currentPlayerIdx,
        isTeamSlot: isTeamSlot,
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

/// Active-game state machine for Shanghai (classic, clockwise, sequential).
///
/// Records darts into a per-visit buffer, scores `multiplier x target`, and
/// detects both score-based wins and the instant-win "Shanghai" (single + double
/// + triple, or three consecutive targets). With two players a Shanghai can be
/// voided by the opponent matching it on the next visit, hence
/// [pendingShanghaiIdx]. Every dart is persisted; undo replays the rest.
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

  /// Index of the player awaiting Shanghai confirmation (cancelled if the
  /// next player also throws a Shanghai), or null if none is pending.
  int? get pendingShanghaiIdx => _pendingShanghaiIdx;

  /// The active game's rule variant.
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

  /// The highest target number reached in the active variant.
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

  /// Maximum darts in a single visit (7 for clockwise, otherwise 3).
  int get visitDartLimit => _variant == ShanghaiVariant.clockwise ? _clockwiseMaxTarget : 3;

  // ── Shanghai hint ──────────────────────────────────────────────────────────

  /// Classic only: multipliers (1=Single, 2=Double, 3=Triple) still missing
  /// on the active target to complete a Shanghai this visit.
  /// Null if a Shanghai is no longer reachable in the current visit.
  List<int>? get shanghaiNeededMultipliers {
    if (_game == null || _variant != ShanghaiVariant.classic) return null;

    final target = activeTarget;
    final hit = <int>[];
    for (final d in _visitBuffer) {
      if (d.isMiss || d.target != target || hit.contains(d.multiplier)) return null;
      hit.add(d.multiplier);
    }
    return [1, 2, 3].where((m) => !hit.contains(m)).toList();
  }

  /// Clockwise/Sequential only: consecutive hits on consecutive targets still
  /// needed to complete a Shanghai from the current visit state.
  /// Null if a Shanghai is no longer reachable in the current visit.
  int? get shanghaiStreakNeeded {
    if (_game == null ||
        (_variant != ShanghaiVariant.clockwise && _variant != ShanghaiVariant.sequential)) {
      return null;
    }

    var streak = 0;
    for (var i = _visitBuffer.length - 1; i >= 0; i--) {
      final d = _visitBuffer[i];
      if (d.isMiss) break;
      if (streak == 0 || _visitBuffer[i + 1].target == d.target + 1) {
        streak++;
      } else {
        break;
      }
    }
    if (streak >= 3) return 0;

    final needed = 3 - streak;
    final remaining = visitDartLimit - _visitBuffer.length;
    return needed <= remaining ? needed : null;
  }

  // ── Slot construction ────────────────────────────────────────────────────

  /// Builds one scoreboard slot per team (if [teams] is set) or one slot per
  /// player (individual game), each with zero score and fresh progress.
  List<ShanghaiPlayerState> _buildSlots(List<Player> players, List<TeamConfig>? teams) {
    if (teams != null && teams.isNotEmpty) {
      return teams.map((team) {
        final teamPlayers = team.playerIds
            .map((id) => players.firstWhere((p) => p.id == id))
            .toList();
        return ShanghaiPlayerState(
          displayName: team.name,
          players:     teamPlayers,
          isTeamSlot:  true,
          score:       0,
        );
      }).toList();
    }
    return players.map((p) => ShanghaiPlayerState(
      displayName: p.name,
      players:     [p],
      score:       0,
    )).toList();
  }

  // ── Resume / Start ─────────────────────────────────────────────────────────

  /// Restores an in-progress Shanghai game and rebuilds scores/turn state by
  /// replaying all stored darts.
  Future<void> resumeGame(ShanghaiGame game, List<Player> players) async {
    _game = game;
    _playerStates = _buildSlots(players, game.teams);
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

  /// Starts a new Shanghai game: persists it, builds fresh zeroed player states,
  /// and resets the visit buffer and history.
  Future<void> startGame(ShanghaiGame game, List<Player> players) async {
    final gameId = await _db.insertShanghaiGame(game);
    _game = ShanghaiGame(
      id: gameId,
      variant: game.variant,
      legs: game.legs,
      sets: game.sets,
      createdAt: game.createdAt,
      playerIds: game.playerIds,
      teams: game.teams,
    );

    _playerStates = _buildSlots(players, game.teams);
    _currentPlayerIndex = 0;
    _currentRound = 1;
    _gameOver = false;
    _winnerId = null;
    _pendingShanghaiIdx = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    notifyListeners();
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

  /// Applies one scoring dart to [playerIdx]: adds its points and, in the
  /// sequential variant, advances progress and records the finishing dart when
  /// the final target is completed.
  void _applyDart(int playerIdx, ShanghaiThrow t) {
    final state = _playerStates[playerIdx];
    final points = t.multiplier * t.target;
    var updated = state.copyWith(score: state.score + points);

    if (_variant == ShanghaiVariant.sequential && t.target == updated.progress) {
      final nextProgress = updated.progress + 1;
      updated = updated.copyWith(progress: nextProgress);
      if (updated.progress > _sequentialMaxTarget) {
        final slotPlayerIds = state.players.map((p) => p.id).toSet();
        final dartsThrown = _throwHistory.where((h) => slotPlayerIds.contains(h.playerId)).length;
        updated = updated.copyWith(finishedAtDart: dartsThrown);
      }
    }

    _playerStates[playerIdx] = updated;
  }

  // ── Visit completion ───────────────────────────────────────────────────────

  /// Ends the visit if it is complete; otherwise does nothing.
  Future<void> _maybeEndVisit() async {
    final visitComplete = _isVisitComplete();
    if (!visitComplete) return;
    await _endVisit();
  }

  /// Whether the current visit is over (dart limit reached, or the sequential
  /// player has completed the final target).
  bool _isVisitComplete() {
    if (_visitBuffer.length >= visitDartLimit) return true;
    if (_variant == ShanghaiVariant.sequential &&
        currentPlayerState.progress > _sequentialMaxTarget) {
      return true;
    }
    return false;
  }

  /// Resolves the completed visit: handles instant Shanghai wins (with the
  /// two-player void/confirm rule), sequential outright wins, and end-of-game
  /// score decisions, then advances the turn.
  Future<void> _endVisit() async {
    final visitDarts = List<ShanghaiThrow>.of(_visitBuffer);
    _visitBuffer.clear();

    final shanghai = _isShanghai(visitDarts, _currentPlayerIndex);
    // True if no further visit will follow (classic/clockwise reach their
    // scheduled end on this very visit) — there is no "next player" left
    // who could cancel a Shanghai, so it must be confirmed immediately.
    final isLastScheduledVisit = _isGameComplete();

    if (_playerStates.length >= 3) {
      // 3+ players: Shanghai is an instant win — no response round.
      if (shanghai) {
        await _handleWin(_currentPlayerIndex);
        return;
      }
    } else {
      // 2 players: the opponent gets one visit to also throw a Shanghai and
      // void the first; if they don't, the original Shanghai thrower wins.
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
    }

    // Sequential: first to complete target 20 wins outright (no pending check).
    if (_variant == ShanghaiVariant.sequential &&
        currentPlayerState.finishedAtDart != null) {
      _pendingShanghaiIdx = null;
      await _handleWin(_currentPlayerIndex);
      return;
    }

    if (isLastScheduledVisit) {
      final winnerIdx = _scoreWinnerIndex();
      if (winnerIdx != null) {
        await _handleWin(winnerIdx);
        return;
      }
      // Tied: sudden death - play continues until someone takes the lead.
    }

    _advanceTurn();
    notifyListeners();
  }

  /// Whether [visitDarts] form a Shanghai: same target hit as single+double+
  /// triple (classic) or three consecutive targets hit (clockwise/sequential).
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

  /// Whether the final scheduled visit of the game has just been played (after
  /// which the winner is decided by score). Sequential never ends this way.
  bool _isGameComplete() {
    switch (_variant) {
      case ShanghaiVariant.classic:
        // `>=` so a tied game keeps re-checking each extra sudden-death round.
        return _currentRound >= _classicMaxRound &&
            _currentPlayerIndex == _playerStates.length - 1;
      case ShanghaiVariant.clockwise:
        return _currentPlayerIndex == _playerStates.length - 1;
      case ShanghaiVariant.sequential:
        return false; // ends only via outright win (handled in _endVisit)
    }
  }

  /// Advances to the next slot, incrementing the round after the last slot in
  /// the classic variant. In team mode, also rotates the player within the
  /// slot that just threw, so its next visit is taken by the next member.
  void _advanceTurn() {
    final isLastPlayer = _currentPlayerIndex == _playerStates.length - 1;

    final s = _playerStates[_currentPlayerIndex];
    if (s.isTeamSlot) {
      final nextIdx = (s.currentPlayerIdx + 1) % s.players.length;
      _playerStates[_currentPlayerIndex] = s.copyWith(currentPlayerIdx: nextIdx);
    }

    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;

    if (_variant == ShanghaiVariant.classic && isLastPlayer) {
      _currentRound++;
    }
  }

  /// Index of the player with the strictly highest score, or null if the
  /// top score is shared (draw).
  int? _scoreWinnerIndex() {
    final topScore = _playerStates.map((s) => s.score).reduce((a, b) => a > b ? a : b);
    final leaders = _playerStates.indexed.where((e) => e.$2.score == topScore).toList();
    return leaders.length == 1 ? leaders.first.$1 : null;
  }

  /// Marks the game over with [playerIdx] as the winner and persists the finish time.
  Future<void> _handleWin(int playerIdx) async {
    _gameOver = true;
    _winnerId = _playerStates[playerIdx].player.id;
    await _db.updateShanghaiGame(_game!.copyWith(finishedAt: DateTime.now()));
    notifyListeners();
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

  /// Undoes the last dart: deletes it from the database and replays the
  /// remaining darts to rebuild scores and turn state.
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

  /// Rebuilds the full game state from the persisted darts: zeroes scores and
  /// turn counters, then replays every dart, ending visits via [_replayEndVisit].
  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getShanghaiThrowsForGame(_game!.id!);

    _playerStates = _playerStates
        .map((s) => ShanghaiPlayerState(
              displayName: s.displayName,
              players:     s.players,
              isTeamSlot:  s.isTeamSlot,
              score:       0,
            ))
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

    if (_playerStates.length >= 3) {
      if (shanghai) {
        _gameOver = true;
        _winnerId = currentPlayerState.player.id;
        return;
      }
    } else {
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
    }

    if (_variant == ShanghaiVariant.sequential &&
        currentPlayerState.finishedAtDart != null) {
      _pendingShanghaiIdx = null;
      _gameOver = true;
      _winnerId = currentPlayerState.player.id;
      return;
    }

    if (isLastScheduledVisit) {
      final winnerIdx = _scoreWinnerIndex();
      if (winnerIdx != null) {
        _gameOver = true;
        _winnerId = _playerStates[winnerIdx].player.id;
        return;
      }
      // Tied: sudden death - play continues until someone takes the lead.
    }

    _advanceTurn();
  }
}
