import 'dart:io';

import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/services/device_identity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A backup is the database file itself, so these run against a real file on
/// disk rather than an in-memory database: everything that can go wrong here
/// (the write-ahead log, the swap, a file that is not ours) only exists once
/// there is a file.
void main() {
  late Directory dir;
  late String dbPath;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DeviceIdentity.debugSetId(null);
    dir = await Directory.systemTemp.createTemp('dartscore_backup');
    dbPath = '${dir.path}/dartscore.db';
    DbHelper.debugDatabasePath = dbPath;
    await DbHelper.debugReset();
  });

  tearDown(() async {
    await DbHelper.debugReset();
    DbHelper.debugDatabasePath = null;
    DeviceIdentity.debugSetId(null);
    await dir.delete(recursive: true);
  });

  /// Writes a backup of the current database to its own file and returns the
  /// path, the way the export does.
  Future<String> writeBackup(String deviceId, {String name = 'backup.db'}) async {
    final source = await DbHelper.instance.prepareBackup(deviceId);
    final target = '${dir.path}/$name';
    await File(source).copy(target);
    return target;
  }

  group('reading a backup before anything is replaced', () {
    test('reports the device, the time and what it holds', () async {
      await DbHelper.instance.insertPlayer(Player(name: 'Ann'));
      await DbHelper.instance.insertPlayer(Player(name: 'Bob'));

      final path = await writeBackup('DEVICE0000000001');
      final info = await DbHelper.instance.inspectBackup(path);

      expect(info, isNotNull);
      expect(info!.deviceId, 'DEVICE0000000001');
      expect(info.playerCount, 2);
      expect(info.gameCount, 0);
      expect(info.schemaVersion, DbHelper.schemaVersion);
      expect(info.createdAt, isNotNull);
    });

    test('refuses a file that is not a database', () async {
      final path = '${dir.path}/notes.txt';
      await File(path).writeAsString('not a database');

      expect(await DbHelper.instance.inspectBackup(path), isNull);
    });

    test('refuses a database that is not this app', () async {
      final path = '${dir.path}/foreign.db';
      final foreign = await databaseFactory.openDatabase(path);
      await foreign.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY)');
      await foreign.close();

      expect(await DbHelper.instance.inspectBackup(path), isNull);
    });

    test('describes a file from a newer app version instead of failing',
        () async {
      final path = await writeBackup('DEVICE0000000001');
      final newer = await databaseFactory.openDatabase(path);
      await newer.execute('PRAGMA user_version = ${DbHelper.schemaVersion + 5}');
      await newer.close();

      final info = await DbHelper.instance.inspectBackup(path);

      expect(info, isNotNull);
      expect(info!.schemaVersion, greaterThan(DbHelper.schemaVersion));
    });
  });

  group('restoring', () {
    test('brings back what the backup held and drops what came after',
        () async {
      await DbHelper.instance.insertPlayer(Player(name: 'Ann'));
      final path = await writeBackup('DEVICE0000000001');

      await DbHelper.instance.insertPlayer(Player(name: 'Later'));
      expect((await DbHelper.instance.getPlayers()).length, 2);

      await DbHelper.instance.replaceDatabase(path);

      final players = await DbHelper.instance.getPlayers();
      expect(players.map((p) => p.name), ['Ann']);
    });

    test('leaves nothing of the old database beside the new one', () async {
      await DbHelper.instance.insertPlayer(Player(name: 'Ann'));
      final path = await writeBackup('DEVICE0000000001');

      // A write-ahead log left over from the replaced database would be
      // applied on top of the restored file.
      await File('$dbPath-wal').writeAsBytes([0, 1, 2, 3]);
      await File('$dbPath-shm').writeAsBytes([0, 1, 2, 3]);

      await DbHelper.instance.replaceDatabase(path);

      expect(await File('$dbPath-wal').exists(), isFalse);
      expect(await File('$dbPath-shm').exists(), isFalse);
      expect(await File('$dbPath.replaced').exists(), isFalse);
    });

    test('keeps the current data when the file cannot be copied', () async {
      await DbHelper.instance.insertPlayer(Player(name: 'Ann'));

      await expectLater(
        DbHelper.instance.replaceDatabase('${dir.path}/gone.db'),
        throwsA(isA<Exception>()),
      );

      expect((await DbHelper.instance.getPlayers()).map((p) => p.name), ['Ann']);
    });
  });

  group('the device identity in a backup', () {
    test('is taken over, so restored games stay attributed', () async {
      await DeviceIdentity.adopt('DEVICE0000000001');
      expect(await DeviceIdentity.id, 'DEVICE0000000001');

      // A second device reads the backup back in.
      DeviceIdentity.debugSetId(null);
      SharedPreferences.setMockInitialValues({});
      final other = await DeviceIdentity.id;
      expect(other, isNot('DEVICE0000000001'));

      await DeviceIdentity.adopt('DEVICE0000000001');
      DeviceIdentity.debugSetId(null);

      expect(await DeviceIdentity.id, 'DEVICE0000000001');
    });
  });
}
