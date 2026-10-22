import 'package:dartscore_app/utils/dartboard_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the colors painted on the board', () {
    test('matches the example the Capital rules give', () {
      // "20-19-treble 20 => black-white-red" is the worked example for the
      // Color contract, and it pins both halves of the alternation at once.
      expect(colorOf((field: 20, multiplier: 1)), BoardColor.black);
      expect(colorOf((field: 19, multiplier: 1)), BoardColor.white);
      expect(colorOf((field: 20, multiplier: 3)), BoardColor.red);
    });

    test('alternates black and white around the singles', () {
      for (var index = 0; index < dartboardSegmentOrder.length; index++) {
        final field = dartboardSegmentOrder[index];
        expect(
          colorOf((field: field, multiplier: 1)),
          index.isEven ? BoardColor.black : BoardColor.white,
          reason: 'single $field at index $index',
        );
      }
    });

    test('alternates red and green over the doubles and the trebles', () {
      for (var index = 0; index < dartboardSegmentOrder.length; index++) {
        final field = dartboardSegmentOrder[index];
        final expected = index.isEven ? BoardColor.red : BoardColor.green;
        expect(colorOf((field: field, multiplier: 2)), expected,
            reason: 'double $field at index $index');
        expect(colorOf((field: field, multiplier: 3)), expected,
            reason: 'treble $field at index $index');
      }
    });

    test('gives a sector the same color in both of its multiplied rings', () {
      for (final field in dartboardSegmentOrder) {
        expect(colorOf((field: field, multiplier: 2)),
            colorOf((field: field, multiplier: 3)),
            reason: 'field $field');
      }
    });

    test('paints the inner bull red inside the green outer bull', () {
      expect(colorOf((field: 25, multiplier: 2)), BoardColor.red);
      expect(colorOf((field: 25, multiplier: 1)), BoardColor.green);
    });

    test('gives a miss no color', () {
      expect(colorOf(boardMiss), isNull);
    });

    test('uses every one of the four colors', () {
      final seen = <BoardColor>{};
      for (final field in dartboardSegmentOrder) {
        for (final multiplier in [1, 2, 3]) {
          seen.add(colorOf((field: field, multiplier: multiplier))!);
        }
      }
      expect(seen, BoardColor.values.toSet());
    });
  });

  group('sectors that touch each other', () {
    test('accepts the example the Capital rules give', () {
      // 16, 7 and 19 sit next to each other, which the order shows in reverse.
      expect(areAdjacentSectors([16, 7, 19]), isTrue);
    });

    test('ignores the order the fields are given in', () {
      expect(areAdjacentSectors([19, 7, 16]), isTrue);
      expect(areAdjacentSectors([7, 19, 16]), isTrue);
    });

    test('lets an arc cross the top of the board', () {
      // The 12 and the 5 end the order and the 20 begins it again.
      expect(areAdjacentSectors([12, 5, 20]), isTrue);
      expect(areAdjacentSectors([5, 20, 1]), isTrue);
    });

    test('rejects consecutive numbers that sit apart on the board', () {
      // The Run contract wants 20, 19, 18. The Side contract must not take it.
      expect(areAdjacentSectors([20, 19, 18]), isFalse);
    });

    test('rejects a gap in the arc', () {
      // 20 and 18 are both neighbours of the 1, but skipping it is not an arc.
      expect(areAdjacentSectors([20, 18, 4]), isFalse);
    });

    test('rejects a repeated field', () {
      expect(areAdjacentSectors([20, 20, 1]), isFalse);
    });

    test('rejects the bull and a miss, which are not sectors', () {
      expect(areAdjacentSectors([20, 1, 25]), isFalse);
      expect(areAdjacentSectors([20, 1, 0]), isFalse);
    });

    test('works for counts other than three', () {
      expect(areAdjacentSectors([20]), isTrue);
      expect(areAdjacentSectors([20, 1]), isTrue);
      expect(areAdjacentSectors([20, 18]), isFalse);
      expect(areAdjacentSectors([20, 1, 18, 4]), isTrue);
      expect(areAdjacentSectors([]), isFalse);
    });

    test('accepts every arc of three the board holds', () {
      final order = dartboardSegmentOrder;
      for (var start = 0; start < order.length; start++) {
        final arc = [
          order[start],
          order[(start + 1) % order.length],
          order[(start + 2) % order.length],
        ];
        expect(areAdjacentSectors(arc), isTrue, reason: '$arc');
      }
    });
  });
}
