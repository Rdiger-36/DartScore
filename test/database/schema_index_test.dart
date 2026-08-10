import 'dart:io';

import 'package:dartscore_app/database/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_db.dart';

/// The indexes the repeated lookups depend on. Named rather than counted, so
/// dropping one to "clean up" fails here instead of quietly turning a lookup
/// back into a full table scan.
const _expectedIndexes = {
  'idx_dart_throws_player',
  'idx_dart_throws_game',
  'idx_game_players_player',
  'idx_cricket_throws_game',
  'idx_shanghai_throws_game',
  'idx_atc_throws_game',
};

/// The names of every index the schema defines itself, ignoring the ones
/// SQLite creates on its own for primary keys.
Future<Set<String>> _indexNames(Database db) async {
  final rows = await db.query(
    'sqlite_master',
    columns: ['name'],
    where: "type = 'index' AND name NOT LIKE 'sqlite_%'",
  );
  return rows.map((r) => r['name'] as String).toSet();
}

void main() {
  group('a fresh database', () {
    useInMemoryDatabase();

    test('carries every index the lookups rely on', () async {
      final db = await DbHelper.instance.db;

      expect(await _indexNames(db), containsAll(_expectedIndexes));
    });

    test('answers a throw lookup by player from the index, not by scanning',
        () async {
      final db = await DbHelper.instance.db;

      final plan = await db.rawQuery(
          'EXPLAIN QUERY PLAN SELECT * FROM dart_throws WHERE player_id = 1');

      expect(plan.map((r) => r['detail']).join(' '),
          contains('idx_dart_throws_player'));
    });

    test('answers a throw lookup by game from the index, not by scanning',
        () async {
      final db = await DbHelper.instance.db;

      final plan = await db.rawQuery(
          'EXPLAIN QUERY PLAN SELECT * FROM dart_throws WHERE game_id = 1');

      expect(plan.map((r) => r['detail']).join(' '),
          contains('idx_dart_throws_game'));
    });
  });

  group('upgrading a database that predates the indexes', () {
    late Directory dir;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // A file, because the migration has to survive closing the connection and
      // an in-memory database does not.
      dir = await Directory.systemTemp.createTemp('dartscore_migration');
      DbHelper.debugDatabasePath = '${dir.path}/dartscore.db';
      await DbHelper.debugReset();
    });

    tearDown(() async {
      await DbHelper.debugReset();
      DbHelper.debugDatabasePath = null;
      await dir.delete(recursive: true);
    });

    test('gets the indexes it never had', () async {
      // Wind a current database back to how version 18 left it: the same
      // tables, without any of the indexes. Rebuilding the old schema by hand
      // would only risk drifting from what version 18 actually shipped.
      final fresh = await DbHelper.instance.db;
      for (final name in await _indexNames(fresh)) {
        await fresh.execute('DROP INDEX $name');
      }
      await fresh.execute('PRAGMA user_version = 18');
      expect(await _indexNames(fresh), isEmpty);
      await DbHelper.debugReset();

      final upgraded = await DbHelper.instance.db;

      expect(await _indexNames(upgraded), containsAll(_expectedIndexes));
    });

    test('keeps the rows it already held', () async {
      final fresh = await DbHelper.instance.db;
      await fresh.insert('players', {'name': 'Nik', 'uuid': 'u-1'});
      for (final name in await _indexNames(fresh)) {
        await fresh.execute('DROP INDEX $name');
      }
      await fresh.execute('PRAGMA user_version = 18');
      await DbHelper.debugReset();

      final players = await DbHelper.instance.getPlayers();

      expect(players.map((p) => p.name), ['Nik']);
    });
  });
}
