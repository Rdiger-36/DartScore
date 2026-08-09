import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Points [DbHelper] at a fresh in-memory SQLite database for every test in
/// the calling group, so provider tests exercise the real schema, the real
/// queries and the real replay path instead of a stand-in.
///
/// Call once inside a `group`, before the tests that need a database.
void useInMemoryDatabase() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DbHelper.debugDatabasePath = inMemoryDatabasePath;
  });

  setUp(() async {
    // A new connection means a new empty in-memory database, created through
    // DbHelper's own onCreate, so the tests run against the shipped schema.
    await DbHelper.debugReset();
  });

  tearDown(() async {
    await DbHelper.debugReset();
  });
}

/// Inserts [names] as players and returns them with their assigned ids, in the
/// given order.
Future<List<Player>> insertPlayers(List<String> names) async {
  final db = DbHelper.instance;
  final players = <Player>[];
  for (final name in names) {
    final id = await db.insertPlayer(Player(name: name));
    players.add(Player(id: id, name: name));
  }
  return players;
}
