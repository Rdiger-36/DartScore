import 'package:dartscore_app/models/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Game handicap persistence', () {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    test('round-trips per-player handicaps through the row map', () {
      final game = Game(
        startScore: 501,
        createdAt: createdAt,
        handicaps: {
          7: const PlayerHandicap(
              checkIn: GameMode.doubleIn, checkOut: CheckoutMode.masterOut),
          9: const PlayerHandicap(checkIn: GameMode.masterIn),
        },
      );

      final restored = Game.fromMap(game.toMap());

      expect(restored.handicaps!.keys, containsAll([7, 9]));
      expect(restored.handicaps![7]!.checkIn, GameMode.doubleIn);
      expect(restored.handicaps![7]!.checkOut, CheckoutMode.masterOut);
      expect(restored.handicaps![9]!.checkIn, GameMode.masterIn);
      expect(restored.handicaps![9]!.checkOut, CheckoutMode.doubleOut);
    });

    test('stores no handicap json for a game without handicaps', () {
      final game = Game(startScore: 501, createdAt: createdAt);

      expect(game.toMap()['handicap_json'], isNull);
      expect(game.hasHandicaps, isFalse);
      expect(Game.fromMap(game.toMap()).handicaps, isNull);
    });

    test('reads rows written before the handicap column existed', () {
      final map = Game(startScore: 301, createdAt: createdAt).toMap()
        ..remove('handicap_json');

      final restored = Game.fromMap(map);

      expect(restored.handicaps, isNull);
      expect(restored.hasHandicaps, isFalse);
    });

    test('falls back to the game defaults for players without a handicap', () {
      final game = Game(
        startScore: 501,
        gameMode: GameMode.straightIn,
        checkoutMode: CheckoutMode.doubleOut,
        createdAt: createdAt,
        handicaps: {
          7: const PlayerHandicap(
              checkIn: GameMode.doubleIn, checkOut: CheckoutMode.masterOut),
        },
      );

      expect(game.checkInFor(7), GameMode.doubleIn);
      expect(game.checkOutFor(7), CheckoutMode.masterOut);
      expect(game.checkInFor(9), GameMode.straightIn);
      expect(game.checkOutFor(9), CheckoutMode.doubleOut);
      expect(game.checkInFor(null), GameMode.straightIn);
    });

    test('carries handicaps through copyWith', () {
      final game = Game(
        startScore: 501,
        createdAt: createdAt,
        handicaps: {7: const PlayerHandicap(checkIn: GameMode.doubleIn)},
      );

      final finished = game.copyWith(finishedAt: createdAt);

      expect(finished.handicaps![7]!.checkIn, GameMode.doubleIn);
    });
  });
}
