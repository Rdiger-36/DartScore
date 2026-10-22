import 'package:dartscore_app/utils/bot_strategy_capital.dart';
import 'package:dartscore_app/utils/capital_rules.dart';
import 'package:dartscore_app/utils/dartboard_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

BoardHit single(int field) => (field: field, multiplier: 1);
BoardHit treble(int field) => (field: field, multiplier: 3);
const BoardHit innerBull = (field: 25, multiplier: 2);
const BoardHit maxPoints = (field: 20, multiplier: 3);

BoardHit aim(CapitalContract contract, [List<BoardHit> darts = const []]) =>
    capitalTarget(contract: contract, dartsSoFar: darts);

void main() {
  group('a bot building the capital', () {
    test('plays the treble twenty, where the points are', () {
      expect(aim(CapitalContract.capital), maxPoints);
    });
  });

  group('a bot on a sector contract', () {
    test('aims at the treble of the sector it needs', () {
      expect(aim(CapitalContract.seventeen), treble(17));
      expect(aim(CapitalContract.fourteen), treble(14));
    });

    test('switches to points once the sector is in the bag', () {
      expect(aim(CapitalContract.seventeen, [single(17)]), maxPoints);
    });
  });

  group('a bot on the ring contracts', () {
    test('takes the double twenty for a double and the bull for a center', () {
      expect(aim(CapitalContract.anyDouble), (field: 20, multiplier: 2));
      expect(aim(CapitalContract.center), innerBull);
    });

    test('plays for points once either is met', () {
      expect(aim(CapitalContract.anyDouble, [(field: 3, multiplier: 2)]), maxPoints);
      expect(aim(CapitalContract.center, [innerBull]), maxPoints);
      expect(aim(CapitalContract.anyTreble, [treble(5)]), maxPoints);
    });
  });

  group('a bot building a side', () {
    test('opens on the twenty', () {
      expect(aim(CapitalContract.side), maxPoints);
    });

    test('extends the arc to a sector that touches the first', () {
      final next = aim(CapitalContract.side, [treble(20)]);
      expect(areAdjacentSectors([20, next.field]), isTrue);
    });

    test('closes an arc of two from one of its ends', () {
      final next = aim(CapitalContract.side, [treble(20), treble(1)]);
      expect(areAdjacentSectors([20, 1, next.field]), isTrue);
    });

    test('plays for points when the darts can no longer make an arc', () {
      expect(aim(CapitalContract.side, [treble(20), treble(19)]), maxPoints);
    });
  });

  group('a bot building a run', () {
    test('opens on the twenty', () {
      expect(aim(CapitalContract.run), maxPoints);
    });

    test('takes a number next to the one it already hit', () {
      expect(aim(CapitalContract.run, [treble(20)]).field, 19);
    });

    test('closes a run of two', () {
      final next = aim(CapitalContract.run, [treble(20), treble(19)]);
      expect(next.field, 18);
    });

    test('fills the gap in a broken pair', () {
      expect(aim(CapitalContract.run, [treble(20), treble(18)]).field, 19);
    });

    test('does not try to wrap past the twenty', () {
      final next = aim(CapitalContract.run, [treble(20), treble(19)]);
      expect(next.field, isNot(1));
    });
  });

  group('a bot matching colors', () {
    test('opens on the red treble twenty', () {
      expect(colorOf(aim(CapitalContract.color)), BoardColor.red);
    });

    test('picks a color it has not used yet, each dart', () {
      final second = aim(CapitalContract.color, [treble(20)]);
      expect(colorOf(second), isNot(BoardColor.red));

      final third = aim(CapitalContract.color, [treble(20), second]);
      expect(colorOf(third), isNot(BoardColor.red));
      expect(colorOf(third), isNot(colorOf(second)));
    });
  });

  group('a bot chasing 57', () {
    test('takes the one dart that makes 57 outright', () {
      expect(aim(CapitalContract.fiftySeven), treble(19));
    });

    test('finishes the total exactly from what it has already thrown', () {
      // 19 thrown leaves 38, which is the double nineteen.
      expect(aim(CapitalContract.fiftySeven, [single(19)]),
          (field: 19, multiplier: 2));
    });

    test('leaves itself a remainder it can finish next dart', () {
      final first = aim(CapitalContract.fiftySeven, [single(1)]);
      final left = 57 - 1 - scoreOf(first);
      expect(left, greaterThan(0));
      expect(
        _allScores.contains(left),
        isTrue,
        reason: 'left $left should be reachable with one dart',
      );
    });
  });

  group('knowing when to stop', () {
    test('calls another dart harmful only once 57 is exact', () {
      expect(
        furtherDartsCanOnlyHurt(
            CapitalContract.fiftySeven, [single(19), (field: 19, multiplier: 2)]),
        isTrue,
      );
      expect(
        furtherDartsCanOnlyHurt(CapitalContract.fiftySeven, [single(19)]),
        isFalse,
      );
    });

    test('never asks any other contract to stop', () {
      for (final contract in CapitalContract.values) {
        if (contract == CapitalContract.fiftySeven) continue;
        expect(
          furtherDartsCanOnlyHurt(contract, [treble(20), treble(20), treble(20)]),
          isFalse,
          reason: '$contract',
        );
      }
    });
  });
}

/// Every total a single dart can score.
final Set<int> _allScores = {
  for (final field in dartboardSegmentOrder) ...[field, field * 2, field * 3],
  25,
  50,
};
