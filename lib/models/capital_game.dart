import 'dart:convert';
import '../utils/dartboard_geometry.dart';
import 'starting_order.dart';

export 'starting_order.dart';

/// Capital progression. Only [classic] exists so far, the fifteen rounds the
/// rule book lists; the column is here so a later variant costs no migration.
enum CapitalVariant { classic }

/// A Capital game configuration and result. Per-dart hits are stored
/// separately as [CapitalThrow] records.
///
/// Capital carries no team configuration, unlike the other modes. The rule
/// book allows teams, but a player row named for a team covers that at no cost
/// in code, so the machinery is left out. Adding a nullable column later is a
/// cheap migration if that ever changes.
class CapitalGame {
  final int? id;
  final CapitalVariant variant;
  final int legs;
  final int sets;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final List<int> playerIds;
  /// How the throwing order was determined.
  final StartingOrder startingOrder;

  const CapitalGame({
    this.id,
    this.variant = CapitalVariant.classic,
    required this.legs,
    required this.sets,
    required this.createdAt,
    this.finishedAt,
    required this.playerIds,
    this.startingOrder = StartingOrder.random,
  });

  /// Serializes this game to a row map for the SQLite `capital_games` table.
  Map<String, dynamic> toMap() => {
        'id':             id,
        'variant':        variant.index,
        'legs':           legs,
        'sets':           sets,
        'created_at':     createdAt.millisecondsSinceEpoch,
        'finished_at':    finishedAt?.millisecondsSinceEpoch,
        'player_ids':     jsonEncode(playerIds),
        'starting_order': startingOrder.index,
      };

  /// Reconstructs a Capital game from a SQLite row map.
  factory CapitalGame.fromMap(Map<String, dynamic> map) => CapitalGame(
        id:         map['id'] as int?,
        variant:    CapitalVariant.values[map['variant'] as int],
        legs:       map['legs'] as int,
        sets:       map['sets'] as int,
        createdAt:  DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        finishedAt: map['finished_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['finished_at'] as int)
            : null,
        playerIds:  (jsonDecode(map['player_ids'] as String) as List).cast<int>(),
        startingOrder: StartingOrder.values[map['starting_order'] as int? ?? 0],
      );

  /// Returns a copy with [finishedAt] optionally updated (used to mark a game done).
  CapitalGame copyWith({DateTime? finishedAt}) => CapitalGame(
        id:         id,
        variant:    variant,
        legs:       legs,
        sets:       sets,
        createdAt:  createdAt,
        finishedAt: finishedAt ?? this.finishedAt,
        playerIds:  playerIds,
        startingOrder: startingOrder,
      );
}

/// A single dart thrown in a Capital game (one dart, not a full visit), used
/// to rebuild the totals and to support undo.
///
/// Where the dart landed is stored, not what it was aimed at, because Capital
/// never names a target: the contract judges what the visit actually hit. The
/// bull is field 25 with multiplier 1 for the outer ring and 2 for the inner,
/// and a miss is field 0 with multiplier 0, matching [BoardHit].
class CapitalThrow {
  final int? id;
  final int gameId;
  final int playerId;
  final int field;      // 0 miss, 1-20, or 25 for either bull ring
  final int multiplier; // 0 miss, 1-3
  final int round;      // 1-15, where round 1 builds the capital
  final int leg;
  final int set_;
  final DateTime thrownAt;

  const CapitalThrow({
    this.id,
    required this.gameId,
    required this.playerId,
    required this.field,
    required this.multiplier,
    required this.round,
    required this.leg,
    required this.set_,
    required this.thrownAt,
  });

  /// This dart as the board geometry and the contract rules express it.
  BoardHit get hit => (field: field, multiplier: multiplier);

  /// Whether this dart landed outside the double ring.
  bool get isMiss => multiplier == 0;

  /// Serializes this throw to a row map for the SQLite `capital_throws` table.
  Map<String, dynamic> toMap() => {
        'id':         id,
        'game_id':    gameId,
        'player_id':  playerId,
        'field':      field,
        'multiplier': multiplier,
        'round':      round,
        'leg':        leg,
        'set_':       set_,
        'thrown_at':  thrownAt.millisecondsSinceEpoch,
      };

  /// Reconstructs a Capital throw from a SQLite row map.
  factory CapitalThrow.fromMap(Map<String, dynamic> map) => CapitalThrow(
        id:         map['id'] as int?,
        gameId:     map['game_id'] as int,
        playerId:   map['player_id'] as int,
        field:      map['field'] as int,
        multiplier: map['multiplier'] as int,
        round:      map['round'] as int,
        leg:        map['leg'] as int,
        set_:       map['set_'] as int,
        thrownAt:   DateTime.fromMillisecondsSinceEpoch(map['thrown_at'] as int),
      );
}
