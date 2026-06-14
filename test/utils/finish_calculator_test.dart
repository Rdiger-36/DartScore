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
}
