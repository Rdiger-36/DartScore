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
        legs: 1,
        sets: 1,
        createdAt: DateTime(2026, 10, 21),
        playerIds: [playerId],
      ));

      await DbHelper.instance.insertCapitalThrow(CapitalThrow(
        gameId: gameId,
        playerId: playerId,
        field: 25,
        multiplier: 2,
        round: 1,
        leg: 1,
        set_: 1,
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
      expect(darts.single.round, 1);
    });

    test('deletes a game together with its darts', () async {
      final playerId = await DbHelper.instance.db.then(
          (db) => db.insert('players', {'name': 'Nik', 'uuid': 'u-1'}));
      final gameId = await DbHelper.instance.insertCapitalGame(CapitalGame(
        legs: 1,
        sets: 1,
        createdAt: DateTime(2026, 10, 21),
        playerIds: [playerId],
      ));
      await DbHelper.instance.insertCapitalThrow(CapitalThrow(
        gameId: gameId,
        playerId: playerId,
        field: 20,
        multiplier: 3,
        round: 2,
        leg: 1,
        set_: 1,
        thrownAt: DateTime(2026, 10, 21),
      ));

      await DbHelper.instance.deleteCapitalGame(gameId);

      expect(await DbHelper.instance.getCapitalGames(), isEmpty);
      expect(await DbHelper.instance.getCapitalThrowsForGame(gameId), isEmpty);
    });
  });
}
