import 'package:dartscore_app/models/dart_throw.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a throw with just the fields the resume and perfect-leg maths read.
DartThrow _t({
  required int playerId,
  required int leg,
  required int set,
  int dartsUsed = 3,
  int score = 60,
}) =>
    DartThrow(
      gameId: 1,
      playerId: playerId,
      score: score,
      dartsUsed: dartsUsed,
      leg: leg,
      set: set,
      remainingBefore: 501,
      thrownAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      bust: false,
    );

void main() {
  group('currentLegAndSet', () {
    test('falls back to leg 1 / set 1 without throws', () {
      expect(currentLegAndSet(const []), (leg: 1, set: 1));
    });

    test('reports the highest leg of a single-set game', () {
      final throws = [
        _t(playerId: 1, leg: 1, set: 1),
        _t(playerId: 1, leg: 2, set: 1),
        _t(playerId: 2, leg: 2, set: 1),
      ];

      expect(currentLegAndSet(throws), (leg: 2, set: 1));
    });

    test('does not carry a leg number over from an earlier set', () {
      // Set 1 ran to leg 3 and was won; set 2 has just started at leg 1.
      final throws = [
        _t(playerId: 1, leg: 1, set: 1),
        _t(playerId: 1, leg: 2, set: 1),
        _t(playerId: 1, leg: 3, set: 1),
        _t(playerId: 1, leg: 1, set: 2),
      ];

      // Taking both maxima independently would report leg 3 of set 2, a
      // leg/set pair without a single throw.
      expect(currentLegAndSet(throws), (leg: 1, set: 2));
    });

    test('reports the highest leg within the highest set', () {
      final throws = [
        _t(playerId: 1, leg: 5, set: 1),
        _t(playerId: 1, leg: 1, set: 2),
        _t(playerId: 1, leg: 2, set: 2),
      ];

      expect(currentLegAndSet(throws), (leg: 2, set: 2));
    });
  });

  group('legDartsUsed', () {
    test('counts only the given leg and set', () {
      final throws = [
        _t(playerId: 1, leg: 1, set: 1, dartsUsed: 3),
        _t(playerId: 1, leg: 2, set: 1, dartsUsed: 3),
        _t(playerId: 1, leg: 1, set: 2, dartsUsed: 3),
      ];

      expect(legDartsUsed(throws, 1, 1, playerId: 1), 3);
    });

    test('counts a nine darter as nine, not twelve', () {
      // Three full visits, the third one being the checkout that is already
      // part of the history when the perfect-leg check runs.
      final throws = [
        _t(playerId: 1, leg: 1, set: 1, dartsUsed: 3),
        _t(playerId: 1, leg: 1, set: 1, dartsUsed: 3),
        _t(playerId: 1, leg: 1, set: 1, dartsUsed: 3),
      ];

      final darts = legDartsUsed(throws, 1, 1, playerId: 1);

      expect(darts, 9);
      expect(darts <= minimumDartsForScore[501]!, isTrue);
    });

    test('ignores other players in an individual game', () {
      final throws = [
        _t(playerId: 1, leg: 1, set: 1, dartsUsed: 3),
        _t(playerId: 2, leg: 1, set: 1, dartsUsed: 3),
      ];

      expect(legDartsUsed(throws, 1, 1, playerId: 1), 3);
    });

    test('counts every member of a team slot when no player is given', () {
      final throws = [
        _t(playerId: 1, leg: 1, set: 1, dartsUsed: 3),
        _t(playerId: 2, leg: 1, set: 1, dartsUsed: 3),
      ];

      expect(legDartsUsed(throws, 1, 1), 6);
    });
  });
}
