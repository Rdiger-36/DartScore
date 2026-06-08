import 'dart:convert';

enum AroundTheClockVariant { basic, fullSegments, skipRules }

/// Clockwise target order, ending at the Bull's Eye (25). Hitting the final
/// entry wins the game.
const List<int> aroundTheClockOrder = [
  1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5, 20, 25,
];

class AroundTheClockGame {
  final int? id;
  final AroundTheClockVariant variant;
  final int legs;
  final int sets;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final List<int> playerIds;

  const AroundTheClockGame({
    this.id,
    required this.variant,
    required this.legs,
    required this.sets,
    required this.createdAt,
    this.finishedAt,
    required this.playerIds,
  });

  Map<String, dynamic> toMap() => {
        'id':          id,
        'variant':     variant.index,
        'legs':        legs,
        'sets':        sets,
        'created_at':  createdAt.millisecondsSinceEpoch,
        'finished_at': finishedAt?.millisecondsSinceEpoch,
        'player_ids':  jsonEncode(playerIds),
      };

  factory AroundTheClockGame.fromMap(Map<String, dynamic> map) => AroundTheClockGame(
        id:         map['id'] as int?,
        variant:    AroundTheClockVariant.values[map['variant'] as int],
        legs:       map['legs'] as int,
        sets:       map['sets'] as int,
        createdAt:  DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        finishedAt: map['finished_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['finished_at'] as int)
            : null,
        playerIds:  (jsonDecode(map['player_ids'] as String) as List).cast<int>(),
      );

  AroundTheClockGame copyWith({DateTime? finishedAt}) => AroundTheClockGame(
        id:         id,
        variant:    variant,
        legs:       legs,
        sets:       sets,
        createdAt:  createdAt,
        finishedAt: finishedAt ?? this.finishedAt,
        playerIds:  playerIds,
      );
}

class AroundTheClockThrow {
  final int? id;
  final int gameId;
  final int playerId;
  final int field;      // 1-20, 25=Bull, 0=miss
  final int multiplier; // 1-3; 0 for miss
  final int leg;
  final int set_;
  final DateTime thrownAt;

  const AroundTheClockThrow({
    this.id,
    required this.gameId,
    required this.playerId,
    required this.field,
    required this.multiplier,
    required this.leg,
    required this.set_,
    required this.thrownAt,
  });

  bool get isMiss => field == 0 || multiplier == 0;

  Map<String, dynamic> toMap() => {
        'id':         id,
        'game_id':    gameId,
        'player_id':  playerId,
        'field':      field,
        'multiplier': multiplier,
        'leg':        leg,
        'set_':       set_,
        'thrown_at':  thrownAt.millisecondsSinceEpoch,
      };

  factory AroundTheClockThrow.fromMap(Map<String, dynamic> map) => AroundTheClockThrow(
        id:         map['id'] as int?,
        gameId:     map['game_id'] as int,
        playerId:   map['player_id'] as int,
        field:      map['field'] as int,
        multiplier: map['multiplier'] as int,
        leg:        map['leg'] as int,
        set_:       map['set_'] as int,
        thrownAt:   DateTime.fromMillisecondsSinceEpoch(map['thrown_at'] as int),
      );
}
