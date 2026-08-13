import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/providers/players_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_db.dart';

void main() {
  group('PlayersProvider', () {
    useInMemoryDatabase();

    late PlayersProvider provider;

    setUp(() {
      provider = PlayersProvider();
    });

    test('starts out not loaded and empty', () {
      expect(provider.loaded, isFalse);
      expect(provider.players, isEmpty);
      expect(provider.primaryPlayer, isNull);
    });

    test('puts the primary player first and the rest in alphabetical order',
        () async {
      await provider.addPlayer('Zoe');
      await provider.addPlayer('Ada');
      final nik = await provider.addPlayer('Nik');
      await provider.setPrimary(nik);

      expect(provider.players.map((p) => p.name), ['Nik', 'Ada', 'Zoe']);
    });

    test('ignores case, so a lower case name is not exiled to the end',
        () async {
      // Ordering by code unit puts every capital ahead of every lower case
      // letter, which is how "anna" ends up behind "Zoe" in a list of names.
      await provider.addPlayer('Zoe');
      await provider.addPlayer('anna');
      await provider.addPlayer('Bob');

      expect(provider.players.map((p) => p.name), ['anna', 'Bob', 'Zoe']);
    });

    test('files the umlauts under their base letter', () async {
      // By code unit these all sort behind "Zoe", far up in the code space.
      await provider.addPlayer('Zoe');
      await provider.addPlayer('Ärger');
      await provider.addPlayer('Über');
      await provider.addPlayer('Öl');

      expect(provider.players.map((p) => p.name),
          ['Ärger', 'Öl', 'Über', 'Zoe']);
    });

    test('treats ß as ss', () async {
      await provider.addPlayer('Strauss');
      await provider.addPlayer('Strauß');
      await provider.addPlayer('Straub');

      expect(provider.players.map((p) => p.name),
          ['Straub', 'Strauss', 'Strauß']);
    });

    test('sorts the same way after reloading from the database', () async {
      await provider.addPlayer('Zoe');
      await provider.addPlayer('Ada');
      final nik = await provider.addPlayer('Nik');
      await provider.setPrimary(nik);

      final reloaded = PlayersProvider();
      await reloaded.load();

      expect(reloaded.players.map((p) => p.name), ['Nik', 'Ada', 'Zoe']);
      expect(reloaded.loaded, isTrue);
    });

    test('leaves only one player primary when the flag moves', () async {
      final first = await provider.addPlayer('Ada');
      final second = await provider.addPlayer('Zoe');
      await provider.setPrimary(first);

      await provider.setPrimary(second);

      expect(provider.players.where((p) => p.isPrimary).map((p) => p.name),
          ['Zoe']);
      expect((await DbHelper.instance.getPrimaryPlayer())?.name, 'Zoe');
    });

    test('leaves only one player primary when a new one is added as primary',
        () async {
      final ada = await provider.addPlayer('Ada');
      await provider.setPrimary(ada);

      final zoe = await provider.addPlayer('Zoe', isPrimary: true);

      expect(provider.players.where((p) => p.isPrimary).map((p) => p.id),
          [zoe.id]);
      expect((await DbHelper.instance.getPrimaryPlayer())?.id, zoe.id);
      expect(provider.primaryPlayer?.id, zoe.id);
    });

    test('keeps a deleted player out of the list without losing the row',
        () async {
      final ada = await provider.addPlayer('Ada');
      await provider.addPlayer('Zoe');

      await provider.deletePlayer(ada.id!);

      expect(provider.players.map((p) => p.name), ['Zoe']);
      // Soft delete: the row survives so the games that reference it still
      // resolve, it is only kept out of every list.
      expect(await DbHelper.instance.getPlayer(ada.id!), isNotNull);
    });

    test('notifies on every change so the screens follow along', () async {
      var notifications = 0;
      provider.addListener(() => notifications++);

      final ada = await provider.addPlayer('Ada');
      await provider.setPrimary(ada);
      await provider.updatePlayer(ada.copyWith(name: 'Ada B'));
      await provider.deletePlayer(ada.id!);

      expect(notifications, 4);
    });

    test('renames a player in the list and in the database', () async {
      final ada = await provider.addPlayer('Ada');

      await provider.updatePlayer(ada.copyWith(name: 'Ada B'));

      expect(provider.players.single.name, 'Ada B');
      expect((await DbHelper.instance.getPlayer(ada.id!))?.name, 'Ada B');
    });

    test('looks a player up by id, and says so when there is none', () async {
      final ada = await provider.addPlayer('Ada');

      expect(provider.getById(ada.id!)?.name, 'Ada');
      expect(provider.getById(9999), isNull);
    });
  });
}
