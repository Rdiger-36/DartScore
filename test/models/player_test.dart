import 'package:dartscore_app/models/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a computer opponent as a player', () {
    test('round-trips its tier through the row map', () {
      final bot = Player(
        name:     BotLevel.semiPro.storedName,
        uuid:     BotLevel.semiPro.uuid,
        botLevel: BotLevel.semiPro,
      );

      final back = Player.fromMap(bot.toMap());

      expect(back.isBot, isTrue);
      expect(back.botLevel, BotLevel.semiPro);
      expect(back.name, 'Bot Semi-Pro');
      expect(back.uuid, BotLevel.semiPro.uuid);
    });

    test('is a person when the column is null or missing', () {
      final human = Player(name: 'Ada');

      expect(human.isBot, isFalse);
      expect(human.toMap()['bot_level'], isNull);
      expect(Player.fromMap({'name': 'Ada'}).botLevel, isNull);
    });

    test('keeps its tier through copyWith', () {
      final bot = Player(name: 'Bot Pro', botLevel: BotLevel.pro);

      expect(bot.copyWith(id: 7).botLevel, BotLevel.pro);
      expect(bot.copyWith(favoriteDoubles: 'D16').isBot, isTrue);
    });
  });

  group('the bot tiers', () {
    test('store their index, weakest first, so the order is part of the schema',
        () {
      expect(BotLevel.values.first, BotLevel.rookie);
      expect(BotLevel.values.last, BotLevel.legend);
      expect(BotLevel.pro.index, 3);
    });

    test('each have a uuid of their own that no generator produces', () {
      final uuids = BotLevel.values.map((l) => l.uuid).toSet();

      expect(uuids.length, BotLevel.values.length);
      for (final u in uuids) {
        expect(u, matches(RegExp(r'^0{8}-0{4}-4000-8000-0{9}b\d{2}$')));
      }
      // A generated uuid never starts with eight zeros, or the tiers could
      // collide with a person made on some other device.
      expect(Player(name: 'x').uuid, isNot(startsWith('00000000-')));
    });
  });
}
