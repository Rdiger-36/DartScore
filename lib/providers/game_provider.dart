import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/player.dart';
import '../models/game.dart';
import '../models/dart_throw.dart';
import '../widgets/dartboard_input.dart' show DartEntry;

/// Minimum darts to finish a game from a given start score (double-out).
const Map<int, int> minimumDartsForScore = {
  101: 2, 170: 3, 201: 4, 301: 6, 501: 9, 701: 12, 1001: 17,
};

// ── PlayerState ───────────────────────────────────────────────────────────────

class PlayerState {
  /// Human-readable name for the scoreboard: team name or player name.
  final String displayName;
  /// All players in this slot — 1 for individual, N for team.
  final List<Player> players;
  /// Which player in [players] throws NEXT (rotates after each team visit).
  final int currentPlayerIdx;

  final int legsWon;
  final int setsWon;
  final int remaining;
  final List<DartThrow> throws;
  final int perfectLegs;

  final bool isTeamSlot;

  const PlayerState({
    required this.displayName,
    required this.players,
    this.currentPlayerIdx = 0,
    required this.legsWon,
    required this.setsWon,
    required this.remaining,
    required this.throws,
    this.perfectLegs = 0,
    this.isTeamSlot = false,
  });

  /// The player who throws next (backward-compatible accessor).
  Player get player => players[currentPlayerIdx];
  bool get isTeam   => players.length > 1;

  int get totalDarts  => throws.fold(0, (s, t) => s + t.dartsUsed);
  int get totalVisits => throws.length;

  double get average {
    if (totalDarts == 0) return 0;
    final scored = throws.fold(0, (s, t) => s + (t.bust ? 0 : t.score));
    return (scored / totalDarts) * 3;
  }

  PlayerState copyWith({
    int?              currentPlayerIdx,
    int?              legsWon,
    int?              setsWon,
    int?              remaining,
    List<DartThrow>?  throws,
    int?              perfectLegs,
  }) =>
      PlayerState(
        displayName:      displayName,
        players:          players,
        currentPlayerIdx: currentPlayerIdx ?? this.currentPlayerIdx,
        legsWon:          legsWon          ?? this.legsWon,
        setsWon:          setsWon          ?? this.setsWon,
        remaining:        remaining        ?? this.remaining,
        throws:           throws           ?? this.throws,
        perfectLegs:      perfectLegs      ?? this.perfectLegs,
        isTeamSlot:       isTeamSlot,
      );
}

// ── GameProvider ──────────────────────────────────────────────────────────────

class GameProvider extends ChangeNotifier {
  final DbHelper _db = DbHelper.instance;

  Game?              _game;
  List<PlayerState>  _playerStates = [];
  int                _currentPlayerIndex = 0;
  int                _currentLeg = 1;
  int                _currentSet = 1;
  bool               _gameOver = false;
  int?               _winnerId;
  Map<int, PlayerHandicap> _handicaps = {};

  final List<DartThrow> _undoStack = [];
  final List<DartThrow> _redoStack = [];

  Game?              get game               => _game;
  List<PlayerState>  get playerStates       => _playerStates;
  int                get currentPlayerIndex => _currentPlayerIndex;
  PlayerState        get currentPlayerState => _playerStates[_currentPlayerIndex];
  int                get currentLeg         => _currentLeg;
  int                get currentSet         => _currentSet;
  bool               get gameOver           => _gameOver;
  int?               get winnerId           => _winnerId;
  bool               get canUndo            => _undoStack.isNotEmpty;
  bool               get canRedo            => _redoStack.isNotEmpty;

  PlayerHandicap? get currentPlayerHandicap {
    if (_playerStates.isEmpty) return null;
    final pid = _playerStates[_currentPlayerIndex].player.id;
    return pid != null ? _handicaps[pid] : null;
  }

  Map<int, PlayerHandicap> get handicaps => Map.unmodifiable(_handicaps);

  // ── Resume ────────────────────────────────────────────────────────────────

  Future<void> resumeGame(Game game, List<Player> players) async {
    final allThrowsRaw = await _db.getThrowsForGame(game.id!);

    final throwsByPlayer = <int, List<DartThrow>>{};
    for (final t in allThrowsRaw) {
      throwsByPlayer.putIfAbsent(t.playerId, () => []).add(t);
    }

    int maxLeg = 1, maxSet = 1;
    for (final t in allThrowsRaw) {
      if (t.set > maxSet) maxSet = t.set;
      if (t.leg > maxLeg) maxLeg = t.leg;
    }

    if (game.isTeamGame) {
      await _resumeTeamGame(game, players, throwsByPlayer, maxLeg, maxSet);
    } else {
      await _resumeIndividualGame(game, players, throwsByPlayer, maxLeg, maxSet);
    }

    _game     = game;
    _gameOver = false;
    _winnerId = null;
    notifyListeners();
  }

  Future<void> _resumeTeamGame(
    Game game,
    List<Player> players,
    Map<int, List<DartThrow>> throwsByPlayer,
    int maxLeg,
    int maxSet,
  ) async {
    final teams       = game.teams!;
    final legsToWin   = game.legs;

    // Compute legs/sets won per team
    final teamLegsWon = List<int>.filled(teams.length, 0);
    final teamSetsWon = List<int>.filled(teams.length, 0);
    final tempLegs    = List<int>.filled(teams.length, 0);

    for (var s = 1; s <= maxSet; s++) {
      for (var l = 1; l <= maxLeg; l++) {
        if (s == maxSet && l == maxLeg) continue;
        for (var ti = 0; ti < teams.length; ti++) {
          final winner = _teamCheckedOutLeg(teams[ti], throwsByPlayer, l, s);
          if (winner) {
            tempLegs[ti]++;
            if (tempLegs[ti] >= legsToWin) {
              teamSetsWon[ti]++;
              tempLegs[ti] = 0;
            }
          }
        }
      }
    }
    for (var ti = 0; ti < teams.length; ti++) {
      teamLegsWon[ti] = tempLegs[ti];
    }

    // Build team states
    final teamVisits = <int>[]; // visits per team in current leg
    _playerStates = teams.asMap().entries.map((entry) {
      final ti   = entry.key;
      final team = entry.value;
      final teamPlayers = team.playerIds
          .map((id) => players.firstWhere((p) => p.id == id))
          .toList();

      // All throws by team members
      final allTeamThrows = teamPlayers
          .expand((p) => throwsByPlayer[p.id!] ?? <DartThrow>[])
          .toList()
        ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt));

      final currentLegThrows = allTeamThrows
          .where((t) => t.leg == maxLeg && t.set == maxSet)
          .toList();

      int remaining = game.startScore;
      for (final t in currentLegThrows) {
        if (!t.bust) remaining -= t.score;
      }

      // How many team visits (individual player turns) happened this leg?
      final visits = currentLegThrows.length;
      teamVisits.add(visits);

      // Current player in rotation
      final currentIdx = visits % teamPlayers.length;

      return PlayerState(
        displayName:      team.name,
        players:          teamPlayers,
        currentPlayerIdx: currentIdx,
        legsWon:          teamLegsWon[ti],
        setsWon:          teamSetsWon[ti],
        remaining:        remaining,
        throws:           allTeamThrows,
        isTeamSlot:       true,
      );
    }).toList();

    // Which team goes next: the one with fewer visits
    final minVisits   = teamVisits.reduce((a, b) => a < b ? a : b);
    _currentPlayerIndex = teamVisits.indexWhere((v) => v == minVisits);
    if (_currentPlayerIndex < 0) _currentPlayerIndex = 0;

    _currentLeg = maxLeg;
    _currentSet = maxSet;
  }

  bool _teamCheckedOutLeg(
    TeamConfig team,
    Map<int, List<DartThrow>> throwsByPlayer,
    int leg,
    int set,
  ) {
    for (final id in team.playerIds) {
      final legThrows = throwsByPlayer[id]
              ?.where((t) => t.leg == leg && t.set == set)
              .toList() ??
          [];
      if (legThrows.isNotEmpty &&
          !legThrows.last.bust &&
          legThrows.last.remainingBefore - legThrows.last.score == 0) {
        return true;
      }
    }
    return false;
  }

  Future<void> _resumeIndividualGame(
    Game game,
    List<Player> players,
    Map<int, List<DartThrow>> throwsByPlayer,
    int maxLeg,
    int maxSet,
  ) async {
    final legsWon     = <int, int>{for (final p in players) p.id!: 0};
    final setsWon     = <int, int>{for (final p in players) p.id!: 0};
    final legsToWinSet = game.legs;

    for (var s = 1; s <= maxSet; s++) {
      for (var l = 1; l <= maxLeg; l++) {
        if (s == maxSet && l == maxLeg) continue;
        for (final p in players) {
          final legThrows = throwsByPlayer[p.id!]
                  ?.where((t) => t.leg == l && t.set == s)
                  .toList() ??
              [];
          if (legThrows.isNotEmpty &&
              !legThrows.last.bust &&
              legThrows.last.remainingBefore - legThrows.last.score == 0) {
            legsWon[p.id!] = (legsWon[p.id!] ?? 0) + 1;
            if ((legsWon[p.id!] ?? 0) >= legsToWinSet) {
              setsWon[p.id!] = (setsWon[p.id!] ?? 0) + 1;
              legsWon[p.id!] = 0;
            }
          }
        }
      }
    }

    _playerStates = players.map((p) {
      final currentLegThrows = throwsByPlayer[p.id!]
              ?.where((t) => t.leg == maxLeg && t.set == maxSet)
              .toList() ??
          [];
      int remaining = game.startScore;
      for (final t in currentLegThrows) {
        if (!t.bust) remaining -= t.score;
      }
      return PlayerState(
        displayName: p.name,
        players:     [p],
        legsWon:     legsWon[p.id!] ?? 0,
        setsWon:     setsWon[p.id!] ?? 0,
        remaining:   remaining,
        throws:      throwsByPlayer[p.id!] ?? [],
      );
    }).toList();

    final currentLegVisits = players
        .map((p) =>
            throwsByPlayer[p.id!]
                ?.where((t) => t.leg == maxLeg && t.set == maxSet)
                .length ??
            0)
        .toList();
    final minVisits         = currentLegVisits.reduce((a, b) => a < b ? a : b);
    _currentPlayerIndex     = currentLegVisits.indexWhere((v) => v == minVisits);
    if (_currentPlayerIndex < 0) _currentPlayerIndex = 0;

    _currentLeg = maxLeg;
    _currentSet = maxSet;
  }

  // ── Start ─────────────────────────────────────────────────────────────────

  Future<void> startGame(
    Game game,
    List<Player> players, {
    Map<int, PlayerHandicap>? handicaps,
  }) async {
    _handicaps = handicaps ?? {};

    final ids    = players.map((p) => p.id!).toList();
    final gameId = await _db.insertGame(game, ids);
    _game = Game(
      id:           gameId,
      startScore:   game.startScore,
      gameMode:     game.gameMode,
      checkoutMode: game.checkoutMode,
      legs:         game.legs,
      sets:         game.sets,
      createdAt:    game.createdAt,
      teams:        game.teams,
    );

    if (game.isTeamGame) {
      _playerStates = game.teams!.map((team) {
        final teamPlayers = team.playerIds
            .map((id) => players.firstWhere((p) => p.id == id))
            .toList();
        return PlayerState(
          displayName: team.name,
          players:     teamPlayers,
          legsWon:     0,
          setsWon:     0,
          remaining:   game.startScore,
          throws:      [],
          isTeamSlot:  true,
        );
      }).toList();
    } else {
      _playerStates = players
          .map((p) => PlayerState(
                displayName: p.name,
                players:     [p],
                legsWon:     0,
                setsWon:     0,
                remaining:   game.startScore,
                throws:      [],
              ))
          .toList();
    }

    _currentPlayerIndex = 0;
    _currentLeg         = 1;
    _currentSet         = 1;
    _gameOver           = false;
    _winnerId           = null;
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  // ── Submit score ──────────────────────────────────────────────────────────

  Future<void> submitScore(int score, int dartsUsed,
      {bool bust = false, List<DartEntry>? hits}) async {
    if (_game == null || _gameOver) return;
    final state     = _playerStates[_currentPlayerIndex];
    final remaining = state.remaining;
    final newRemaining = remaining - score;

    final checkout = !bust && newRemaining == 0;

    final hitsJson = hits != null && hits.isNotEmpty
        ? jsonEncode(hits.map((h) => {'f': h.field, 'm': h.modifier}).toList())
        : null;

    final t = DartThrow(
      gameId:          _game!.id!,
      playerId:        state.player.id!, // individual player — even in team mode
      score:           bust ? 0 : score,
      dartsUsed:       dartsUsed,
      leg:             _currentLeg,
      set:             _currentSet,
      remainingBefore: remaining,
      thrownAt:        DateTime.now(),
      bust:            bust,
      hitsJson:        hitsJson,
    );

    final id = await _db.insertThrow(t);
    final saved = DartThrow(
      id: id, gameId: t.gameId, playerId: t.playerId, score: t.score,
      dartsUsed: t.dartsUsed, leg: t.leg, set: t.set,
      remainingBefore: t.remainingBefore, thrownAt: t.thrownAt, bust: t.bust,
      hitsJson: t.hitsJson,
    );

    _playerStates[_currentPlayerIndex] = state.copyWith(
      remaining: bust ? remaining : newRemaining,
      throws: [...state.throws, saved],
    );

    _undoStack.add(saved);
    _redoStack.clear();

    if (checkout) {
      await _handleCheckout(dartsUsed);
    } else {
      _advancePlayer();
    }
    notifyListeners();
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  Future<void> _handleCheckout(int dartsUsed) async {
    final state = _playerStates[_currentPlayerIndex];
    int legsWon = state.legsWon + 1;
    int setsWon = state.setsWon;

    // Perfect leg
    final minDarts = minimumDartsForScore[_game!.startScore];
    final currentPlayer = state.player;
    final legDarts = state.throws
            .where((t) =>
                t.leg == _currentLeg &&
                t.set == _currentSet &&
                (state.isTeam ? true : t.playerId == currentPlayer.id))
            .fold(0, (s, t) => s + t.dartsUsed) +
        dartsUsed;
    final isPerfect  = minDarts != null && legDarts <= minDarts;
    final perfectLegs = state.perfectLegs + (isPerfect ? 1 : 0);

    // Solo game: no legs/sets — finish immediately on checkout
    if (_playerStates.length == 1) {
      _playerStates[_currentPlayerIndex] = state.copyWith(
          legsWon: 0, setsWon: 0, perfectLegs: perfectLegs);
      _gameOver = true;
      _winnerId = state.player.id;
      await _db.updateGame(_game!.copyWith(finishedAt: DateTime.now()));
      return;
    }

    final legsToWinSet = _game!.legs;
    if (legsWon >= legsToWinSet) {
      // Set won
      setsWon += 1;
      legsWon  = 0;

      final setsToWin = _game!.sets;
      if (setsWon >= setsToWin) {
        // Game over
        _playerStates[_currentPlayerIndex] = state.copyWith(
            legsWon: legsWon, setsWon: setsWon, perfectLegs: perfectLegs);
        _gameOver = true;
        _winnerId = state.isTeam ? state.players.first.id : state.player.id;
        await _db.updateGame(_game!.copyWith(finishedAt: DateTime.now()));
        return;
      }
      // New set — reset legs for all players
      _currentSet += 1;
      _currentLeg  = 1;
      _playerStates = _playerStates
          .map((s) => s.copyWith(legsWon: 0))
          .toList();
    } else {
      // Same set, next leg
      _currentLeg += 1;
    }

    _playerStates[_currentPlayerIndex] =
        state.copyWith(legsWon: legsWon, setsWon: setsWon, perfectLegs: perfectLegs);

    _resetScores();
    _advancePlayer();
  }

  void _resetScores() {
    _playerStates = _playerStates
        .map((s) => PlayerState(
              displayName:      s.displayName,
              players:          s.players,
              currentPlayerIdx: s.currentPlayerIdx,
              legsWon:          s.legsWon,
              setsWon:          s.setsWon,
              remaining:        _game!.startScore,
              throws:           s.throws,
              perfectLegs:      s.perfectLegs,
              isTeamSlot:       s.isTeamSlot,
            ))
        .toList();
  }

  /// Advance to the next team/player. In team mode, also rotate the player
  /// within the team that just threw.
  void _advancePlayer() {
    // Rotate player within current team BEFORE advancing to next slot
    if (_playerStates[_currentPlayerIndex].isTeam) {
      final s       = _playerStates[_currentPlayerIndex];
      final nextIdx = (s.currentPlayerIdx + 1) % s.players.length;
      _playerStates[_currentPlayerIndex] = s.copyWith(currentPlayerIdx: nextIdx);
    }
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  Future<void> undoLastThrow() async {
    if (_game == null || _undoStack.isEmpty) return;

    final lastThrow = _undoStack.removeLast();
    _redoStack.add(lastThrow);

    await _db.deleteThrow(lastThrow.id!);

    final players = _playerStates.expand((s) => s.players).toList();
    await resumeGame(_game!, players);
  }

  Future<void> redoLastThrow() async {
    if (_game == null || _redoStack.isEmpty) return;

    final t = _redoStack.removeLast();

    final id = await _db.insertThrow(DartThrow(
      gameId: t.gameId, playerId: t.playerId, score: t.score,
      dartsUsed: t.dartsUsed, leg: t.leg, set: t.set,
      remainingBefore: t.remainingBefore, thrownAt: t.thrownAt, bust: t.bust,
    ));
    final saved = DartThrow(
      id: id, gameId: t.gameId, playerId: t.playerId, score: t.score,
      dartsUsed: t.dartsUsed, leg: t.leg, set: t.set,
      remainingBefore: t.remainingBefore, thrownAt: t.thrownAt, bust: t.bust,
    );
    _undoStack.add(saved);

    final players = _playerStates.expand((s) => s.players).toList();
    await resumeGame(_game!, players);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<DartThrow> allThrows() {
    return _playerStates.expand((s) => s.throws).toList()
      ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt));
  }
}
