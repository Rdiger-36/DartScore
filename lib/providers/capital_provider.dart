import 'package:flutter/widgets.dart';

import '../database/db_helper.dart';
import '../models/capital_game.dart';
import '../models/player.dart';
import '../utils/bot_strategy_capital.dart';
import '../utils/capital_rules.dart';
import '../utils/dartboard_geometry.dart';
import '../utils/player_label.dart';
import 'bot_runner.dart';

/// One scoreboard slot in a Capital game: a player and the capital they hold.
///
/// Capital has no team slots, so [isTeamSlot] is always false and [players]
/// always holds exactly one player. The class still implements [LabelledSlot]
/// so the screens name a slot the same way they do in every other mode.
class CapitalPlayerState implements LabelledSlot {
  @override
  final String displayName;
  @override
  final List<Player> players;

  /// The running capital, which a met contract adds to and a failed one halves.
  final int total;

  /// Whether this slot met the contract in the round it last completed, or
  /// null before it has completed a contract round.
  final bool? lastRoundMet;

  /// The capital this slot held before its last completed visit, so the
  /// scoreboard can show the arithmetic that produced [total] rather than the
  /// bare result.
  final int totalBefore;

  /// The darts of the last completed visit, in the order they were thrown.
  final List<BoardHit> lastVisit;

  const CapitalPlayerState({
    required this.displayName,
    required this.players,
    this.total = 0,
    this.lastRoundMet,
    this.totalBefore = 0,
    this.lastVisit = const [],
  });

  @override
  bool get isTeamSlot => false;

  /// The one player in this slot.
  Player get player => players.first;

  /// Returns a copy with the given fields replaced.
  ///
  /// [lastRoundMet] is passed straight through rather than defaulted, because
  /// the capital round has no contract and has to be able to clear it.
  CapitalPlayerState copyWith({
    int? total,
    required bool? lastRoundMet,
    int? totalBefore,
    List<BoardHit>? lastVisit,
  }) =>
      CapitalPlayerState(
        displayName:  displayName,
        players:      players,
        total:        total ?? this.total,
        lastRoundMet: lastRoundMet,
        totalBefore:  totalBefore ?? this.totalBefore,
        lastVisit:    lastVisit ?? this.lastVisit,
      );
}

/// Capital: one round to build a capital, then fourteen contracts.
///
/// Every dart is persisted as it lands and nothing derived is stored: the
/// totals and whether each contract was met are rebuilt by replaying the darts
/// through [applyCapitalVisit], which is the one implementation of the scoring
/// rule. A visit ends on its third dart or the moment it makes exactly 57, and
/// both are read back off the darts, so no boundary is stored either.
class CapitalProvider extends ChangeNotifier
    with WidgetsBindingObserver, BotRunner {
  final DbHelper _db = DbHelper.instance;

  /// Darts in a full visit, when the player does not stop early.
  static const int dartsPerVisit = 3;

  CapitalGame? _game;
  List<CapitalPlayerState> _playerStates = [];
  int _currentPlayerIndex = 0;
  int _currentRound = 1;
  bool _gameOver = false;
  int? _winnerId;

  /// Darts thrown so far in the current visit.
  final List<CapitalThrow> _visitBuffer = [];

  /// All persisted throws for undo (newest last).
  final List<CapitalThrow> _throwHistory = [];

  CapitalGame? get game => _game;
  List<CapitalPlayerState> get playerStates => _playerStates;
  int get currentPlayerIndex => _currentPlayerIndex;
  CapitalPlayerState get currentPlayerState => _playerStates[_currentPlayerIndex];
  int get currentRound => _currentRound;
  bool get gameOver => _gameOver;
  int? get winnerId => _winnerId;
  List<CapitalThrow> get visitBuffer => List.unmodifiable(_visitBuffer);
  int get dartsInVisit => _visitBuffer.length;

  /// Every persisted dart of the game, oldest first.
  List<CapitalThrow> get throwHistory => List.unmodifiable(_throwHistory);

  /// The contract the current round proposes.
  CapitalContract get contract => CapitalContract.forRound(_currentRound);

  /// The slot that completed the most recent visit, or null before any has.
  ///
  /// The turn has already moved on by the time a visit settles, so this is the
  /// slot behind the one on turn. The scoreboard follows it, because the sum
  /// worth reading is the one that just changed.
  int? get lastSettledIndex {
    if (_playerStates.isEmpty) return null;
    final previous =
        (_currentPlayerIndex - 1 + _playerStates.length) % _playerStates.length;
    return _playerStates[previous].lastVisit.isEmpty ? null : previous;
  }

  /// The visit so far, as the board geometry and the contract rules read it.
  List<BoardHit> get visitHits =>
      _visitBuffer.map((dart) => dart.hit).toList();

  /// Whether the darts thrown so far already fulfil the contract.
  bool get contractMet => capitalContractMet(contract, visitHits);

  /// Whether another dart could only cost the thrower the contract.
  bool get shouldStopNow => furtherDartsCanOnlyHurt(contract, visitHits);

  /// Whether there is a dart to undo. Not while a bot is throwing, and not
  /// when every recorded dart is a bot's: those are never undone on their own.
  bool get canUndo =>
      !isBotTurn && _throwHistory.any((t) => !_isBotId(t.playerId));

  // ── Slot construction ──────────────────────────────────────────────────────

  /// One slot per player, each starting on no capital at all.
  List<CapitalPlayerState> _buildSlots(List<Player> players) => players
      .map((p) => CapitalPlayerState(displayName: p.name, players: [p]))
      .toList();

  // ── Resume / Start ─────────────────────────────────────────────────────────

  /// Restores an in-progress Capital game, rebuilding every total by replaying
  /// the stored darts.
  Future<void> resumeGame(CapitalGame game, List<Player> players) async {
    _game = game;
    _playerStates = _buildSlots(players);
    _currentPlayerIndex = 0;
    _currentRound = 0;
    _gameOver = false;
    _winnerId = null;
    dropHeldVisit();
    releaseBot();
    await _replayState();
    notifyListeners();
    scheduleBot();
  }

  /// Starts a fresh Capital game, persisting it first.
  Future<void> startGame(CapitalGame game, List<Player> players) async {
    final gameId = await _db.insertCapitalGame(game);
    _game = CapitalGame(
      id:            gameId,
      variant:       game.variant,
      legs:          game.legs,
      sets:          game.sets,
      createdAt:     game.createdAt,
      playerIds:     game.playerIds,
      startingOrder: game.startingOrder,
    );
    _playerStates = _buildSlots(players);
    _currentPlayerIndex = 0;
    _currentRound = 0;
    _gameOver = false;
    _winnerId = null;
    _visitBuffer.clear();
    _throwHistory.clear();
    dropHeldVisit();
    releaseBot();
    notifyListeners();
    scheduleBot();
  }

  // ── Bot ────────────────────────────────────────────────────────────────────

  @override
  bool get isBotTurn =>
      _game != null &&
      !_gameOver &&
      _playerStates.isNotEmpty &&
      currentPlayerState.player.isBot;

  /// Whether [playerId] belongs to one of the bots in this game.
  bool _isBotId(int playerId) => _playerStates
      .expand((s) => s.players)
      .any((p) => p.id == playerId && p.isBot);

  @override
  Future<void> throwBotDart() async {
    final aim = capitalTarget(contract: contract, dartsSoFar: visitHits);
    final hit = botThrower.throwAt(aim, currentPlayerState.player.botLevel!);
    await _recordDart(hit);
  }

  // ── Record a dart ──────────────────────────────────────────────────────────

  /// Records one dart for the person on turn. Refused while a bot is on turn
  /// or a finished visit is still shown.
  Future<void> recordDart(BoardHit hit) async {
    if (inputLocked) return;
    await _recordDart(hit);
    scheduleBot();
  }

  /// Records one dart for whoever is on turn, bot or person.
  Future<void> _recordDart(BoardHit hit) async {
    if (_game == null || _gameOver) return;
    if (_visitBuffer.length >= dartsPerVisit) return;

    final t = CapitalThrow(
      gameId:     _game!.id!,
      playerId:   currentPlayerState.player.id!,
      field:      hit.field,
      multiplier: hit.multiplier,
      round:      _currentRound,
      leg:        1,
      set_:       1,
      thrownAt:   DateTime.now(),
    );
    final id = await _db.insertCapitalThrow(t);
    final saved = CapitalThrow(
      id:         id,
      gameId:     t.gameId,
      playerId:   t.playerId,
      field:      t.field,
      multiplier: t.multiplier,
      round:      t.round,
      leg:        t.leg,
      set_:       t.set_,
      thrownAt:   t.thrownAt,
    );

    _visitBuffer.add(saved);
    _throwHistory.add(saved);

    await _maybeEndVisit();
    notifyListeners();
  }

  // ── Visit completion ───────────────────────────────────────────────────────

  /// Ends the visit if it is over, after its pause on the board.
  ///
  /// A visit ends on its third dart, or the moment it makes exactly 57 in the
  /// round that asks for it. Closing it there rather than offering the choice
  /// costs the thrower nothing: from an exact 57 every scoring dart breaks the
  /// total and a missing one changes nothing, so throwing on is a gamble with
  /// no prize. It also keeps the visit boundary something the replay can work
  /// out, rather than a decision that would have to be stored.
  Future<void> _maybeEndVisit() async {
    if (_visitBuffer.length < dartsPerVisit && !shouldStopNow) return;
    notifyListeners();
    await holdVisit(_endVisit);
  }

  /// Scores the completed visit onto the thrower's capital and moves on.
  Future<void> _endVisit() async {
    _settleVisit();
    _visitBuffer.clear();
    await _advanceTurn();
    notifyListeners();
  }

  /// Applies the visit to the slot that threw it, through the one scoring rule.
  void _settleVisit() {
    final hits = visitHits;
    final state = _playerStates[_currentPlayerIndex];
    final met = capitalContractMet(contract, hits);
    _playerStates[_currentPlayerIndex] = state.copyWith(
      total: applyCapitalVisit(
        total:    state.total,
        contract: contract,
        darts:    hits,
      ),
      lastRoundMet: contract == CapitalContract.capital ? null : met,
      totalBefore:  state.total,
      lastVisit:    hits,
    );
  }

  /// Moves to the next slot, and past the last one into the next round.
  Future<void> _advanceTurn() async {
    final wasLastSlot = _currentPlayerIndex == _playerStates.length - 1;
    _currentPlayerIndex = (_currentPlayerIndex + 1) % _playerStates.length;
    if (!wasLastSlot) return;

    _currentRound++;
    if (_currentRound > CapitalContract.lastRound) await _finishGame();
  }

  /// Closes the game on the highest capital, or on no winner when it is shared.
  Future<void> _finishGame() async {
    _gameOver = true;
    _currentRound = CapitalContract.lastRound;
    final top = _playerStates
        .map((s) => s.total)
        .reduce((a, b) => a > b ? a : b);
    final leaders = _playerStates.where((s) => s.total == top).toList();
    _winnerId = leaders.length == 1 ? leaders.first.player.id : null;
    await _db.updateCapitalGame(_game!.copyWith(finishedAt: DateTime.now()));
    notifyListeners();
  }

  // ── Undo ───────────────────────────────────────────────────────────────────

  /// Undoes the last dart and replays the rest to rebuild every total.
  ///
  /// A bot's darts are never undone one at a time: undo removes every bot dart
  /// since the last human dart, then that dart, in one rebuild. Undoing the
  /// dart that ended the game reopens it.
  Future<void> undoLastDart() async {
    if (_game == null || isBotTurn) return;
    if (!_throwHistory.any((t) => !_isBotId(t.playerId))) return;
    while (_isBotId(_throwHistory.last.playerId)) {
      await _db.deleteCapitalThrow(_throwHistory.removeLast().id!);
    }
    dropHeldVisit();
    botSuspended = true;

    final wasGameOver = _gameOver;
    final last = _throwHistory.removeLast();
    await _db.deleteCapitalThrow(last.id!);

    await _replayState();

    if (wasGameOver) {
      await _db.updateCapitalGame(_game!);
    }

    botSuspended = false;
    notifyListeners();
    scheduleBot();
  }

  // ── Replay ─────────────────────────────────────────────────────────────────

  /// Rebuilds every total and the turn from the persisted darts.
  ///
  /// A visit ends exactly where the live game ended it, on the third dart or
  /// on an exact 57, because the same two conditions are checked here.
  Future<void> _replayState() async {
    if (_game == null) return;

    final allThrows = await _db.getCapitalThrowsForGame(_game!.id!);

    _playerStates = _playerStates
        .map((s) => CapitalPlayerState(
              displayName: s.displayName,
              players:     s.players,
            ))
        .toList();

    _gameOver = false;
    _winnerId = null;
    _currentPlayerIndex = 0;
    _currentRound = 0;
    _visitBuffer.clear();
    _throwHistory.clear();

    for (final t in allThrows) {
      _visitBuffer.add(t);
      _throwHistory.add(t);
      if (_visitBuffer.length >= dartsPerVisit || shouldStopNow) {
        _settleVisit();
        _visitBuffer.clear();
        await _advanceTurn();
      }
      if (_gameOver) break;
    }
  }
}
