import 'dart:convert';

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

/// Team assignment for team-game mode.
class TeamConfig {
  final String name;
  final List<int> playerIds; // DB IDs of players in this team

  const TeamConfig({required this.name, required this.playerIds});

  /// Serializes this team to a JSON map for the game's `team_config_json` column.
  Map<String, dynamic> toJson() => {'name': name, 'player_ids': playerIds};

  /// Reconstructs a team from its JSON map.
  factory TeamConfig.fromJson(Map<String, dynamic> j) => TeamConfig(
        name:      j['name'] as String,
        playerIds: (j['player_ids'] as List).cast<int>(),
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
        'team_config_json': teams == null
            ? null
            : jsonEncode(teams!.map((t) => t.toJson()).toList()),
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
        teams:        _parseTeams(map['team_config_json'] as String?),
      );

  /// Decodes the stored team-config JSON into [TeamConfig]s, or null for a
  /// non-team game.
  static List<TeamConfig>? _parseTeams(String? json) {
    if (json == null) return null;
    final list = jsonDecode(json) as List;
    return list.map((e) => TeamConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

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
      );
}
