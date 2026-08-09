import 'package:dartscore_app/models/dart_throw.dart';
import 'package:dartscore_app/utils/throw_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single visit; everything that is not under test gets a harmless default.
DartThrow _visit(
  int score, {
  int remainingBefore = 501,
  int dartsUsed = 3,
  int leg = 1,
  int set = 1,
  int playerId = 1,
  bool bust = false,
}) =>
    DartThrow(
      gameId:          1,
      playerId:        playerId,
      score:           score,
      dartsUsed:       dartsUsed,
      leg:             leg,
      set:             set,
      remainingBefore: remainingBefore,
      thrownAt:        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      bust:            bust,
    );

void main() {
  group('ThrowStats.fromThrows', () {
    test('an empty list yields zeros instead of NaN', () {
      final s = ThrowStats.fromThrows([]);

      expect(s.totalVisits, 0);
      expect(s.totalDarts, 0);
      expect(s.totalScored, 0);
      expect(s.highestVisit, 0);
      expect(s.average, 0);
      expect(s.first9Average, 0);
      expect(s.bustRate, 0);
      expect(s.checkoutRate, 0);
      expect(s.scoreStdDev, 0);
    });

    test('a bust adds darts but no score', () {
      final s = ThrowStats.fromThrows([
        _visit(140),
        _visit(180, remainingBefore: 361, bust: true),
      ]);

      expect(s.totalVisits, 2);
      expect(s.totalDarts, 6);
      expect(s.totalScored, 140);
      expect(s.busts, 1);
      expect(s.highestVisit, 140, reason: 'the busted 180 does not count');
      expect(s.count180, 0);
      expect(s.count140plus, 1);
      expect(s.average, closeTo(70, 0.001));
      expect(s.bustRate, closeTo(50, 0.001));
    });

    test('a busted visit from a finishable remaining is still an attempt', () {
      final s = ThrowStats.fromThrows([
        _visit(60, remainingBefore: 41, bust: true),
      ]);

      expect(s.checkoutAttempts, 1);
      expect(s.checkoutSuccesses, 0);
      expect(s.coAttemptSub60, 1);
      expect(s.coSuccessSub60, 0);
      expect(s.highestCheckout, 0);
    });

    test('a finishing visit counts as attempt and success', () {
      final s = ThrowStats.fromThrows([
        _visit(101, remainingBefore: 101, dartsUsed: 2),
        _visit(40, remainingBefore: 40),
      ]);

      expect(s.checkoutAttempts, 2);
      expect(s.checkoutSuccesses, 2);
      expect(s.highestCheckout, 101);
      expect(s.checkoutRate, closeTo(100, 0.001));
    });

    test('checkout ranges split at 40, 60, 100 and 170', () {
      final s = ThrowStats.fromThrows([
        _visit(0, remainingBefore: 40),
        _visit(0, remainingBefore: 41),
        _visit(0, remainingBefore: 60),
        _visit(0, remainingBefore: 61),
        _visit(0, remainingBefore: 100),
        _visit(0, remainingBefore: 101),
        _visit(0, remainingBefore: 170),
        _visit(0, remainingBefore: 171),
      ]);

      expect(s.checkoutAttempts, 7, reason: '171 is not finishable');
      expect(s.coAttemptSub40, 1);
      expect(s.coAttemptSub60, 2);
      expect(s.coAttemptSub100, 2);
      expect(s.coAttemptSub170, 2);
    });

    test('score thresholds are inclusive', () {
      final s = ThrowStats.fromThrows([
        _visit(180),
        _visit(140),
        _visit(139),
        _visit(100),
        _visit(99),
      ]);

      expect(s.count180, 1);
      expect(s.count140plus, 2, reason: '180 and 140');
      expect(s.count100plus, 4, reason: '180, 140, 139 and 100');
    });

    group('first 9', () {
      test('takes only the opening three visits of a leg', () {
        final s = ThrowStats.fromThrows([
          _visit(60),
          _visit(60),
          _visit(60),
          _visit(180),
          _visit(180),
        ]);

        expect(s.first9Darts, 9);
        expect(s.first9Scored, 180);
        expect(s.first9Average, closeTo(60, 0.001));
      });

      test('sums the opening visits of every leg', () {
        final s = ThrowStats.fromThrows([
          _visit(60, leg: 1),
          _visit(60, leg: 1),
          _visit(60, leg: 1),
          _visit(100, leg: 2),
          _visit(100, leg: 2),
          _visit(100, leg: 2),
          _visit(20, leg: 2),
        ]);

        expect(s.first9Darts, 18);
        expect(s.first9Scored, 480);
      });

      test('keeps legs of the same number apart across sets', () {
        final s = ThrowStats.fromThrows([
          _visit(60, leg: 1, set: 1),
          _visit(60, leg: 1, set: 1),
          _visit(60, leg: 1, set: 1),
          _visit(100, leg: 1, set: 2),
        ]);

        expect(s.first9Darts, 12);
        expect(s.first9Scored, 280);
      });

      test('counts a short finishing visit with its real dart count', () {
        final s = ThrowStats.fromThrows([
          _visit(180, remainingBefore: 501),
          _visit(180, remainingBefore: 321),
          _visit(141, remainingBefore: 141, dartsUsed: 3),
        ]);

        expect(s.first9Darts, 9);
        expect(s.first9Scored, 501);
        expect(s.first9Average, closeTo(167, 0.001));
      });

      test('a bust among the opening visits contributes darts but no score', () {
        final s = ThrowStats.fromThrows([
          _visit(60),
          _visit(60, bust: true),
          _visit(60),
        ]);

        expect(s.first9Darts, 9);
        expect(s.first9Scored, 120);
      });
    });

    test('standard deviation ignores busts', () {
      final even = ThrowStats.fromThrows([
        _visit(60),
        _visit(60),
        _visit(60),
      ]);
      expect(even.scoreStdDev, closeTo(0, 0.001));

      final spread = ThrowStats.fromThrows([
        _visit(100),
        _visit(20),
      ]);
      expect(spread.scoreStdDev, closeTo(40, 0.001));
    });
  });

  group('filters', () {
    test('throwsInLeg keeps only the given leg of the given set, in order', () {
      final throws = [
        _visit(1, leg: 1, set: 1),
        _visit(2, leg: 2, set: 1),
        _visit(3, leg: 1, set: 2),
        _visit(4, leg: 1, set: 1),
      ];

      expect(throwsInLeg(throws, 1, 1).map((t) => t.score), [1, 4]);
      expect(throwsInLeg(throws, 1, 2).map((t) => t.score), [3]);
      expect(throwsInLeg(throws, 3, 1), isEmpty);
    });

    test('throwsOfPlayer keeps only that player, in order', () {
      final throws = [
        _visit(1, playerId: 7),
        _visit(2, playerId: 8),
        _visit(3, playerId: 7),
      ];

      expect(throwsOfPlayer(throws, 7).map((t) => t.score), [1, 3]);
      expect(throwsOfPlayer(throws, 9), isEmpty);
    });
  });
}
