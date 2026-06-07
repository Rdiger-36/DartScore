import 'dart:convert';

enum ShanghaiVariant { classic, clockwise, sequential }

class ShanghaiGame {
  final int? id;
  final ShanghaiVariant variant;
  final int legs;
  final int sets;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final List<int> playerIds;

  const ShanghaiGame({
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

  factory ShanghaiGame.fromMap(Map<String, dynamic> map) => ShanghaiGame(
        id:         map['id'] as int?,
        variant:    ShanghaiVariant.values[map['variant'] as int],
        legs:       map['legs'] as int,
        sets:       map['sets'] as int,
        createdAt:  DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        finishedAt: map['finished_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['finished_at'] as int)
            : null,
        playerIds:  (jsonDecode(map['player_ids'] as String) as List).cast<int>(),
      );

  ShanghaiGame copyWith({DateTime? finishedAt}) => ShanghaiGame(
        id:         id,
        variant:    variant,
        legs:       legs,
        sets:       sets,
        createdAt:  createdAt,
        finishedAt: finishedAt ?? this.finishedAt,
        playerIds:  playerIds,
      );
}

class ShanghaiThrow {
  final int? id;
  final int gameId;
  final int playerId;
  final int target;     // the number this dart aimed at
  final int multiplier; // 1-3; 0 for miss
  final int round;      // visit/round index (1-based)
  final int leg;
  final int set_;
  final DateTime thrownAt;

  const ShanghaiThrow({
    this.id,
    required this.gameId,
    required this.playerId,
    required this.target,
    required this.multiplier,
    required this.round,
    required this.leg,
    required this.set_,
    required this.thrownAt,
  });

  bool get isMiss => multiplier == 0;

  Map<String, dynamic> toMap() => {
        'id':         id,
        'game_id':    gameId,
        'player_id':  playerId,
        'target':     target,
        'multiplier': multiplier,
        'round':      round,
        'leg':        leg,
        'set_':       set_,
        'thrown_at':  thrownAt.millisecondsSinceEpoch,
      };

  factory ShanghaiThrow.fromMap(Map<String, dynamic> map) => ShanghaiThrow(
        id:         map['id'] as int?,
        gameId:     map['game_id'] as int,
        playerId:   map['player_id'] as int,
        target:     map['target'] as int,
        multiplier: map['multiplier'] as int,
        round:      map['round'] as int,
        leg:        map['leg'] as int,
        set_:       map['set_'] as int,
        thrownAt:   DateTime.fromMillisecondsSinceEpoch(map['thrown_at'] as int),
      );
}
