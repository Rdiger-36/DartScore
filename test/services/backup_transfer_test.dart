import 'dart:io';

import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/services/backup_service.dart';
import 'package:dartscore_app/services/device_identity.dart';
import 'package:dartscore_app/services/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Handing the whole database to another device over the local network.
///
/// Deliberately without `TestWidgetsFlutterBinding`: that binding answers every
/// HTTP request with a 400 instead of letting one out, and these drive a real
/// socket. The device id is pinned rather than read, so nothing here needs
/// shared_preferences and therefore no binding either.
void main() {
  late Directory dir;
  late SyncServer server;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dartscore_transfer');
    DbHelper.debugDatabasePath = '${dir.path}/dartscore.db';
    await DbHelper.debugReset();
    DeviceIdentity.debugSetId('SENDER0000000001');
    server = SyncServer();
  });

  tearDown(() async {
    await server.stop();
    server.dispose();
    await DbHelper.debugReset();
    DbHelper.debugDatabasePath = null;
    DeviceIdentity.debugSetId(null);
    await dir.delete(recursive: true);
  });

  /// Waits for the server to reach [state], or fails.
  Future<void> until(SyncServerState state) async {
    for (var i = 0; i < 250; i++) {
      if (server.state.value == state) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('the server never reached $state');
  }

  /// Where the peer connects, on loopback whatever address was reported.
  SyncConnection loopback(SyncConnection c) =>
      SyncConnection('127.0.0.1', c.port, c.token);

  test('the peer gets a database it can actually read', () async {
    final id = await DbHelper.instance.insertPlayer(Player(name: 'Ann'));
    await DbHelper.instance.insertPlayer(Player(name: 'Bob'));

    final connection = await server.start(
      await BackupService.exportBytes(),
      twoWay: false,
      contentType: ContentType.binary,
      codePrefix: kBackupWifiPrefix,
    );
    expect(connection.qrPayload, startsWith(kBackupWifiPrefix));

    final fetch = SyncClient().fetchBytes(loopback(connection));
    await until(SyncServerState.pending);
    server.approve();

    final bytes = await fetch;
    await until(SyncServerState.served);

    // Readable as a database on the far side, not merely the right number of
    // bytes. A transfer that arrives corrupt would replace a device with
    // nothing.
    final incoming = '${dir.path}/incoming.db';
    await File(incoming).writeAsBytes(bytes, flush: true);

    final info = await DbHelper.instance.inspectBackup(incoming);
    expect(info, isNotNull);
    expect(info!.playerCount, 2);
    expect(info.deviceId, 'SENDER0000000001',
        reason: 'the receiver has to know which device played what it is '
            'about to take on');
    expect(id, isPositive);
  });

  test('nothing can be pushed back down the same connection', () async {
    final connection = await server.start(
      await BackupService.exportBytes(),
      twoWay: false,
      codePrefix: kBackupWifiPrefix,
    );

    final client = SyncClient();
    final fetch = client.fetchBytes(loopback(connection));
    await until(SyncServerState.pending);
    server.approve();
    await fetch;

    // A database replaces the device that takes it, so there is nothing it
    // could hand back and the door shuts behind the transfer.
    await expectLater(
      client.post(loopback(connection), 'anything'),
      throwsA(isA<Exception>()),
    );
    expect(server.state.value, SyncServerState.served);
  });

  test('a declined transfer hands over nothing', () async {
    final connection = await server.start(
      await BackupService.exportBytes(),
      twoWay: false,
      codePrefix: kBackupWifiPrefix,
    );

    final fetch = SyncClient().fetchBytes(loopback(connection));
    await until(SyncServerState.pending);
    server.reject();

    await expectLater(fetch, throwsA(isA<SyncRejectedException>()));
  });

  test('a profile sync code is not a database code', () {
    final syncCode = SyncConnection('10.0.0.5', 1234, 'TOKEN').qrPayload;
    final backupCode = SyncConnection('10.0.0.5', 1234, 'TOKEN',
            prefix: kBackupWifiPrefix)
        .qrPayload;

    // The two do opposite things, one merges and one replaces, so a code for
    // the wrong screen has to fail rather than half work.
    expect(SyncConnection.parse(syncCode, prefix: kBackupWifiPrefix), isNull);
    expect(SyncConnection.parse(backupCode), isNull);
    expect(SyncConnection.parse(syncCode), isNotNull);
    expect(SyncConnection.parse(backupCode, prefix: kBackupWifiPrefix),
        isNotNull);
  });
}
