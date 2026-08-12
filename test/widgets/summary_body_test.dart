import 'package:dartscore_app/utils/layout.dart';
import 'package:dartscore_app/widgets/summary_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The body every post-game summary is laid out by: one column, or two with the
/// way out under both.
void main() {
  group('a summary body', () {
    /// Renders a stand-in summary at [size]: one card of result, one of detail
    /// and a button out.
    Future<void> pumpBody(WidgetTester tester, Size size) async {
      usePhoneSurface(tester, size: size);
      await tester.pumpWidget(testApp(Scaffold(
        body: SummaryBody(
          result:  const [Card(child: SizedBox(height: 200, child: Text('won'))) ],
          details: const [Card(child: SizedBox(height: 200, child: Text('numbers')))],
          footer:  FilledButton(onPressed: () {}, child: const Text('home')),
        ),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('is one column on a phone, in the order it was given',
        (tester) async {
      await pumpBody(tester, const Size(400, 900));

      expect(find.byKey(kPaneDividerKey), findsNothing);
      expect(tester.getRect(find.text('won')).bottom,
          lessThan(tester.getRect(find.text('numbers')).top));
      expect(tester.getRect(find.text('numbers')).bottom,
          lessThan(tester.getRect(find.text('home')).top));
    });

    testWidgets('stays one column on a tablet held upright', (tester) async {
      // An iPad upright is 768 wide, which is two summary columns short of the
      // width they need.
      await pumpBody(tester, const Size(768, 1024));

      expect(find.byKey(kPaneDividerKey), findsNothing);
      expect(tester.getRect(find.text('won')).bottom,
          lessThan(tester.getRect(find.text('numbers')).top));
    });

    testWidgets('divides once there is room, with the way out under both',
        (tester) async {
      await pumpBody(tester, const Size(1180, 820));

      expect(find.byKey(kPaneDividerKey), findsOneWidget);
      expect(tester.getRect(find.text('numbers')).left,
          greaterThan(tester.getRect(find.text('won')).right));

      // Under both: below whichever column reaches furthest down.
      final button = tester.getRect(find.text('home'));
      for (final column in tester.widgetList(find.byType(ListView))) {
        expect(button.top,
            greaterThan(tester.getRect(find.byWidget(column)).bottom));
      }
      // And centred, rather than stretched across the whole window.
      expect(button.center.dx, closeTo(1180 / 2, 8));
    });
  });
}
