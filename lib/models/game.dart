import 'team_config.dart';

export 'team_config.dart';

/// How a player may open (check in) an X01 leg: with any field, only a double,
/// or any double/triple (master).
enum GameMode { straightIn, doubleIn, masterIn }

/// How a player must finish (check out) an X01 leg: on any field, only a double,
/// or any double/triple (master).
enum CheckoutMode { straightOut, doubleOut, masterOut }

/// Per-player handicap: individual check-in and check-out rules.
class PlayerHandicap {
  final GameMode checkIn;
  final CheckoutMode checkOut;

  const PlayerHandicap({
    this.checkIn = GameMode.straightIn,
    this.checkOut = CheckoutMode.doubleOut,
  });

  /// Returns a copy with the given check-in/check-out rules replaced.
  PlayerHandicap copyWith({GameMode? checkIn, CheckoutMode? checkOut}) =>
      PlayerHandicap(
        checkIn:  checkIn  ?? this.checkIn,
        checkOut: checkOut ?? this.checkOut,
      );
}

/// An X01 game configuration and result (start score, in/out modes, legs/sets,
/// and optional team setup). Per-turn scoring is stored separately as
/// [DartThrow] records.
class Game {
  final int? id;
  final int startScore;
  final GameMode gameMode;
  final CheckoutMode checkoutMode;
  final int legs;
  final int sets;
  final DateTime createdAt;
  final DateTime? finishedAt;
  /// Non-null when this is a team game.
  final List<TeamConfig>? teams;
  /// Whether every leg is played to the end (everyone finishes, producing a
  /// 1st/2nd/3rd/... ranking) instead of ending as soon as one slot checks out.
  final bool placementMode;

  const Game({
    this.id,
    required this.startScore,
    this.gameMode = GameMode.straightIn,
    this.checkoutMode = CheckoutMode.doubleOut,
    this.legs = 3,
    this.sets = 1,
    required this.createdAt,
    this.finishedAt,
    this.teams,
    this.placementMode = false,
  });

  /// Whether this game is played in teams rather than individually.
  bool get isTeamGame => teams != null && teams!.isNotEmpty;

  /// Serializes this game to a row map for the SQLite `games` table.
  Map<String, dynamic> toMap() => {
        'id': id,
        'start_score': startScore,
        'game_mode': gameMode.index,
        'checkout_mode': checkoutMode.index,
        'legs': legs,
        'sets': sets,
        'created_at': createdAt.millisecondsSinceEpoch,
        'finished_at': finishedAt?.millisecondsSinceEpoch,
        'team_config_json': encodeTeamConfigs(teams),
        'placement_mode': placementMode ? 1 : 0,
      };

  /// Reconstructs a game from a SQLite row map.
  factory Game.fromMap(Map<String, dynamic> map) => Game(
        id:           map['id'] as int?,
        startScore:   map['start_score'] as int,
        gameMode:     GameMode.values[map['game_mode'] as int],
        checkoutMode: CheckoutMode.values[map['checkout_mode'] as int],
        legs:         map['legs'] as int,
        sets:         map['sets'] as int,
        createdAt:    DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        finishedAt:   map['finished_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['finished_at'] as int)
            : null,
        teams:        decodeTeamConfigs(map['team_config_json'] as String?),
        placementMode: (map['placement_mode'] as int? ?? 0) == 1,
      );

  /// Returns a copy with [finishedAt] optionally updated (used to mark a game done).
  Game copyWith({DateTime? finishedAt}) => Game(
        id:           id,
        startScore:   startScore,
        gameMode:     gameMode,
        checkoutMode: checkoutMode,
        legs:         legs,
        sets:         sets,
        createdAt:    createdAt,
        finishedAt:   finishedAt ?? this.finishedAt,
        teams:        teams,
        placementMode: placementMode,
      );
}
