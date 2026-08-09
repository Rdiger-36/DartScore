import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/player.dart';
import '../models/game.dart';
import '../models/dart_throw.dart';
import '../models/cricket_game.dart';
import '../models/shanghai_game.dart';
import '../models/around_the_clock_game.dart';
import '../utils/throw_stats.dart';

/// Singleton SQLite wrapper and the single point of database access for the app.
///
/// Holds all schema definitions and migrations and exposes typed CRUD methods
/// for players, X01 games/throws, the three extra game modes, and sync support.
/// No widget or provider should query SQLite directly; everything goes through
/// this class.
class DbHelper {
  static final DbHelper instance = DbHelper._();
  static Database? _db;

  /// Where the database file lives, overriding the platform default. Only set
  /// by tests, which point it at an in-memory database so each case starts on
  /// a fresh schema.
  @visibleForTesting
  static String? debugDatabasePath;

  DbHelper._();

  /// Closes the cached connection so the next access opens a new one. Only
  /// used by tests between cases; the app keeps one connection for its lifetime.
  @visibleForTesting
  static Future<void> debugReset() async {
    await _db?.close();
    _db = null;
  }

  /// The lazily-opened database instance, created on first access.
  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  /// Opens (creating if needed) the `dartscore.db` database with foreign keys on.
  Future<Database> _initDb() async {
    final path =
        debugDatabasePath ?? join(await getDatabasesPath(), 'dartscore.db');
    return openDatabase(
      path,
      version: 18,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Applies incremental schema migrations from [oldVersion] up to [newVersion].
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE players ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE players ADD COLUMN uuid TEXT NOT NULL DEFAULT ''");
      await db.execute(
          'ALTER TABLE players ADD COLUMN last_synced_at INTEGER');
      final players = await db.query('players');
      for (final p in players) {
        final uuid = _generateUuid();
        await db.update('players', {'uuid': uuid},
            where: 'id = ?', whereArgs: [p['id']]);
      }
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE games ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE players ADD COLUMN synced_stats TEXT');
    }
    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE players ADD COLUMN is_primary INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 7) {
      await db.execute(
          'ALTER TABLE games ADD COLUMN team_config_json TEXT');
    }
    if (oldVersion < 8) {
      await db.execute(
          'ALTER TABLE players ADD COLUMN local_stats_json TEXT');
    }
    if (oldVersion < 9) {
      await db.execute(
          'ALTER TABLE dart_throws ADD COLUMN hits_json TEXT');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cricket_games (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          variant INTEGER NOT NULL,
          scoring_mode INTEGER NOT NULL,
          legs INTEGER NOT NULL,
          sets INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          finished_at INTEGER,
          player_ids TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cricket_throws (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_id INTEGER NOT NULL,
          player_id INTEGER NOT NULL,
          field INTEGER NOT NULL,
          multiplier INTEGER NOT NULL,
          leg INTEGER NOT NULL,
          set_ INTEGER NOT NULL,
          thrown_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shanghai_games (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          variant INTEGER NOT NULL,
          legs INTEGER NOT NULL,
          sets INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          finished_at INTEGER,
          player_ids TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shanghai_throws (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_id INTEGER NOT NULL,
          player_id INTEGER NOT NULL,
          target INTEGER NOT NULL,
          multiplier INTEGER NOT NULL,
          round INTEGER NOT NULL,
          leg INTEGER NOT NULL,
          set_ INTEGER NOT NULL,
          thrown_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS around_the_clock_games (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          variant INTEGER NOT NULL,
          legs INTEGER NOT NULL,
          sets INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          finished_at INTEGER,
          player_ids TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS around_the_clock_throws (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          game_id INTEGER NOT NULL,
          player_id INTEGER NOT NULL,
          field INTEGER NOT NULL,
          multiplier INTEGER NOT NULL,
          leg INTEGER NOT NULL,
          set_ INTEGER NOT NULL,
          thrown_at INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 13) {
      await db.execute(
          'ALTER TABLE cricket_games ADD COLUMN team_config_json TEXT');
    }
    if (oldVersion < 14) {
      await db.execute(
          'ALTER TABLE shanghai_games ADD COLUMN team_config_json TEXT');
    }
    if (oldVersion < 15) {
      await db.execute(
          'ALTER TABLE around_the_clock_games ADD COLUMN team_config_json TEXT');
    }
    if (oldVersion < 16) {
      await db.execute(
          'ALTER TABLE games ADD COLUMN placement_mode INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 17) {
      await db.execute('ALTER TABLE games ADD COLUMN handicap_json TEXT');
    }
    if (oldVersion < 18) {
      // Default 0 = StartingOrder.random, which is how every game up to here
      // was played: the setup screens always shuffled.
      for (final table in const [
        'games',
        'cricket_games',
        'shanghai_games',
        'around_the_clock_games',
      ]) {
        await db.execute(
            'ALTER TABLE $table ADD COLUMN starting_order INTEGER NOT NULL DEFAULT 0');
      }
    }
  }

  /// Generates a random RFC 4122 version-4 UUID for migrating rows that predate
  /// the uuid column.
  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(List<int> b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(bytes.sublist(0, 4))}-${hex(bytes.sublist(4, 6))}'
        '-${hex(bytes.sublist(6, 8))}-${hex(bytes.sublist(8, 10))}'
        '-${hex(bytes.sublist(10, 16))}';
  }

  /// Creates the full schema (all tables and indexes) for a fresh install.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE players (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        favorite_doubles TEXT NOT NULL DEFAULT '',
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_primary INTEGER NOT NULL DEFAULT 0,
        uuid TEXT NOT NULL DEFAULT '',
        last_synced_at INTEGER,
        synced_stats TEXT,
        local_stats_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_score INTEGER NOT NULL,
        game_mode INTEGER NOT NULL DEFAULT 0,
        checkout_mode INTEGER NOT NULL DEFAULT 1,
        legs INTEGER NOT NULL DEFAULT 3,
        sets INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        finished_at INTEGER,
        is_synced INTEGER NOT NULL DEFAULT 0,
        team_config_json TEXT,
        handicap_json TEXT,
        placement_mode INTEGER NOT NULL DEFAULT 0,
        starting_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE game_players (
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (game_id, player_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE dart_throws (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        darts_used INTEGER NOT NULL DEFAULT 3,
        leg INTEGER NOT NULL DEFAULT 1,
        set_ INTEGER NOT NULL DEFAULT 1,
        remaining_before INTEGER NOT NULL,
        thrown_at INTEGER NOT NULL,
        bust INTEGER NOT NULL DEFAULT 0,
        hits_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE cricket_games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        variant INTEGER NOT NULL,
        scoring_mode INTEGER NOT NULL,
        legs INTEGER NOT NULL,
        sets INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        finished_at INTEGER,
        player_ids TEXT NOT NULL,
        team_config_json TEXT,
        starting_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE cricket_throws (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        field INTEGER NOT NULL,
        multiplier INTEGER NOT NULL,
        leg INTEGER NOT NULL,
        set_ INTEGER NOT NULL,
        thrown_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE shanghai_games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        variant INTEGER NOT NULL,
        legs INTEGER NOT NULL,
        sets INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        finished_at INTEGER,
        player_ids TEXT NOT NULL,
        team_config_json TEXT,
        starting_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE shanghai_throws (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        target INTEGER NOT NULL,
        multiplier INTEGER NOT NULL,
        round INTEGER NOT NULL,
        leg INTEGER NOT NULL,
        set_ INTEGER NOT NULL,
        thrown_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE around_the_clock_games (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        variant INTEGER NOT NULL,
        legs INTEGER NOT NULL,
        sets INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        finished_at INTEGER,
        player_ids TEXT NOT NULL,
        team_config_json TEXT,
        starting_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE around_the_clock_throws (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id INTEGER NOT NULL,
        player_id INTEGER NOT NULL,
        field INTEGER NOT NULL,
        multiplier INTEGER NOT NULL,
        leg INTEGER NOT NULL,
        set_ INTEGER NOT NULL,
        thrown_at INTEGER NOT NULL
      )
    ''');
  }

  // Players

  /// The primary (non-deleted) player, or null if none is set.
  Future<Player?> getPrimaryPlayer() async {
    final d = await db;
    final rows = await d.query('players',
        where: 'is_primary = 1 AND is_deleted = 0');
    return rows.isEmpty ? null : Player.fromMap(rows.first);
  }

  /// Sets one player as primary, clears the flag on all others.
  Future<void> setPrimaryPlayer(int id) async {
    final d = await db;
    // Atomic: clear all, then set one, which prevents a crash window
    await d.transaction((txn) async {
      await txn.update('players', {'is_primary': 0});
      await txn.update('players', {'is_primary': 1},
          where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Inserts a new player and returns its assigned id.
  Future<int> insertPlayer(Player p) async {
    final d = await db;
    return d.insert('players', p.toMap()..remove('id'));
  }

  /// All non-deleted players ordered by name.
  Future<List<Player>> getPlayers() async {
    final d = await db;
    final rows = await d.query('players',
        where: 'is_deleted = 0', orderBy: 'name ASC');
    return rows.map(Player.fromMap).toList();
  }

  /// The player with [id] regardless of deleted status (for history/stats), or null.
  Future<Player?> getPlayer(int id) async {
    final d = await db;
    // Returns player regardless of deleted status (for history/stats)
    final rows = await d.query('players', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Player.fromMap(rows.first);
  }

  /// Every player keyed by id, deleted ones included, for callers that resolve
  /// many ids at once. The history would otherwise run one query per player per
  /// game.
  Future<Map<int, Player>> getPlayersById() async {
    final d = await db;
    final rows = await d.query('players');
    return {
      for (final row in rows.map(Player.fromMap))
        if (row.id != null) row.id!: row,
    };
  }

  /// Updates the stored row for [p].
  Future<void> updatePlayer(Player p) async {
    final d = await db;
    await d.update('players', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  /// Soft-deletes the player with [id], keeping the name visible in history/stats.
  Future<void> deletePlayer(int id) async {
    final d = await db;
    // Soft delete: keeps name visible in history/stats
    await d.update('players', {'is_deleted': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // Games

  /// Inserts an X01 game and its ordered player list, returning the game id.
  Future<int> insertGame(Game g, List<int> playerIds) async {
    final d = await db;
    final map = g.toMap()..remove('id');
    final gameId = await d.insert('games', map);
    for (var i = 0; i < playerIds.length; i++) {
      await d.insert('game_players', {
        'game_id': gameId,
        'player_id': playerIds[i],
        'sort_order': i,
      });
    }
    return gameId;
  }

  /// Permanently deletes an X01 game and its throws and player links.
  Future<void> deleteGame(int gameId) async {
    final d = await db;
    await d.delete('dart_throws', where: 'game_id = ?', whereArgs: [gameId]);
    await d.delete('game_players', where: 'game_id = ?', whereArgs: [gameId]);
    await d.delete('games', where: 'id = ?', whereArgs: [gameId]);
  }

  // Minimum darts to finish from a given start score (double-out).
  // Mirrors game_provider.dart: kept local to avoid circular import.
  static const _kMinDarts = {101: 2, 170: 3, 201: 4, 301: 6, 501: 9, 701: 12, 1001: 17};


  /// Counts perfect legs in [throws] (legs finished within [minDarts] darts).
  static int _perfectLegsFor(List<DartThrow> throws, int? minDarts) {
    if (minDarts == null) return 0;
    int count = 0;
    // Group darts used per leg (gameId-set-leg key)
    final legDarts = <String, int>{};
    for (final t in throws) {
      final k = '${t.gameId}-${t.set}-${t.leg}';
      legDarts[k] = (legDarts[k] ?? 0) + t.dartsUsed;
    }
    for (final t in throws) {
      if (!t.bust && t.remainingBefore - t.score == 0) {
        final k = '${t.gameId}-${t.set}-${t.leg}';
        if ((legDarts[k] ?? 999) <= minDarts) count++;
      }
    }
    return count;
  }

  /// Snapshots one game's throws into each involved player's persistent
  /// `local_stats_json`, so lifetime stats survive deleting the game. Call this
  /// BEFORE [deleteGame].
  Future<void> snapshotGameStats(int gameId) async {
    final d      = await db;
    final throws = await getThrowsForGame(gameId);
    if (throws.isEmpty) return;

    // Fetch startScore to compute perfect legs
    final gameRows  = await d.query('games', where: 'id = ?', whereArgs: [gameId]);
    final startScore = gameRows.isEmpty ? null : gameRows.first['start_score'] as int?;
    final minDarts   = startScore != null ? _kMinDarts[startScore] : null;

    final byPlayer = <int, List<DartThrow>>{};
    for (final t in throws) {
      byPlayer.putIfAbsent(t.playerId, () => []).add(t);
    }

    final isFinished = gameRows.isNotEmpty && gameRows.first['finished_at'] != null ? 1 : 0;

    for (final entry in byPlayer.entries) {
      final playerId     = entry.key;
      final playerThrows = entry.value;

      final stats = <String, dynamic>{
        ..._computeStatsFromThrows(playerThrows),
        'perfect_legs':    _perfectLegsFor(playerThrows, minDarts),
        'games_finished':  isFinished,
      };

      final rows = await d.query('players', where: 'id = ?', whereArgs: [playerId]);
      if (rows.isEmpty) continue;
      final existing = rows.first['local_stats_json'] as String?;

      final merged = (existing != null && existing.isNotEmpty)
          ? _mergeStats(jsonDecode(existing) as Map<String, dynamic>, stats)
          : stats;

      await d.update('players', {'local_stats_json': jsonEncode(merged)},
          where: 'id = ?', whereArgs: [playerId]);
    }
  }

  /// Folds [excluded] into the snapshot [snapshotJson] and returns the result,
  /// or null when there is nothing to carry.
  ///
  /// A sync can be limited to the last few days, in which case only those
  /// throws travel as individual throws. Everything older still has to reach
  /// the other device, just as aggregated numbers, otherwise its lifetime
  /// totals silently read low and nobody can tell. Grouping by game mirrors
  /// [snapshotGameStats]: perfect legs and the finished-game count are
  /// properties of a game, not of a single throw.
  Future<Map<String, dynamic>?> foldThrowsIntoSnapshot(
      String? snapshotJson, List<DartThrow> excluded) async {
    var merged = (snapshotJson != null && snapshotJson.isNotEmpty)
        ? jsonDecode(snapshotJson) as Map<String, dynamic>
        : null;
    if (excluded.isEmpty) return merged;

    final d = await db;

    final byGame = <int, List<DartThrow>>{};
    for (final t in excluded) {
      byGame.putIfAbsent(t.gameId, () => []).add(t);
    }

    for (final entry in byGame.entries) {
      final gameRows = await d.query('games',
          columns: ['start_score', 'finished_at'],
          where: 'id = ?',
          whereArgs: [entry.key]);

      final startScore =
          gameRows.isEmpty ? null : gameRows.first['start_score'] as int?;
      final minDarts = startScore != null ? _kMinDarts[startScore] : null;

      final stats = <String, dynamic>{
        ..._computeStatsFromThrows(entry.value),
        'perfect_legs':   _perfectLegsFor(entry.value, minDarts),
        'games_finished':
            gameRows.isNotEmpty && gameRows.first['finished_at'] != null ? 1 : 0,
      };

      merged = merged == null ? stats : _mergeStats(merged, stats);
    }

    return merged;
  }

  /// Computes an aggregate stats map (darts, scored, averages, highs, counts)
  /// from a list of throws.
  ///
  /// The counters that also matter while a game is running come from
  /// [ThrowStats], so a number shown live and the same number read back
  /// from a snapshot can never drift apart. Only what the persisted stats need
  /// on top of that is aggregated here: the segment heatmap, the score
  /// distribution, the per-day buckets behind the week comparison, and the
  /// recent-throws tail.
  static Map<String, dynamic> _computeStatsFromThrows(List<DartThrow> throws) {
    final stats = ThrowStats.fromThrows(throws);

    final segmentHits  = segmentHitsOf(throws);
    final scoreDistrib = <String, int>{};
    // date → {scored, darts, visits, s180} for week-comparison reconstruction
    final dailyStats   = <String, Map<String, int>>{};
    final gameIds = throws.map((t) => t.gameId).toSet();

    for (final t in throws) {
      // Daily stats (all throws, bust or not, for activity heat and week windows)
      final day = '${t.thrownAt.year}-'
          '${t.thrownAt.month.toString().padLeft(2, '0')}-'
          '${t.thrownAt.day.toString().padLeft(2, '0')}';
      final ds = dailyStats.putIfAbsent(day, () => {'scored': 0, 'darts': 0, 'visits': 0, 's180': 0});
      ds['darts'] = (ds['darts'] ?? 0) + t.dartsUsed;

      if (!t.bust) {
        final bucket = ((t.score ~/ 20) * 20).toString();
        scoreDistrib[bucket] = (scoreDistrib[bucket] ?? 0) + 1;

        ds['scored']  = (ds['scored']  ?? 0) + t.score;
        ds['visits']  = (ds['visits']  ?? 0) + 1;
        if (t.score == 180) ds['s180'] = (ds['s180'] ?? 0) + 1;
      }
    }

    // Recent throws: last 20, newest first, as compact maps
    final sortedThrows = [...throws]
      ..sort((a, b) => b.thrownAt.compareTo(a.thrownAt));
    final recentThrows = sortedThrows.take(20).map((t) => {
      'score':            t.score,
      'darts_used':       t.dartsUsed,
      'bust':             t.bust ? 1 : 0,
      'remaining_before': t.remainingBefore,
      'thrown_at':        t.thrownAt.millisecondsSinceEpoch,
    }).toList();

    return {
      'total_darts':        stats.totalDarts,
      'total_scored':       stats.totalScored,
      'total_visits':       stats.totalVisits,
      // A leg is won by finishing it, so every successful checkout is a leg.
      'legs_won':           stats.checkoutSuccesses,
      'busts':              stats.busts,
      'highest_visit':      stats.highestVisit,
      'highest_checkout':   stats.highestCheckout,
      'count_180':          stats.count180,
      'count_140_plus':     stats.count140plus,
      'count_100_plus':     stats.count100plus,
      'checkout_attempts':  stats.checkoutAttempts,
      'checkout_successes': stats.checkoutSuccesses,
      'games_played':       gameIds.length,
      'score_sum_squares':  stats.scoreSumSquares,
      'highest_game_avg':   bestGameAverage(throws),
      'co_at_sub40':  stats.coAttemptSub40,  'co_ok_sub40':  stats.coSuccessSub40,
      'co_at_sub60':  stats.coAttemptSub60,  'co_ok_sub60':  stats.coSuccessSub60,
      'co_at_sub100': stats.coAttemptSub100, 'co_ok_sub100': stats.coSuccessSub100,
      'co_at_sub170': stats.coAttemptSub170, 'co_ok_sub170': stats.coSuccessSub170,
      'segment_hits':       segmentHits,
      'score_distribution': scoreDistrib,
      'daily_stats':        dailyStats,
      'recent_throws':      recentThrows,
    };
  }

  /// Counts the dartboard segments [throws] hit, as field to multiplier to
  /// count, skipping the throws that were entered as a plain score.
  static Map<String, Map<String, int>> segmentHitsOf(List<DartThrow> throws) {
    final hits = <String, Map<String, int>>{};

    for (final t in throws) {
      if (t.hitsJson == null) continue;
      try {
        for (final h in jsonDecode(t.hitsJson!) as List<dynamic>) {
          final field = (h['f'] as int).toString();
          final mul   = (h['m'] as int).toString();
          hits.putIfAbsent(field, () => {});
          hits[field]![mul] = (hits[field]![mul] ?? 0) + 1;
        }
      } catch (_) {}
    }

    return hits;
  }

  /// Adds the segments [throws] hit to [snapshot], leaving every other counter
  /// in it untouched, and returns null when there is nothing to add.
  ///
  /// Which segment a dart landed on is the one thing a synced throw cannot
  /// carry: the wire format holds a visit's score but not the three darts
  /// behind it. Without this the dartboard heatmap and the top doubles would
  /// stay empty on the receiving device for everything that travelled as
  /// throws, and would fill in only for whatever a shorter range happened to
  /// push into the snapshot instead.
  ///
  /// Adding them here cannot double count: the throws travelling alongside
  /// arrive without their darts, so they contribute nothing to the segments on
  /// the other side.
  static Map<String, dynamic>? addSegmentHits(
      Map<String, dynamic>? snapshot, List<DartThrow> throws) {
    final hits = segmentHitsOf(throws);
    if (hits.isEmpty) return snapshot;
    return _mergeStats(snapshot ?? {}, {'segment_hits': hits});
  }

  /// Merges two stats maps, summing counts and recomputing maxima/averages, so
  /// snapshots accumulate across games.
  static Map<String, dynamic> _mergeStats(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    int add(String k) => (a[k] as int? ?? 0) + (b[k] as int? ?? 0);
    int mx(String k)  => max(a[k] as int? ?? 0, b[k] as int? ?? 0);
    double mxd(String k) =>
        max((a[k] as num? ?? 0).toDouble(), (b[k] as num? ?? 0).toDouble());

    // segment_hits: field → multiplier → count
    final aHits = (a['segment_hits'] as Map?)?.cast<String, dynamic>() ?? {};
    final bHits = (b['segment_hits'] as Map?)?.cast<String, dynamic>() ?? {};
    final mergedHits = <String, Map<String, int>>{};
    for (final f in {...aHits.keys, ...bHits.keys}) {
      final aM = (aHits[f] as Map?)?.cast<String, dynamic>() ?? {};
      final bM = (bHits[f] as Map?)?.cast<String, dynamic>() ?? {};
      final m  = <String, int>{};
      for (final mul in {...aM.keys, ...bM.keys}) {
        m[mul] = (aM[mul] as int? ?? 0) + (bM[mul] as int? ?? 0);
      }
      mergedHits[f] = m;
    }

    // score_distribution: bucket → count
    final aDist = (a['score_distribution'] as Map?)?.cast<String, dynamic>() ?? {};
    final bDist = (b['score_distribution'] as Map?)?.cast<String, dynamic>() ?? {};
    final mergedDist = <String, int>{};
    for (final k in {...aDist.keys, ...bDist.keys}) {
      mergedDist[k] = (aDist[k] as int? ?? 0) + (bDist[k] as int? ?? 0);
    }

    // daily_stats: date → {scored, darts, visits, s180}
    final aDs = (a['daily_stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final bDs = (b['daily_stats'] as Map?)?.cast<String, dynamic>() ?? {};
    final mergedDs = <String, Map<String, int>>{};
    for (final day in {...aDs.keys, ...bDs.keys}) {
      final aD = (aDs[day] as Map?)?.cast<String, dynamic>() ?? {};
      final bD = (bDs[day] as Map?)?.cast<String, dynamic>() ?? {};
      mergedDs[day] = {
        'scored':  (aD['scored']  as int? ?? 0) + (bD['scored']  as int? ?? 0),
        'darts':   (aD['darts']   as int? ?? 0) + (bD['darts']   as int? ?? 0),
        'visits':  (aD['visits']  as int? ?? 0) + (bD['visits']  as int? ?? 0),
        's180':    (aD['s180']    as int? ?? 0) + (bD['s180']    as int? ?? 0),
      };
    }

    // recent_throws: combine, sort newest-first, keep 20
    final aRt = (a['recent_throws'] as List?)?.cast<dynamic>() ?? [];
    final bRt = (b['recent_throws'] as List?)?.cast<dynamic>() ?? [];
    final combined = [...aRt, ...bRt]
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((x, y) => ((y['thrown_at'] as int? ?? 0)
          .compareTo(x['thrown_at'] as int? ?? 0)));
    final mergedRt = combined.take(20).toList();

    return {
      'total_darts':        add('total_darts'),
      'total_scored':       add('total_scored'),
      'total_visits':       add('total_visits'),
      'legs_won':           add('legs_won'),
      'busts':              add('busts'),
      'highest_visit':      mx('highest_visit'),
      'highest_checkout':   mx('highest_checkout'),
      'highest_game_avg':   mxd('highest_game_avg'),
      'count_180':          add('count_180'),
      'count_140_plus':     add('count_140_plus'),
      'count_100_plus':     add('count_100_plus'),
      'checkout_attempts':  add('checkout_attempts'),
      'checkout_successes': add('checkout_successes'),
      'games_played':       add('games_played'),
      'games_finished':     add('games_finished'),
      'score_sum_squares':  add('score_sum_squares'),
      'perfect_legs':       add('perfect_legs'),
      'co_at_sub40':  add('co_at_sub40'),  'co_ok_sub40':  add('co_ok_sub40'),
      'co_at_sub60':  add('co_at_sub60'),  'co_ok_sub60':  add('co_ok_sub60'),
      'co_at_sub100': add('co_at_sub100'), 'co_ok_sub100': add('co_ok_sub100'),
      'co_at_sub170': add('co_at_sub170'), 'co_ok_sub170': add('co_ok_sub170'),
      'segment_hits':       mergedHits,
      'score_distribution': mergedDist,
      'daily_stats':        mergedDs,
      'recent_throws':      mergedRt,
    };
  }

  /// Updates an X01 game row (e.g. to mark it finished).
  Future<void> updateGame(Game g) async {
    final d = await db;
    await d.update('games', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
  }

  /// All non-sync X01 games, newest first.
  Future<List<Game>> getGames() async {
    final d = await db;
    final rows = await d.query('games',
        where: 'is_synced = 0', orderBy: 'created_at DESC');
    return rows.map(Game.fromMap).toList();
  }

  /// The player ids for an X01 game in turn order.
  Future<List<int>> getGamePlayerIds(int gameId) async {
    final d = await db;
    final rows = await d.query(
      'game_players',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'sort_order ASC',
    );
    return rows.map((r) => r['player_id'] as int).toList();
  }

  // Throws

  /// Inserts an X01 throw and returns its id.
  Future<int> insertThrow(DartThrow t) async {
    final d = await db;
    final map = t.toMap()..remove('id');
    map['set_'] = map.remove('set');
    return d.insert('dart_throws', map);
  }

  /// Deletes the X01 throw with [id] (used by undo).
  Future<void> deleteThrow(int id) async {
    final d = await db;
    await d.delete('dart_throws', where: 'id = ?', whereArgs: [id]);
  }

  /// All throws for an X01 game in chronological order.
  Future<List<DartThrow>> getThrowsForGame(int gameId) async {
    final d = await db;
    final rows = await d.query(
      'dart_throws',
      where: 'game_id = ?',
      whereArgs: [gameId],
      // Ties on the millisecond are possible, so the row id decides. The
      // replay in every provider depends on a stable order.
      orderBy: 'thrown_at ASC, id ASC',
    );
    return rows.map(_throwFromMap).toList();
  }

  /// All X01 throws by a player across all games, in chronological order.
  Future<List<DartThrow>> getThrowsForPlayer(int playerId) async {
    final d = await db;
    final rows = await d.query(
      'dart_throws',
      where: 'player_id = ?',
      whereArgs: [playerId],
      // Ties on the millisecond are possible, so the row id decides. The
      // replay in every provider depends on a stable order.
      orderBy: 'thrown_at ASC, id ASC',
    );
    return rows.map(_throwFromMap).toList();
  }

  /// Returns all game IDs the player participated in, newest first.
  Future<List<int>> getGameIdsForPlayer(int playerId) async {
    final d = await db;
    final rows = await d.query(
      'game_players',
      columns: ['game_id'],
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
    final ids = rows.map((r) => r['game_id'] as int).toList();
    if (ids.isEmpty) return [];
    // sort by created_at desc
    final gameRows = await d.query(
      'games',
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
      orderBy: 'created_at DESC',
    );
    return gameRows.map((r) => r['id'] as int).toList();
  }

  /// Builds a [DartThrow] from a row, translating the reserved `set_` column
  /// back to `set`.
  DartThrow _throwFromMap(Map<String, dynamic> map) {
    final m = Map<String, dynamic>.from(map);
    m['set'] = m.remove('set_');
    return DartThrow.fromMap(m);
  }

  // ── Sync helpers ────────────────────────────────────────────────────────────

  /// The non-deleted player matching [uuid] (used to merge synced players), or null.
  Future<Player?> getPlayerByUuid(String uuid) async {
    final d = await db;
    final rows = await d.query('players',
        where: 'uuid = ? AND is_deleted = 0', whereArgs: [uuid]);
    return rows.isEmpty ? null : Player.fromMap(rows.first);
  }

  /// Throws since [sinceMs] (exclusive) for a player.
  Future<List<DartThrow>> getThrowsForPlayerSince(
      int playerId, int sinceMs) async {
    final d = await db;
    final rows = await d.query(
      'dart_throws',
      where: 'player_id = ? AND thrown_at > ?',
      whereArgs: [playerId, sinceMs],
      // Ties on the millisecond are possible, so the row id decides. The
      // replay in every provider depends on a stable order.
      orderBy: 'thrown_at ASC, id ASC',
    );
    return rows.map(_throwFromMap).toList();
  }

  /// All known thrown_at timestamps for a player (for dedup).
  Future<Set<int>> getThrowTimestampsForPlayer(int playerId) async {
    final d = await db;
    final rows = await d.query(
      'dart_throws',
      columns: ['thrown_at'],
      where: 'player_id = ?',
      whereArgs: [playerId],
    );
    return rows.map((r) => r['thrown_at'] as int).toSet();
  }

  /// Creates one hidden sync-game and returns its id.
  /// Call once per import session, then pass the id to [insertSyncedThrows].
  Future<int> createSyncGame(int playerStartScore) async {
    final d = await db;
    return d.insert('games', {
      'start_score': playerStartScore,
      'game_mode': 0,
      'checkout_mode': 1,
      'legs': 1,
      'sets': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'finished_at': DateTime.now().millisecondsSinceEpoch,
      'is_synced': 1, // hidden from history
    });
  }

  /// Removes [playerId]'s throws from earlier imports, dropping any hidden
  /// sync-game left empty by that.
  ///
  /// Call this before importing, because a packet is authoritative for
  /// everything that came from the sending device. Its stats snapshot may cover
  /// throws an earlier sync delivered one by one, and keeping both would count
  /// the same leg twice. Games played on this device carry `is_synced = 0` and
  /// are never touched.
  Future<void> deleteSyncedThrowsForPlayer(int playerId) async {
    final d = await db;
    final rows = await d.rawQuery(
      'SELECT DISTINCT g.id AS id FROM games g '
      'JOIN dart_throws t ON t.game_id = g.id '
      'WHERE g.is_synced = 1 AND t.player_id = ?',
      [playerId],
    );

    for (final row in rows) {
      final gameId = row['id'] as int;
      await d.delete('dart_throws',
          where: 'game_id = ? AND player_id = ?',
          whereArgs: [gameId, playerId]);

      final remaining = Sqflite.firstIntValue(await d.rawQuery(
          'SELECT COUNT(*) FROM dart_throws WHERE game_id = ?', [gameId]));
      if (remaining == 0) await deleteGame(gameId);
    }
  }

  /// Inserts throws imported during sync into the hidden sync-game.
  ///
  /// One statement per throw would mean a round trip each, and a sync can carry
  /// tens of thousands of them; a batch keeps a large import to a few seconds.
  /// Callers that show progress pass the throws in slices and get a chance to
  /// report between the calls.
  Future<void> insertSyncedThrows(
      int playerId, int gameId, List<DartThrow> throws) async {
    final d = await db;
    final batch = d.batch();

    for (final t in throws) {
      batch.insert('dart_throws', {
        'game_id': gameId,
        'player_id': playerId,
        'score': t.score,
        'darts_used': t.dartsUsed,
        'leg': t.leg,
        'set_': t.set,
        'remaining_before': t.remainingBefore,
        'thrown_at': t.thrownAt.millisecondsSinceEpoch,
        'bust': t.bust ? 1 : 0,
      });
    }

    await batch.commit(noResult: true);
  }

  /// Records the last sync time and optional received stats snapshot for a player.
  Future<void> updatePlayerSyncTime(int playerId, int syncedAt,
      {String? syncedStatsJson}) async {
    final d = await db;
    final map = <String, dynamic>{'last_synced_at': syncedAt};
    if (syncedStatsJson != null) map['synced_stats'] = syncedStatsJson;
    await d.update('players', map,
        where: 'id = ?', whereArgs: [playerId]);
  }

  // ── Cricket ──────────────────────────────────────────────────────────────────

  /// Inserts a Cricket game and returns its id.
  Future<int> insertCricketGame(CricketGame g) async {
    final d = await db;
    final map = g.toMap()..remove('id');
    return d.insert('cricket_games', map);
  }

  /// Updates a Cricket game row (e.g. to mark it finished).
  Future<void> updateCricketGame(CricketGame g) async {
    final d = await db;
    await d.update('cricket_games', g.toMap(),
        where: 'id = ?', whereArgs: [g.id]);
  }

  /// Inserts a Cricket dart and returns its id.
  Future<int> insertCricketThrow(CricketThrow t) async {
    final d = await db;
    final map = t.toMap()..remove('id');
    return d.insert('cricket_throws', map);
  }

  /// Deletes the Cricket dart with [id] (used by undo).
  Future<void> deleteCricketThrow(int id) async {
    final d = await db;
    await d.delete('cricket_throws', where: 'id = ?', whereArgs: [id]);
  }

  /// All Cricket darts for a game in chronological order.
  Future<List<CricketThrow>> getCricketThrowsForGame(int gameId) async {
    final d = await db;
    final rows = await d.query(
      'cricket_throws',
      where: 'game_id = ?',
      whereArgs: [gameId],
      // Ties on the millisecond are possible, so the row id decides. The
      // replay in every provider depends on a stable order.
      orderBy: 'thrown_at ASC, id ASC',
    );
    return rows.map(CricketThrow.fromMap).toList();
  }

  /// All Cricket games, newest first.
  Future<List<CricketGame>> getCricketGames() async {
    final d = await db;
    final rows = await d.query('cricket_games', orderBy: 'created_at DESC');
    return rows.map(CricketGame.fromMap).toList();
  }

  /// Permanently deletes a Cricket game and its darts.
  Future<void> deleteCricketGame(int gameId) async {
    final d = await db;
    await d.delete('cricket_throws', where: 'game_id = ?', whereArgs: [gameId]);
    await d.delete('cricket_games', where: 'id = ?', whereArgs: [gameId]);
  }

  // ── Shanghai ─────────────────────────────────────────────────────────────────

  /// Inserts a Shanghai game and returns its id.
  Future<int> insertShanghaiGame(ShanghaiGame g) async {
    final d = await db;
    final map = g.toMap()..remove('id');
    return d.insert('shanghai_games', map);
  }

  /// Updates a Shanghai game row (e.g. to mark it finished).
  Future<void> updateShanghaiGame(ShanghaiGame g) async {
    final d = await db;
    await d.update('shanghai_games', g.toMap(),
        where: 'id = ?', whereArgs: [g.id]);
  }

  /// Inserts a Shanghai dart and returns its id.
  Future<int> insertShanghaiThrow(ShanghaiThrow t) async {
    final d = await db;
    final map = t.toMap()..remove('id');
    return d.insert('shanghai_throws', map);
  }

  /// Deletes the Shanghai dart with [id] (used by undo).
  Future<void> deleteShanghaiThrow(int id) async {
    final d = await db;
    await d.delete('shanghai_throws', where: 'id = ?', whereArgs: [id]);
  }

  /// All Shanghai darts for a game in chronological order.
  Future<List<ShanghaiThrow>> getShanghaiThrowsForGame(int gameId) async {
    final d = await db;
    final rows = await d.query(
      'shanghai_throws',
      where: 'game_id = ?',
      whereArgs: [gameId],
      // Ties on the millisecond are possible, so the row id decides. The
      // replay in every provider depends on a stable order.
      orderBy: 'thrown_at ASC, id ASC',
    );
    return rows.map(ShanghaiThrow.fromMap).toList();
  }

  /// All Shanghai games, newest first.
  Future<List<ShanghaiGame>> getShanghaiGames() async {
    final d = await db;
    final rows = await d.query('shanghai_games', orderBy: 'created_at DESC');
    return rows.map(ShanghaiGame.fromMap).toList();
  }

  /// Permanently deletes a Shanghai game and its darts.
  Future<void> deleteShanghaiGame(int gameId) async {
    final d = await db;
    await d.delete('shanghai_throws', where: 'game_id = ?', whereArgs: [gameId]);
    await d.delete('shanghai_games', where: 'id = ?', whereArgs: [gameId]);
  }

  // ── Around the Clock ─────────────────────────────────────────────────────────

  /// Inserts an Around the Clock game and returns its id.
  Future<int> insertAroundTheClockGame(AroundTheClockGame g) async {
    final d = await db;
    final map = g.toMap()..remove('id');
    return d.insert('around_the_clock_games', map);
  }

  /// Updates an Around the Clock game row (e.g. to mark it finished).
  Future<void> updateAroundTheClockGame(AroundTheClockGame g) async {
    final d = await db;
    await d.update('around_the_clock_games', g.toMap(),
        where: 'id = ?', whereArgs: [g.id]);
  }

  /// Inserts an Around the Clock dart and returns its id.
  Future<int> insertAroundTheClockThrow(AroundTheClockThrow t) async {
    final d = await db;
    final map = t.toMap()..remove('id');
    return d.insert('around_the_clock_throws', map);
  }

  /// Deletes the Around the Clock dart with [id] (used by undo).
  Future<void> deleteAroundTheClockThrow(int id) async {
    final d = await db;
    await d.delete('around_the_clock_throws', where: 'id = ?', whereArgs: [id]);
  }

  /// All Around the Clock darts for a game in chronological order.
  Future<List<AroundTheClockThrow>> getAroundTheClockThrowsForGame(int gameId) async {
    final d = await db;
    final rows = await d.query(
      'around_the_clock_throws',
      where: 'game_id = ?',
      whereArgs: [gameId],
      // Ties on the millisecond are possible, so the row id decides. The
      // replay in every provider depends on a stable order.
      orderBy: 'thrown_at ASC, id ASC',
    );
    return rows.map(AroundTheClockThrow.fromMap).toList();
  }

  /// All Around the Clock games, newest first.
  Future<List<AroundTheClockGame>> getAroundTheClockGames() async {
    final d = await db;
    final rows = await d.query('around_the_clock_games', orderBy: 'created_at DESC');
    return rows.map(AroundTheClockGame.fromMap).toList();
  }

  /// Permanently deletes an Around the Clock game and its darts.
  Future<void> deleteAroundTheClockGame(int gameId) async {
    final d = await db;
    await d.delete('around_the_clock_throws', where: 'game_id = ?', whereArgs: [gameId]);
    await d.delete('around_the_clock_games', where: 'id = ?', whereArgs: [gameId]);
  }
}
