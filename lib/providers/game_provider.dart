import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/player.dart';
import '../models/game.dart';
import '../models/dart_throw.dart';
import '../utils/placement.dart';
import '../widgets/dartboard_input.dart' show DartEntry;

/// Minimum darts to finish a game from a given start score (double-out).
const Map<int, int> minimumDartsForScore = {
  101: 2, 170: 3, 201: 4, 301: 6, 501: 9, 701: 12, 1001: 17,
};

/// Decodes a [DartThrow.hitsJson] string back into individual dart entries,
/// or null if no per-dart hits were recorded for that visit.
List<DartEntry>? _parseHits(String? hitsJson) {
  if (hitsJson == null) return null;
  final list = jsonDecode(hitsJson) as List;
  return list.map((e) {
    final m = e as Map<String, dynamic>;
    final field = m['f'] as int;
    final modifier = m['m'] as int;
    final score = field == 0
        ? 0
        : (field == 25 ? (modifier == 2 ? 50 : 25) : field * modifier);
    return DartEntry(field: field, modifier: modifier, score: score);
  }).toList();
}

/// A unit of redo state for [GameProvider.redoLastDart]: either a single dart
/// to re-add to the in-progress visit, or - for legacy throws recorded before
/// per-dart [DartThrow.hitsJson] was captured - a whole visit to re-insert verbatim.
class _RedoEntry {
  final DartEntry? dart;
  final DartThrow? legacyVisit;

  const _RedoEntry.dart(DartEntry entry) : dart = entry, legacyVisit = null;
  const _RedoEntry.legacyVisit(DartThrow visit) : dart = null, legacyVisit = visit;
}

// ── PlayerState ───────────────────────────────────────────────────────────────

/// Immutable scoreboard state for one slot in an X01 game.
///
/// A slot is either a single player or a whole team. For teams, [players] holds
/// every member and [currentPlayerIdx] tracks whose turn it is within the team;
/// [displayName] is the team or player name shown on the scoreboard.
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

  /// In placement-mode games: this slot's 1-based finishing position for the
  /// current leg, or null if it hasn't checked out yet this leg.
  final int? legPlacement;
  /// In placement-mode games: cumulative sum of [legPlacement] across all
  /// completed legs, used as a tie-breaker for the final ranking.
  final int placementSum;

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
    this.legPlacement,
    this.placementSum = 0,
  });

  /// The player who throws next (backward-compatible accessor).
  Player get player => players[currentPlayerIdx];

  /// Whether this slot represents a team rather than a single player.
  bool get isTeam   => players.length > 1;

  /// Total number of darts thrown by this slot across the game.
  int get totalDarts  => throws.fold(0, (s, t) => s + t.dartsUsed);

  /// Total number of visits (turns) taken by this slot.
  int get totalVisits => throws.length;

  /// Three-dart average for this slot; busts count as zero scored.
  double get average {
    if (totalDarts == 0) return 0;
    final scored = throws.fold(0, (s, t) => s + (t.bust ? 0 : t.score));
    return (scored / totalDarts) * 3;
  }

  /// Returns a copy with the given mutable fields replaced; identity fields
  /// ([displayName], [players], [isTeamSlot]) are preserved.
  /// Returns a copy with the given mutable fields replaced. [legPlacement] is
  /// only overridden when [resetLegPlacement] is true (so a normal copyWith
  /// call doesn't accidentally clear it), in which case [legPlacement] itself
  /// supplies the new value (including null).
  PlayerState copyWith({
    int?              currentPlayerIdx,
    int?              legsWon,
    int?              setsWon,
    int?              remaining,
    List<DartThrow>?  throws,
    int?              perfectLegs,
    int?              legPlacement,
    bool              resetLegPlacement = false,
    int?              placementSum,
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
        legPlacement:     resetLegPlacement ? legPlacement : (legPlacement ?? this.legPlacement),
        placementSum:     placementSum     ?? this.placementSum,
      );
}

// ── GameProvider ──────────────────────────────────────────────────────────────

/// Active-game state machine for X01 games (individual and team).
///
/// Owns the per-slot [PlayerState]s, the current leg/set/turn, win detection,
/// and undo/redo. Every throw is persisted immediately via [DbHelper]; resuming
/// rebuilds the full state by replaying stored throws, which is also how undo
/// and redo recompute the board.
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

  /// Darts entered so far for the current player's in-progress (not yet
  /// committed) visit, in throw order. Cleared whenever the visit is
  /// committed or the turn moves on.
  List<DartEntry> _currentVisitDarts = [];

  /// Tracks if a check-in double/triple was hit within [_currentVisitDarts].
  bool _checkedInThisVisit = false;

  /// Darts (or, for legacy throws without per-dart hits, whole visits)
  /// removed by [undoLastDart], in undo order, restorable via [redoLastDart].
  final List<_RedoEntry> _redoStack = [];

  Game?              get game               => _game;
  List<PlayerState>  get playerStates       => _playerStates;
  int                get currentPlayerIndex => _currentPlayerIndex;
  PlayerState        get currentPlayerState => _playerStates[_currentPlayerIndex];
  int                get currentLeg         => _currentLeg;
  int                get currentSet         => _currentSet;
  bool               get gameOver           => _gameOver;
  int?               get winnerId           => _winnerId;

  /// Darts entered so far for the current player's in-progress visit.
  List<DartEntry>    get currentVisitDarts  => List.unmodifiable(_currentVisitDarts);

  /// Number of darts entered so far in the current in-progress visit.
  int                get dartsInVisit       => _currentVisitDarts.length;

  /// Whether a qualifying check-in dart was thrown this visit (live).
  bool               get checkedInThisVisit => _checkedInThisVisit;

  /// Whether there is any dart left to undo: either in the in-progress visit
  /// or in a previously recorded visit (possibly a previous player's turn).
  bool               get canUndoDart        => _currentVisitDarts.isNotEmpty || allThrows().isNotEmpty;

  /// Whether a previously undone dart (or legacy visit) can be restored.
  bool               get canRedoDart        => _redoStack.isNotEmpty;

  /// Whether check-in rules apply: only in the very first leg of the game.
  bool get _checkInActive => _currentLeg == 1 && _currentSet == 1;

  /// Check-in rule for the player about to throw (handicap overrides game default).
  GameMode get currentGameMode {
    if (!_checkInActive) return GameMode.straightIn;
    final pid = currentPlayerState.player.id;
    return _handicaps[pid]?.checkIn ?? _game!.gameMode;
  }

  /// Checkout rule for the player about to throw (handicap overrides game default).
  CheckoutMode get currentCheckoutMode {
    final pid = currentPlayerState.player.id;
    return _handicaps[pid]?.checkOut ?? _game!.checkoutMode;
  }

  /// Whether the player about to throw already checked in earlier this leg
  /// (i.e. before the in-progress visit).
  bool get currentHasCheckedIn =>
      currentGameMode == GameMode.straightIn ||
      currentPlayerState.remaining < _game!.startScore;

  /// Sum of dart scores entered so far in the in-progress visit.
  int get _visitScoreSoFar => _currentVisitDarts.fold(0, (s, d) => s + d.score);

  /// Remaining score if the in-progress visit ended right now.
  int get liveRunningRemaining => currentPlayerState.remaining - _visitScoreSoFar;

  /// Whether the in-progress visit would currently bust (negative remaining,
  /// or stuck on 1 with double/master-out while checked in).
  bool get liveBust {
    final running = liveRunningRemaining;
    final stuck = running == 1 &&
        currentCheckoutMode != CheckoutMode.straightOut &&
        (currentHasCheckedIn || _checkedInThisVisit);
    return running < 0 || stuck;
  }

  /// Remaining score to display for the current player: the live running
  /// remaining, or the pre-visit remaining if the in-progress visit busts.
  int get liveDisplayRemaining =>
      liveBust ? currentPlayerState.remaining : liveRunningRemaining;

  /// Per-player check-in/check-out handicap for the player about to throw, if any.
  PlayerHandicap? get currentPlayerHandicap {
    if (_playerStates.isEmpty) return null;
    final pid = _playerStates[_currentPlayerIndex].player.id;
    return pid != null ? _handicaps[pid] : null;
  }

  /// Read-only view of all per-player handicaps keyed by player id.
  Map<int, PlayerHandicap> get handicaps => Map.unmodifiable(_handicaps);

  // ── Resume ────────────────────────────────────────────────────────────────

  /// Restores a previously started game from the database by replaying all
  /// stored throws, rebuilding per-slot state and the current leg/set/turn.
  Future<void> resumeGame(Game game, List<Player> players) async {
    // In-progress visit and undo/redo state is only valid for the GameScreen
    // that produced it; drop it on every full rebuild of the board. Callers
    // that need to preserve it across a rebuild (undo/redo) restore it
    // afterwards.
    _currentVisitDarts = [];
    _checkedInThisVisit = false;
    _redoStack.clear();

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

  /// Rebuilds team-game state: tallies legs/sets won per team across completed
  /// legs, reconstructs each team's remaining score and player rotation for the
  /// current leg, and picks the team that throws next (fewest visits).
  Future<void> _resumeTeamGame(
    Game game,
    List<Player> players,
    Map<int, List<DartThrow>> throwsByPlayer,
    int maxLeg,
    int maxSet,
  ) async {
    if (game.placementMode) {
      _resumeTeamPlacementGame(game, players, throwsByPlayer, maxLeg);
      return;
    }

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

  /// Rebuilds team placement-mode state: every leg is played to the end by all
  /// teams, so [legsWon]/[PlayerState.placementSum] and [PlayerState.legPlacement]
  /// for the current leg come from [_placementResumeState] (keyed by team index).
  void _resumeTeamPlacementGame(
    Game game,
    List<Player> players,
    Map<int, List<DartThrow>> throwsByPlayer,
    int maxLeg,
  ) {
    final teams = game.teams!;

    final throwsByTeam = <int, List<DartThrow>>{
      for (var ti = 0; ti < teams.length; ti++)
        ti: teams[ti]
            .playerIds
            .expand((id) => throwsByPlayer[id] ?? <DartThrow>[])
            .toList()
          ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt)),
    };

    final r = _placementResumeState(throwsByTeam, maxLeg);

    _playerStates = teams.asMap().entries.map((entry) {
      final ti   = entry.key;
      final team = entry.value;
      final teamPlayers = team.playerIds
          .map((id) => players.firstWhere((p) => p.id == id))
          .toList();

      final allTeamThrows  = throwsByTeam[ti]!;
      final currentLegThrows =
          allTeamThrows.where((t) => t.leg == maxLeg && t.set == 1).toList();
      final currentIdx = currentLegThrows.length % teamPlayers.length;

      final placement = r.legPlacement[ti];
      int remaining = game.startScore;
      if (!r.legComplete) {
        if (placement == null) {
          for (final t in currentLegThrows) {
            if (!t.bust) remaining -= t.score;
          }
        } else {
          remaining = 0;
        }
      }

      return PlayerState(
        displayName:      team.name,
        players:          teamPlayers,
        currentPlayerIdx: currentIdx,
        legsWon:          r.legsWon[ti] ?? 0,
        setsWon:          0,
        remaining:        remaining,
        throws:           allTeamThrows,
        isTeamSlot:       true,
        legPlacement:     placement,
        placementSum:     r.placementSum[ti] ?? 0,
      );
    }).toList();

    if (r.legComplete) {
      _currentLeg = maxLeg + 1;
      _currentPlayerIndex = 0;
      _currentSet = 1;
    } else {
      _resumePickNextSlot(maxLeg);
    }
  }

  /// Whether any member of [team] checked out (reached exactly zero) in the
  /// given [leg] and [set].
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

  /// Rebuilds individual-game state: tallies legs/sets won per player across
  /// completed legs, reconstructs each player's remaining score for the current
  /// leg, and picks the player who throws next (fewest visits).
  Future<void> _resumeIndividualGame(
    Game game,
    List<Player> players,
    Map<int, List<DartThrow>> throwsByPlayer,
    int maxLeg,
    int maxSet,
  ) async {
    if (game.placementMode) {
      _resumeIndividualPlacementGame(game, players, throwsByPlayer, maxLeg);
      return;
    }

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

  /// Computes the placement-mode ranking for a resume. [maxLeg] is treated as
  /// fully complete (and its results folded into [legsWon]/[placementSum])
  /// either when every id already has a checkout in [maxLeg], or when all but
  /// one do -- the last remaining id then automatically takes last place, per
  /// [_handlePlacementCheckout]'s "second-to-last checkout ends the leg" rule.
  /// [legPlacement] gives each id's finishing position in [maxLeg], or `null`
  /// if [maxLeg] is still in progress for that id.
  ({
    Map<int, int> legsWon,
    Map<int, int> placementSum,
    Map<int, int?> legPlacement,
    bool legComplete,
  }) _placementResumeState(
    Map<int, List<DartThrow>> throwsById,
    int maxLeg,
  ) {
    final ids = throwsById.keys.toList();
    final currentPlacements = legPlacements(throwsById, maxLeg, 1);

    final completePlacements = Map<int, int>.of(currentPlacements);
    if (currentPlacements.length == ids.length - 1) {
      final missingId =
          ids.firstWhere((id) => !currentPlacements.containsKey(id));
      completePlacements[missingId] = ids.length;
    }
    final legComplete = completePlacements.length == ids.length;

    final ranking = placementRanking(throwsById, maxLeg - 1, 1);
    final legsWon = Map<int, int>.of(ranking.legsWon);
    final placementSum = Map<int, int>.of(ranking.placementSum);

    final placementsForMaxLeg =
        legComplete ? completePlacements : currentPlacements;
    for (final entry in placementsForMaxLeg.entries) {
      placementSum[entry.key] = (placementSum[entry.key] ?? 0) + entry.value;
      if (entry.value == 1) legsWon[entry.key] = (legsWon[entry.key] ?? 0) + 1;
    }

    return (
      legsWon: legsWon,
      placementSum: placementSum,
      legPlacement: {
        for (final id in ids) id: legComplete ? null : currentPlacements[id],
      },
      legComplete: legComplete,
    );
  }

  /// Rebuilds individual placement-mode state: every leg is played to the end
  /// by all players, so [legsWon]/[PlayerState.placementSum] come from
  /// [_placementResumeState], and [PlayerState.legPlacement] for the current
  /// leg comes from the same.
  void _resumeIndividualPlacementGame(
    Game game,
    List<Player> players,
    Map<int, List<DartThrow>> throwsByPlayer,
    int maxLeg,
  ) {
    final throwsById = {
      for (final p in players) p.id!: throwsByPlayer[p.id!] ?? <DartThrow>[],
    };

    final r = _placementResumeState(throwsById, maxLeg);

    _playerStates = players.map((p) {
      final placement = r.legPlacement[p.id!];
      int remaining = game.startScore;
      if (!r.legComplete) {
        if (placement == null) {
          final currentLegThrows = (throwsById[p.id!] ?? [])
              .where((t) => t.leg == maxLeg && t.set == 1)
              .toList();
          for (final t in currentLegThrows) {
            if (!t.bust) remaining -= t.score;
          }
        } else {
          remaining = 0;
        }
      }

      return PlayerState(
        displayName:  p.name,
        players:      [p],
        legsWon:      r.legsWon[p.id!] ?? 0,
        setsWon:      0,
        remaining:    remaining,
        throws:       throwsByPlayer[p.id!] ?? [],
        legPlacement: placement,
        placementSum: r.placementSum[p.id!] ?? 0,
      );
    }).toList();

    if (r.legComplete) {
      _currentLeg = maxLeg + 1;
      _currentPlayerIndex = 0;
      _currentSet = 1;
    } else {
      _resumePickNextSlot(maxLeg);
    }
  }

  /// Picks the next slot to throw for a placement-mode resume, among the
  /// slots not yet finished with [maxLeg]: the one with the fewest visits.
  void _resumePickNextSlot(int maxLeg) {
    final candidates = [
      for (var i = 0; i < _playerStates.length; i++)
        if (_playerStates[i].legPlacement == null) i,
    ];
    final visits = candidates
        .map((i) => _playerStates[i].throws
            .where((t) => t.leg == maxLeg && t.set == 1)
            .length)
        .toList();
    final minVisits = visits.reduce((a, b) => a < b ? a : b);
    _currentPlayerIndex = candidates[visits.indexOf(minVisits)];
    _currentLeg = maxLeg;
    _currentSet = 1;
  }

  // ── Start ─────────────────────────────────────────────────────────────────

  /// Starts a brand-new game: persists it, builds fresh per-slot state for the
  /// players or teams, resets leg/set/turn counters, and clears undo/redo.
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
      placementMode: game.placementMode,
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
    _currentVisitDarts  = [];
    _checkedInThisVisit = false;
    _redoStack.clear();
    notifyListeners();
  }

  // ── Submit visit ──────────────────────────────────────────────────────────

  /// Records the current slot's visit: persists the throw (optionally with
  /// per-dart [hits]), updates the remaining score, and either handles a
  /// checkout or advances to the next slot. Busts keep the remaining score
  /// unchanged.
  Future<void> _submitVisit(int score, int dartsUsed,
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

    if (checkout) {
      await _handleCheckout(dartsUsed);
    } else {
      _advancePlayer();
    }
    notifyListeners();
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  /// Resolves a successful checkout: awards the leg, tracks perfect legs, and
  /// promotes to set/game win as needed. Scores reset and play advances to
  /// the next slot, including solo games, which simply continue to the next
  /// leg until [Game.legs] is reached.
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

    // Placement mode: award the leg, but keep playing until every slot has
    // checked out, producing a 1st/2nd/3rd/... finishing order for this leg.
    if (_game!.placementMode) {
      await _handlePlacementCheckout(perfectLegs);
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

  /// Resolves a checkout in a placement-mode game: records this slot's
  /// finishing position for the current leg, and awards a leg win
  /// ([PlayerState.legsWon]) only to whoever finishes 1st. If this was the
  /// second-to-last slot to check out, the one remaining slot automatically
  /// takes last place without having to finish its visit. Once every slot
  /// has a placement, either ends the game (if the 1st-place slot's
  /// [PlayerState.legsWon] reached [Game.legs]) or starts the next leg with
  /// everyone active again.
  Future<void> _handlePlacementCheckout(int perfectLegs) async {
    final state = _playerStates[_currentPlayerIndex];
    final placement =
        _playerStates.where((s) => s.legPlacement != null).length + 1;
    final legsWon = placement == 1 ? state.legsWon + 1 : state.legsWon;

    _playerStates[_currentPlayerIndex] = state.copyWith(
      legsWon:          legsWon,
      perfectLegs:      perfectLegs,
      legPlacement:     placement,
      resetLegPlacement: true,
      placementSum:     state.placementSum + placement,
    );

    // If only one slot is left without a placement, it automatically takes
    // last place -- the leg ends without that slot finishing its throws.
    final stillPlaying =
        _playerStates.where((s) => s.legPlacement == null).toList();
    if (stillPlaying.length == 1) {
      final lastIdx   = _playerStates.indexOf(stillPlaying.first);
      final lastState = _playerStates[lastIdx];
      final lastPlacement = placement + 1;
      _playerStates[lastIdx] = lastState.copyWith(
        legPlacement:      lastPlacement,
        resetLegPlacement: true,
        placementSum:      lastState.placementSum + lastPlacement,
      );
    }

    final legComplete =
        _playerStates.every((s) => s.legPlacement != null);
    if (!legComplete) {
      _advancePlayer();
      return;
    }

    final winner = _playerStates.firstWhere((s) => s.legPlacement == 1);
    if (winner.legsWon >= _game!.legs) {
      _gameOver = true;
      _winnerId = winner.isTeam ? winner.players.first.id : winner.player.id;
      await _db.updateGame(_game!.copyWith(finishedAt: DateTime.now()));
      return;
    }

    _currentLeg += 1;
    _resetScores();
    _advancePlayer();
  }

  /// Resets every slot's remaining score back to the start score for a new leg,
  /// preserving legs/sets won, throw history, and player rotation. In
  /// placement-mode games this also clears [PlayerState.legPlacement] so
  /// everyone is active again.
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
              legPlacement:     null,
              placementSum:     s.placementSum,
            ))
        .toList();
  }

  /// Advance to the next team/player. In team mode, also rotate the player
  /// within the team that just threw. In placement-mode games, slots that
  /// already checked out this leg ([PlayerState.legPlacement] set) are skipped.
  void _advancePlayer() {
    // Rotate player within current team BEFORE advancing to next slot
    if (_playerStates[_currentPlayerIndex].isTeam) {
      final s       = _playerStates[_currentPlayerIndex];
      final nextIdx = (s.currentPlayerIdx + 1) % s.players.length;
      _playerStates[_currentPlayerIndex] = s.copyWith(currentPlayerIdx: nextIdx);
    }
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;

    if (_game!.placementMode) {
      while (_playerStates[_currentPlayerIndex].legPlacement != null) {
        _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
      }
    }
  }

  // ── Dart input ────────────────────────────────────────────────────────────

  /// Re-evaluates [_checkedInThisVisit] from [_currentVisitDarts] under the
  /// current player's check-in rule, e.g. after a dart that triggered
  /// check-in was undone.
  void _recomputeCheckedInThisVisit() {
    final gameMode = currentGameMode;
    if (gameMode == GameMode.straightIn || currentHasCheckedIn) {
      _checkedInThisVisit = false;
      return;
    }
    _checkedInThisVisit = _currentVisitDarts.any((d) {
      if (d.field == 0) return false;
      final isDouble = d.modifier == 2;
      final isTriple = d.modifier == 3 && d.field != 25;
      return gameMode == GameMode.doubleIn
          ? isDouble
          : (isDouble || isTriple);
    });
  }

  /// Registers [field] (0=miss, 1-20, 25=bull)/[modifier] (1/2/3) as the next
  /// dart of the current player's in-progress visit: computes its score under
  /// the active check-in rule, detects a bust or completed checkout, and
  /// commits the visit once three darts are thrown or it ends early.
  Future<void> _addDart(int field, int modifier) async {
    int score;
    if (field == 0) {
      score = 0;
    } else if (field == 25) {
      score = modifier == 2 ? 50 : 25;
    } else {
      score = field * modifier;
    }

    final gameMode     = currentGameMode;
    final checkoutMode = currentCheckoutMode;
    final requiresCheckIn =
        gameMode == GameMode.doubleIn || gameMode == GameMode.masterIn;

    final isDouble = field != 0 && modifier == 2;
    final isTriple = field != 0 && modifier == 3 && field != 25;
    final qualifiesForCheckIn = gameMode == GameMode.doubleIn
        ? isDouble
        : (gameMode == GameMode.masterIn ? (isDouble || isTriple) : false);

    bool dartScores = true;
    if (requiresCheckIn && !(currentHasCheckedIn || _checkedInThisVisit)) {
      if (qualifiesForCheckIn) {
        _checkedInThisVisit = true;
      } else {
        dartScores = false;
        score = 0;
      }
    }
    final isCheckedIn = currentHasCheckedIn || _checkedInThisVisit;

    final entry =
        DartEntry(field: field, modifier: field == 0 ? 1 : modifier, score: score);
    _currentVisitDarts.add(entry);

    final newVisitTotal = _visitScoreSoFar;
    final newRemaining  = currentPlayerState.remaining - newVisitTotal;

    bool bust     = false;
    bool endVisit = false;

    if (!dartScores) {
      if (_currentVisitDarts.length == 3) endVisit = true;
    } else if (newRemaining < 0) {
      bust     = true;
      endVisit = true;
    } else if (newRemaining == 0) {
      bool valid = true;
      if (checkoutMode == CheckoutMode.doubleOut) {
        valid = modifier == 2;
      } else if (checkoutMode == CheckoutMode.masterOut) {
        valid = field == 25 ? modifier != 3 : (modifier == 2 || modifier == 3);
      }
      bust     = !valid;
      endVisit = true;
    } else if (newRemaining == 1 &&
        checkoutMode != CheckoutMode.straightOut &&
        isCheckedIn) {
      bust     = true;
      endVisit = true;
    } else if (_currentVisitDarts.length == 3) {
      endVisit = true;
    }

    if (endVisit) {
      final dartsUsed  = _currentVisitDarts.length;
      final finalScore = bust ? 0 : newVisitTotal;
      final hits       = List<DartEntry>.from(_currentVisitDarts);
      _currentVisitDarts  = [];
      _checkedInThisVisit = false;
      await _submitVisit(finalScore, dartsUsed, bust: bust, hits: hits);
    }
  }

  /// Handles a tap on [field] (0=miss, 1-20, 25=bull) with the given
  /// [modifier] (1=single, 2=double, 3=triple) for the current player's
  /// in-progress visit. Any new dart invalidates the redo stack.
  Future<void> tapField(int field, int modifier) async {
    if (_game == null || _gameOver || _currentVisitDarts.length >= 3) return;
    _redoStack.clear();
    await _addDart(field, modifier);
    notifyListeners();
  }

  /// Ends the current player's in-progress visit early, scoring the darts
  /// entered so far. No-op if no darts have been entered yet.
  Future<void> finishVisitEarly() async {
    if (_game == null || _gameOver || _currentVisitDarts.isEmpty) return;
    _redoStack.clear();
    final dartsUsed = _currentVisitDarts.length;
    final score     = _visitScoreSoFar;
    final hits      = List<DartEntry>.from(_currentVisitDarts);
    _currentVisitDarts  = [];
    _checkedInThisVisit = false;
    await _submitVisit(score, dartsUsed, bust: false, hits: hits);
    notifyListeners();
  }

  // ── Undo / Redo ───────────────────────────────────────────────────────────

  /// Undoes the last individual dart, even across visit and player boundaries.
  ///
  /// If the current player still has darts entered for their in-progress
  /// visit, the most recent one is simply removed. Otherwise, the most
  /// recently recorded visit is deleted from the database and the game state
  /// is rebuilt, which naturally returns the turn to whoever threw it (and
  /// reverts any leg/set it had completed). If that visit had more than one
  /// dart, the darts before the removed one become the new in-progress visit
  /// so the UI shows them pre-filled.
  Future<void> undoLastDart() async {
    if (_game == null) return;

    if (_currentVisitDarts.isNotEmpty) {
      _redoStack.add(_RedoEntry.dart(_currentVisitDarts.removeLast()));
      _recomputeCheckedInThisVisit();
      notifyListeners();
      return;
    }

    final all = allThrows();
    if (all.isEmpty) return;

    final wasGameOver = _gameOver;
    final lastVisit = all.last;
    final hits = _parseHits(lastVisit.hitsJson);

    await _db.deleteThrow(lastVisit.id!);

    final preservedRedo = List<_RedoEntry>.from(_redoStack);
    List<DartEntry> prefill;
    if (hits != null && hits.isNotEmpty) {
      preservedRedo.add(_RedoEntry.dart(hits.removeLast()));
      prefill = hits;
    } else {
      preservedRedo.add(_RedoEntry.legacyVisit(lastVisit));
      prefill = const [];
    }

    final players = _playerStates.expand((s) => s.players).toList();
    await resumeGame(_game!, players);

    // Undoing the winning dart un-finishes the game; resumeGame already reset
    // _gameOver/_winnerId in-memory, so persist that the game is open again.
    if (wasGameOver) {
      await _db.updateGame(_game!);
    }

    _currentVisitDarts = prefill;
    _redoStack
      ..clear()
      ..addAll(preservedRedo);
    _recomputeCheckedInThisVisit();
    notifyListeners();
  }

  /// Redoes the last undone dart: restores it to the in-progress visit
  /// (committing the visit again if that completes it), or - for a legacy
  /// whole-visit redo - re-inserts the previously removed visit verbatim.
  Future<void> redoLastDart() async {
    if (_game == null || _redoStack.isEmpty) return;

    final entry = _redoStack.removeLast();

    if (entry.dart != null) {
      await _addDart(entry.dart!.field, entry.dart!.modifier);
      notifyListeners();
      return;
    }

    final t = entry.legacyVisit!;
    await _db.insertThrow(DartThrow(
      gameId: t.gameId, playerId: t.playerId, score: t.score,
      dartsUsed: t.dartsUsed, leg: t.leg, set: t.set,
      remainingBefore: t.remainingBefore, thrownAt: t.thrownAt, bust: t.bust,
      hitsJson: t.hitsJson,
    ));

    final preservedRedo = List<_RedoEntry>.from(_redoStack);
    final players = _playerStates.expand((s) => s.players).toList();
    await resumeGame(_game!, players);

    _redoStack
      ..clear()
      ..addAll(preservedRedo);
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// All throws across every slot, sorted chronologically.
  List<DartThrow> allThrows() {
    return _playerStates.expand((s) => s.throws).toList()
      ..sort((a, b) => a.thrownAt.compareTo(b.thrownAt));
  }
}
