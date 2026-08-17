import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/utils/finish_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinishCalculator.getRoutes - favorite double alternative', () {
    test('alternative leads to the favorite double when primary does not', () {
      final routes = FinishCalculator.getRoutes(100, 'D16');

      expect(routes.primary, ['T20', 'D20']);
      expect(routes.alternative, ['T20', 'S8', 'D16']);
    });

    test('keeps the existing alternative when primary already finishes on '
        'the favorite double', () {
      final routes = FinishCalculator.getRoutes(125, 'D20');

      expect(routes.primary, ['Bull', 'T15', 'D20']);
      expect(routes.alternative, ['T20', 'T15', 'D10']);
    });

    test('offers a favorite-double route as a hint when no checkout fits '
        'the remaining darts this turn', () {
      final routes = FinishCalculator.getRoutes(
        55,
        'D8',
        maxDarts: 1,
      );

      expect(routes.primary, isNull);
      expect(routes.alternative, ['T13', 'D8']);
    });

    test('returns no alternative when no favorite-double route exists '
        'within 3 darts', () {
      final routes = FinishCalculator.getRoutes(
        170,
        'D8',
        maxDarts: 1,
        checkoutMode: CheckoutMode.doubleOut,
      );

      expect(routes.primary, isNull);
      expect(routes.alternative, isNull);
    });
  });

  group('FinishCalculator.canFinishWithOneDart', () {
    bool can(int remaining, CheckoutMode mode) =>
        FinishCalculator.canFinishWithOneDart(remaining, mode);

    test('double-out finishes on a double or the bull only', () {
      const mode = CheckoutMode.doubleOut;

      expect(can(2, mode),  isTrue);
      expect(can(16, mode), isTrue);
      expect(can(40, mode), isTrue);
      expect(can(50, mode), isTrue);

      expect(can(1, mode),  isFalse, reason: 'no dart scores 1 on a double');
      expect(can(15, mode), isFalse, reason: 'odd');
      expect(can(25, mode), isFalse, reason: 'the outer bull is a single');
      expect(can(41, mode), isFalse);
      expect(can(42, mode), isFalse, reason: 'even but above D20');
      expect(can(60, mode), isFalse, reason: 'T20 is not a double');
    });

    test('master-out adds the triples and the outer bull', () {
      const mode = CheckoutMode.masterOut;

      expect(can(3, mode),  isTrue);
      expect(can(40, mode), isTrue);
      expect(can(42, mode), isTrue, reason: 'T14');
      expect(can(60, mode), isTrue, reason: 'T20');
      expect(can(25, mode), isTrue, reason: 'the outer bull counts as a single');
      expect(can(50, mode), isTrue);

      expect(can(1, mode),  isFalse);
      expect(can(41, mode), isFalse);
      expect(can(61, mode), isFalse);
    });

    test('straight-out finishes on any single dart that hits the number', () {
      const mode = CheckoutMode.straightOut;

      expect(can(1, mode),  isTrue,  reason: 'S1');
      expect(can(20, mode), isTrue);
      expect(can(22, mode), isTrue,  reason: 'D11');
      expect(can(25, mode), isTrue);
      expect(can(42, mode), isTrue,  reason: 'T14');
      expect(can(50, mode), isTrue);
      expect(can(60, mode), isTrue);

      expect(can(23, mode), isFalse, reason: 'no single dart scores 23');
      expect(can(41, mode), isFalse);
      expect(can(61, mode), isFalse);
    });

    test('a remaining of zero or less is never one dart away', () {
      for (final mode in CheckoutMode.values) {
        expect(can(0, mode),  isFalse);
        expect(can(-3, mode), isFalse);
      }
    });
  });
}
