import 'dart:convert';

enum CricketVariant { normal, cutThroat }
enum CricketScoringMode { standard, simple }

const List<int> cricketFields = [20, 19, 18, 17, 16, 15, 25];

int cricketFieldLabel(int field) => field; // 25 displayed as "Bull"

class CricketGame {
  final int? id;
  final CricketVariant variant;
  final CricketScoringMode scoringMode;
  final int legs;
  final int sets;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final List<int> playerIds;

  const CricketGame({
    this.id,
    required this.variant,
    required this.scoringMode,
    required this.legs,
    required this.sets,
    required this.createdAt,
    this.finishedAt,
    required this.playerIds,
  });

  Map<String, dynamic> toMap() => {
        'id':           id,
        'variant':      variant.index,
        'scoring_mode': scoringMode.index,
        'legs':         legs,
        'sets':         sets,
        'created_at':   createdAt.millisecondsSinceEpoch,
        'finished_at':  finishedAt?.millisecondsSinceEpoch,
        'player_ids':   jsonEncode(playerIds),
      };

  factory CricketGame.fromMap(Map<String, dynamic> map) => CricketGame(
        id:          map['id'] as int?,
        variant:     CricketVariant.values[map['variant'] as int],
        scoringMode: CricketScoringMode.values[map['scoring_mode'] as int],
        legs:        map['legs'] as int,
        sets:        map['sets'] as int,
        createdAt:   DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        finishedAt:  map['finished_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['finished_at'] as int)
            : null,
        playerIds:   (jsonDecode(map['player_ids'] as String) as List).cast<int>(),
      );

  CricketGame copyWith({DateTime? finishedAt}) => CricketGame(
        id:          id,
        variant:     variant,
        scoringMode: scoringMode,
        legs:        legs,
        sets:        sets,
        createdAt:   createdAt,
        finishedAt:  finishedAt ?? this.finishedAt,
        playerIds:   playerIds,
      );
}

class CricketThrow {
  final int? id;
  final int gameId;
  final int playerId;
  final int field;      // 15-20, 25=Bull, 0=miss
  final int multiplier; // 1-3; 0 for miss
  final int leg;
  final int set_;
  final DateTime thrownAt;

  const CricketThrow({
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

  factory CricketThrow.fromMap(Map<String, dynamic> map) => CricketThrow(
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
