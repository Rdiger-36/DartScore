import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/player.dart';
import '../models/game.dart';
import '../models/dart_throw.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._();
  static Database? _db;

  DbHelper._();

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'dartscore.db');
    return openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

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
  }

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
        team_config_json TEXT
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
  }

  // Players
  Future<Player?> getPrimaryPlayer() async {
    final d = await db;
    final rows = await d.query('players',
        where: 'is_primary = 1 AND is_deleted = 0');
    return rows.isEmpty ? null : Player.fromMap(rows.first);
  }

  /// Sets one player as primary, clears the flag on all others.
  Future<void> setPrimaryPlayer(int id) async {
    final d = await db;
    // Atomic: clear all, then set one — prevents a crash window
    await d.transaction((txn) async {
      await txn.update('players', {'is_primary': 0});
      await txn.update('players', {'is_primary': 1},
          where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> insertPlayer(Player p) async {
    final d = await db;
    return d.insert('players', p.toMap()..remove('id'));
  }

  Future<List<Player>> getPlayers() async {
    final d = await db;
    final rows = await d.query('players',
        where: 'is_deleted = 0', orderBy: 'name ASC');
    return rows.map(Player.fromMap).toList();
  }

  Future<Player?> getPlayer(int id) async {
    final d = await db;
    // Returns player regardless of deleted status (for history/stats)
    final rows = await d.query('players', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Player.fromMap(rows.first);
  }

  Future<void> updatePlayer(Player p) async {
    final d = await db;
    await d.update('players', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> deletePlayer(int id) async {
    final d = await db;
    // Soft delete — keeps name visible in history/stats
    await d.update('players', {'is_deleted': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // Games
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

  Future<void> deleteGame(int gameId) async {
    final d = await db;
    await d.delete('dart_throws', where: 'game_id = ?', whereArgs: [gameId]);
    await d.delete('game_players', where: 'game_id = ?', whereArgs: [gameId]);
    await d.delete('games', where: 'id = ?', whereArgs: [gameId]);
  }

  /// Snapshots stats for ONE game's throws into each involved player's
  /// [local_stats_json]. Call this BEFORE [deleteGame].
  Future<void> snapshotGameStats(int gameId) async {
    final d      = await db;
    final throws = await getThrowsForGame(gameId);
    if (throws.isEmpty) return;

    final byPlayer = <int, List<DartThrow>>{};
    for (final t in throws) {
      byPlayer.putIfAbsent(t.playerId, () => []).add(t);
    }

    for (final entry in byPlayer.entries) {
      final playerId     = entry.key;
      final playerThrows = entry.value;

      final stats = _computeStatsFromThrows(playerThrows);

      final rows = await d.query('players',
          where: 'id = ?', whereArgs: [playerId]);
      if (rows.isEmpty) continue;
      final existing = rows.first['local_stats_json'] as String?;

      final merged = (existing != null && existing.isNotEmpty)
          ? _mergeStats(jsonDecode(existing) as Map<String, dynamic>, stats)
          : stats;

      await d.update('players', {'local_stats_json': jsonEncode(merged)},
          where: 'id = ?', whereArgs: [playerId]);
    }
  }

  /// Computes per-player stats from current throws and merges them into
  /// [local_stats_json] on each player. Call this BEFORE [clearAllGames].
  Future<void> snapshotPlayerStats() async {
    final d       = await db;
    final players = await getPlayers();

    for (final player in players) {
      final throws = await getThrowsForPlayer(player.id!);
      if (throws.isEmpty) continue;

      final stats    = _computeStatsFromThrows(throws);
      final existing = player.localStatsJson;
      final merged   = (existing != null && existing.isNotEmpty)
          ? _mergeStats(jsonDecode(existing) as Map<String, dynamic>, stats)
          : stats;

      await d.update('players', {'local_stats_json': jsonEncode(merged)},
          where: 'id = ?', whereArgs: [player.id]);
    }
  }

  static Map<String, int> _computeStatsFromThrows(List<DartThrow> throws) {
    int totalDarts = 0, totalScored = 0;
    int busts = 0, legsWon = 0;
    int highestVisit = 0, highestCheckout = 0;
    int count180 = 0, count140plus = 0, count100plus = 0;
    int checkoutAttempts = 0, checkoutSuccesses = 0;

    for (final t in throws) {
      totalDarts += t.dartsUsed;
      if (t.bust) {
        busts++;
      } else {
        totalScored += t.score;
        if (t.score > highestVisit) highestVisit = t.score;
        if (t.score == 180) count180++;
        if (t.score >= 140) count140plus++;
        if (t.score >= 100) count100plus++;

        if (t.remainingBefore <= 170) {
          checkoutAttempts++;
          if (t.remainingBefore - t.score == 0) {
            legsWon++;
            checkoutSuccesses++;
            if (t.score > highestCheckout) highestCheckout = t.score;
          }
        }
      }
    }

    return {
      'total_darts':        totalDarts,
      'total_scored':       totalScored,
      'total_visits':       throws.length,
      'legs_won':           legsWon,
      'busts':              busts,
      'highest_visit':      highestVisit,
      'highest_checkout':   highestCheckout,
      'count_180':          count180,
      'count_140_plus':     count140plus,
      'count_100_plus':     count100plus,
      'checkout_attempts':  checkoutAttempts,
      'checkout_successes': checkoutSuccesses,
    };
  }

  static Map<String, dynamic> _mergeStats(
    Map<String, dynamic> a,
    Map<String, int> b,
  ) {
    int add(String k) => (a[k] as int? ?? 0) + (b[k] ?? 0);
    int mx(String k)  => max(a[k] as int? ?? 0, b[k] ?? 0);
    return {
      'total_darts':        add('total_darts'),
      'total_scored':       add('total_scored'),
      'total_visits':       add('total_visits'),
      'legs_won':           add('legs_won'),
      'busts':              add('busts'),
      'highest_visit':      mx('highest_visit'),
      'highest_checkout':   mx('highest_checkout'),
      'count_180':          add('count_180'),
      'count_140_plus':     add('count_140_plus'),
      'count_100_plus':     add('count_100_plus'),
      'checkout_attempts':  add('checkout_attempts'),
      'checkout_successes': add('checkout_successes'),
    };
  }

  Future<void> clearAllGames() async {
    final d = await db;
    await d.delete('dart_throws');
    await d.delete('game_players');
    await d.delete('games');
  }

  Future<void> updateGame(Game g) async {
    final d = await db;
    await d.update('games', g.toMap(), where: 'id = ?', whereArgs: [g.id]);
  }

  Future<List<Game>> getGames() async {
    final d = await db;
    final rows = await d.query('games',
        where: 'is_synced = 0', orderBy: 'created_at DESC');
    return rows.map(Game.fromMap).toList();
  }

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
  Future<int> insertThrow(DartThrow t) async {
    final d = await db;
    final map = t.toMap()..remove('id');
    map['set_'] = map.remove('set');
    return d.insert('dart_throws', map);
  }

  Future<void> deleteThrow(int id) async {
    final d = await db;
    await d.delete('dart_throws', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DartThrow>> getThrowsForGame(int gameId) async {
    final d = await db;
    final rows = await d.query(
      'dart_throws',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'thrown_at ASC',
    );
    return rows.map(_throwFromMap).toList();
  }

  Future<List<DartThrow>> getThrowsForPlayer(int playerId) async {
    final d = await db;
    final rows = await d.query(
      'dart_throws',
      where: 'player_id = ?',
      whereArgs: [playerId],
      orderBy: 'thrown_at ASC',
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

  DartThrow _throwFromMap(Map<String, dynamic> map) {
    final m = Map<String, dynamic>.from(map);
    m['set'] = m.remove('set_');
    return DartThrow.fromMap(m);
  }

  // ── Sync helpers ────────────────────────────────────────────────────────────

  Future<Player?> getPlayerByUuid(String uuid) async {
    final d = await db;
    final rows = await d.query('players', where: 'uuid = ?', whereArgs: [uuid]);
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
      orderBy: 'thrown_at ASC',
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
  /// Call once per import session, then pass the id to [insertSyncedThrow].
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
      'is_synced': 1, // hidden from Spielverlauf
    });
  }

  Future<void> insertSyncedThrow(int playerId, int gameId, DartThrow t) async {
    final d = await db;
    await d.insert('dart_throws', {
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

  Future<void> updatePlayerSyncTime(int playerId, int syncedAt,
      {String? syncedStatsJson}) async {
    final d = await db;
    final map = <String, dynamic>{'last_synced_at': syncedAt};
    if (syncedStatsJson != null) map['synced_stats'] = syncedStatsJson;
    await d.update('players', map,
        where: 'id = ?', whereArgs: [playerId]);
  }
}
