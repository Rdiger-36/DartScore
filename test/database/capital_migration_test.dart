import 'dart:io';

import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/capital_game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('upgrading a database that predates Capital', () {
    late Directory dir;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // A file, because the migration has to survive closing the connection and
      // an in-memory database does not.
      dir = await Directory.systemTemp.createTemp('dartscore_capital');
      DbHelper.debugDatabasePath = '${dir.path}/dartscore.db';
      await DbHelper.debugReset();
    });

    tearDown(() async {
      await DbHelper.debugReset();
      DbHelper.debugDatabasePath = null;
      await dir.delete(recursive: true);
    });

    /// Winds a current database back to how version 24 left it, so the upgrade
    /// runs against a database that never held the Capital tables.
    Future<void> windBackTo24(Database db) async {
      await db.execute('DROP INDEX IF EXISTS idx_capital_throws_game');
      await db.execute('DROP TABLE IF EXISTS capital_throws');
      await db.execute('DROP TABLE IF EXISTS capital_games');
      await db.execute('PRAGMA user_version = 24');
    }

    /// Winds a current database back to how version 17 left it: no starting
    /// order on any game table, none of the indexes, and none of the tables
    /// that came after. This is the path that broke when the step to 18 and
    /// the step to 19 still mentioned the Capital tables, which do not exist
    /// until the step to 26.
    Future<void> windBackTo17(Database db) async {
      final indexes = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name LIKE 'idx_%'");
      for (final row in indexes) {
        await db.execute('DROP INDEX ${row['name']}');
      }
      for (final table in const [
        'capital_throws',
        'capital_games',
        'checkout_ladder_throws',
        'checkout_ladder_games',
        'player_origin_stats',
        'app_meta',
      ]) {
        await db.execute('DROP TABLE $table');
      }
      await db.execute('ALTER TABLE games DROP COLUMN origin_device');
      await db.execute('ALTER TABLE dart_throws DROP COLUMN checkout_darts');
      await db.execute('ALTER TABLE players DROP COLUMN bot_ordinal');
      await db.execute('ALTER TABLE players DROP COLUMN bot_level');
      for (final table in const [
        'games',
        'cricket_games',
        'shanghai_games',
        'around_the_clock_games',
      ]) {
        await db.execute('ALTER TABLE $table DROP COLUMN starting_order');
      }
      await db.execute('PRAGMA user_version = 17');
    }

    /// The tables the database holds right now.
    Future<Set<String>> tablesOf(Database db) async {
      final rows = await db
          .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
      return rows.map((r) => r['name'] as String).toSet();
    }

    test('creates both Capital tables on the way up from 24', () async {
      final fresh = await DbHelper.instance.db;
      await windBackTo24(fresh);
      expect(await tablesOf(fresh), isNot(contains('capital_games')));
      await DbHelper.debugReset();

      final upgraded = await DbHelper.instance.db;
      final tables = await tablesOf(upgraded);
      expect(tables, contains('capital_games'));
      expect(tables, contains('capital_throws'));
      expect(await upgraded.getVersion(), DbHelper.schemaVersion);
    });

    test('upgrades a database from before the starting order and the indexes',
        () async {
      final fresh = await DbHelper.instance.db;
      await fresh.insert('players', {'name': 'Nik', 'uuid': 'u-1'});
      await windBackTo17(fresh);
      await DbHelper.debugReset();

      final upgraded = await DbHelper.instance.db;
      expect(await upgraded.getVersion(), DbHelper.schemaVersion);
      expect(await tablesOf(upgraded),
          containsAll(['capital_games', 'capital_throws']));
      expect(await DbHelper.instance.getCapitalGames(), isEmpty);
      expect(await DbHelper.instance.getPlayers(), hasLength(1));
    });

    test('stores the board a game was played on', () async {
      final playerId = await DbHelper.instance.db.then(
          (db) => db.insert('players', {'name': 'Nik', 'uuid': 'u-1'}));
      await DbHelper.instance.insertCapitalGame(CapitalGame(
        boardType: BoardType.softTip,
        createdAt: DateTime(2026, 11, 10),
        playerIds: [playerId],
      ));

      final games = await DbHelper.instance.getCapitalGames();
      expect(games.single.boardType, BoardType.softTip);
    });

    test('reads a game stored without a board as a steel one', () async {
      final d = await DbHelper.instance.db;
      await d.insert('capital_games', {
        'variant': 0,
        'created_at': 1,
        'player_ids': '[1]',
      });

      final games = await DbHelper.instance.getCapitalGames();
      expect(games.single.boardType, BoardType.steel);
    });

    test('indexes the darts by game on the way up', () async {
      final fresh = await DbHelper.instance.db;
      await windBackTo24(fresh);
      await DbHelper.debugReset();

      final upgraded = await DbHelper.instance.db;
      final rows = await upgraded.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND name = 'idx_capital_throws_game'");
      expect(rows, hasLength(1));
    });

    test('leaves the games every other mode already stored alone', () async {
      final fresh = await DbHelper.instance.db;
      await fresh.insert('players', {'name': 'Nik', 'uuid': 'u-1'});
      await fresh.insert('shanghai_games', {
        'variant': 0,
        'legs': 1,
        'sets': 1,
        'created_at': 1,
        'player_ids': '[1]',
      });
      await windBackTo24(fresh);
      await DbHelper.debugReset();

      expect(await DbHelper.instance.getShanghaiGames(), hasLength(1));
      expect(await DbHelper.instance.getPlayers(), hasLength(1));
    });

    test('stores and reads back a Capital game and its darts', () async {
      final d = await DbHelper.instance.db;
      await windBackTo24(d);
      await DbHelper.debugReset();

      final playerId = await DbHelper.instance.db.then(
          (db) => db.insert('players', {'name': 'Nik', 'uuid': 'u-1'}));
      final gameId = await DbHelper.instance.insertCapitalGame(CapitalGame(
        createdAt: DateTime(2026, 10, 21),
        playerIds: [playerId],
      ));

      await DbHelper.instance.insertCapitalThrow(CapitalThrow(
        gameId: gameId,
        playerId: playerId,
        field: 25,
        multiplier: 2,
        round: 0,
        thrownAt: DateTime(2026, 10, 21),
      ));

      final games = await DbHelper.instance.getCapitalGames();
      expect(games, hasLength(1));
      expect(games.single.variant, CapitalVariant.classic);
      expect(games.single.playerIds, [playerId]);

      final darts =
          await DbHelper.instance.getCapitalThrowsForGame(gameId);
      expect(darts, hasLength(1));
      // The bull survives the round trip as field 25 in the inner ring, which
      // is what the board geometry and the contract rules expect.
      expect(darts.single.hit, (field: 25, multiplier: 2));
      expect(darts.single.round, 0);
    });

    test('deletes a game together with its darts', () async {
      final playerId = await DbHelper.instance.db.then(
          (db) => db.insert('players', {'name': 'Nik', 'uuid': 'u-1'}));
      final gameId = await DbHelper.instance.insertCapitalGame(CapitalGame(
        createdAt: DateTime(2026, 10, 21),
        playerIds: [playerId],
      ));
      await DbHelper.instance.insertCapitalThrow(CapitalThrow(
        gameId: gameId,
        playerId: playerId,
        field: 20,
        multiplier: 3,
        round: 2,
        thrownAt: DateTime(2026, 10, 21),
      ));

      await DbHelper.instance.deleteCapitalGame(gameId);

      expect(await DbHelper.instance.getCapitalGames(), isEmpty);
      expect(await DbHelper.instance.getCapitalThrowsForGame(gameId), isEmpty);
    });
  });
}
