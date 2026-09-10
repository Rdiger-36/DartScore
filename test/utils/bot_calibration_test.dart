import 'dart:math';

import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/utils/bot_strategy_x01.dart';
import 'package:dartscore_app/utils/bot_thrower.dart';
import 'package:dartscore_app/utils/dartboard_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three-dart average each tier is meant to play, and the band it may
/// drift in. These numbers are what the tier names promise, so a change to
/// `scatterOf` that moves one out of its band is a change to the product.
const _expected = <BotLevel, ({double average, double tolerance})>{
  BotLevel.rookie:  (average: 35,  tolerance: 4),
  BotLevel.amateur: (average: 50,  tolerance: 4),
  BotLevel.semiPro: (average: 65,  tolerance: 4),
  BotLevel.pro:     (average: 85,  tolerance: 4),
  BotLevel.legend:  (average: 100, tolerance: 4),
};

/// Plays [legs] legs of 501 double-out for one bot and returns its three-dart
/// average over all of them, busts counted as zero the way `ThrowStats`
/// counts them.
({double average, int darts}) _play(BotLevel level, int legs, Random rng) {
  final thrower = BotThrower(rng: rng);
  var scored = 0;
  var darts  = 0;

  for (var leg = 0; leg < legs; leg++) {
    var remaining = 501;
    while (remaining > 0) {
      var visitScore = 0;
      var bust = false;
      for (var dart = 0; dart < 3; dart++) {
        final target = x01Target(
            remaining: remaining - visitScore,
            dartsLeft: 3 - dart,
            checkedIn: true);
        final hit = thrower.throwAt(target, level);
        darts++;
        visitScore += scoreOf(hit);
        final left = remaining - visitScore;
        if (left < 0 || left == 1 || (left == 0 && hit.multiplier != 2)) {
          bust = true;
          break;
        }
        if (left == 0) break;
      }
      if (!bust) {
        scored    += visitScore;
        remaining -= visitScore;
      }
    }
  }
  return (average: scored / darts * 3, darts: darts);
}

void main() {
  group('the tiers play the averages their names promise', () {
    for (final entry in _expected.entries) {
      test('${entry.key.name} averages about ${entry.value.average}', () {
        final result = _play(entry.key, 300, Random(20260910));

        expect(result.average,
            closeTo(entry.value.average, entry.value.tolerance),
            reason: '${entry.key.name} over ${result.darts} darts');
      });
    }

    test('each tier is better than the one below it', () {
      final averages = [
        for (final level in BotLevel.values)
          _play(level, 100, Random(7)).average,
      ];
      for (var i = 1; i < averages.length; i++) {
        expect(averages[i], greaterThan(averages[i - 1]));
      }
    });
  });
}
