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
  // Mirrors game_provider.dart — kept local to avoid circular import.
  static const _kMinDarts = {101: 2, 170: 3, 201: 4, 301: 6, 501: 9, 701: 12, 1001: 17};

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

  /// [local_stats_json]. Call this BEFORE [deleteGame].
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

  /// Computes per-player stats from current throws and merges them into
  /// [local_stats_json] on each player. Call this BEFORE [clearAllGames].
  Future<void> snapshotPlayerStats() async {
    final d       = await db;
    final players = await getPlayers();

    // Build gameId → startScore map for perfect-leg computation
    final allGames    = await d.query('games');
    final startScores = {for (final g in allGames) g['id'] as int: g['start_score'] as int};

    for (final player in players) {
      final throws = await getThrowsForPlayer(player.id!);
      if (throws.isEmpty) continue;

      // Perfect legs: compute per game since each game has its own minDarts
      int totalPerfect = 0;
      final gameIds = throws.map((t) => t.gameId).toSet();
      for (final gid in gameIds) {
        final gThrows  = throws.where((t) => t.gameId == gid).toList();
        final minDarts = _kMinDarts[startScores[gid]];
        totalPerfect  += _perfectLegsFor(gThrows, minDarts);
      }

      // Count finished games for this player
      final playerGameIds   = throws.map((t) => t.gameId).toSet();
      final finishedCount   = allGames
          .where((g) => playerGameIds.contains(g['id']) && g['finished_at'] != null)
          .length;

      final stats = <String, dynamic>{
        ..._computeStatsFromThrows(throws),
        'perfect_legs':   totalPerfect,
        'games_finished': finishedCount,
      };
      final existing = player.localStatsJson;
      final merged   = (existing != null && existing.isNotEmpty)
          ? _mergeStats(jsonDecode(existing) as Map<String, dynamic>, stats)
          : stats;

      await d.update('players', {'local_stats_json': jsonEncode(merged)},
          where: 'id = ?', whereArgs: [player.id]);
    }
  }

  static Map<String, dynamic> _computeStatsFromThrows(List<DartThrow> throws) {
    int totalDarts = 0, totalScored = 0;
    int busts = 0, legsWon = 0;
    int highestVisit = 0, highestCheckout = 0;
    int count180 = 0, count140plus = 0, count100plus = 0;
    int checkoutAttempts = 0, checkoutSuccesses = 0;
    int scoreSumSquares = 0;
    int coAtSub40 = 0, coOkSub40 = 0;
    int coAtSub60 = 0, coOkSub60 = 0;
    int coAtSub100 = 0, coOkSub100 = 0;
    int coAtSub170 = 0, coOkSub170 = 0;
    final segmentHits    = <String, Map<String, int>>{};
    final scoreDistrib   = <String, int>{};
    // date → {scored, darts, visits, s180} for week-comparison reconstruction
    final dailyStats     = <String, Map<String, int>>{};
    final gameIds = throws.map((t) => t.gameId).toSet();

    for (final t in throws) {
      totalDarts += t.dartsUsed;

      // Heatmap
      if (t.hitsJson != null) {
        try {
          final hits = jsonDecode(t.hitsJson!) as List<dynamic>;
          for (final h in hits) {
            final field = (h['f'] as int).toString();
            final mul   = (h['m'] as int).toString();
            segmentHits.putIfAbsent(field, () => {});
            segmentHits[field]![mul] = (segmentHits[field]![mul] ?? 0) + 1;
          }
        } catch (_) {}
      }

      // Daily stats (all throws, bust or not — for activity heat and week windows)
      final day = '${t.thrownAt.year}-'
          '${t.thrownAt.month.toString().padLeft(2, '0')}-'
          '${t.thrownAt.day.toString().padLeft(2, '0')}';
      final ds = dailyStats.putIfAbsent(day, () => {'scored': 0, 'darts': 0, 'visits': 0, 's180': 0});
      ds['darts'] = (ds['darts'] ?? 0) + t.dartsUsed;

      if (t.bust) {
        busts++;
      } else {
        totalScored     += t.score;
        scoreSumSquares += t.score * t.score;
        if (t.score > highestVisit) highestVisit = t.score;
        if (t.score == 180) count180++;
        if (t.score >= 140) count140plus++;
        if (t.score >= 100) count100plus++;

        final bucket = ((t.score ~/ 20) * 20).toString();
        scoreDistrib[bucket] = (scoreDistrib[bucket] ?? 0) + 1;

        ds['scored']  = (ds['scored']  ?? 0) + t.score;
        ds['visits']  = (ds['visits']  ?? 0) + 1;
        if (t.score == 180) ds['s180'] = (ds['s180'] ?? 0) + 1;

        if (t.remainingBefore <= 170) {
          checkoutAttempts++;
          final success = t.remainingBefore - t.score == 0;
          if (t.remainingBefore <= 40)       { coAtSub40++;  if (success) coOkSub40++;  }
          else if (t.remainingBefore <= 60)  { coAtSub60++;  if (success) coOkSub60++;  }
          else if (t.remainingBefore <= 100) { coAtSub100++; if (success) coOkSub100++; }
          else                               { coAtSub170++; if (success) coOkSub170++; }
          if (success) {
            legsWon++;
            checkoutSuccesses++;
            if (t.score > highestCheckout) highestCheckout = t.score;
          }
        }
      }
    }

    // Recent throws — last 20, newest first, as compact maps
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
      'games_played':       gameIds.length,
      'score_sum_squares':  scoreSumSquares,
      'co_at_sub40':  coAtSub40,  'co_ok_sub40':  coOkSub40,
      'co_at_sub60':  coAtSub60,  'co_ok_sub60':  coOkSub60,
      'co_at_sub100': coAtSub100, 'co_ok_sub100': coOkSub100,
      'co_at_sub170': coAtSub170, 'co_ok_sub170': coOkSub170,
      'segment_hits':       segmentHits,
      'score_distribution': scoreDistrib,
      'daily_stats':        dailyStats,
      'recent_throws':      recentThrows,
    };
  }

  static Map<String, dynamic> _mergeStats(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    int add(String k) => (a[k] as int? ?? 0) + (b[k] as int? ?? 0);
    int mx(String k)  => max(a[k] as int? ?? 0, b[k] as int? ?? 0);

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
