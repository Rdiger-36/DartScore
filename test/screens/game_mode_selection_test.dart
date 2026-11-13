import 'package:dartscore_app/providers/tablet_layout_provider.dart';
import 'package:dartscore_app/screens/game_mode_info_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
import 'package:dartscore_app/screens/game_mode_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';

/// The mode selection on a phone and on a tablet. No test opens a setup: that
/// screen reads the roster from the database, which is not what is under test.
void main() {
  late TabletLayoutProvider layout;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    layout = TabletLayoutProvider();
  });

  /// Pumps the selection on a surface of [size].
  Future<void> pumpSelection(WidgetTester tester, Size size,
      {EdgeInsets safeArea = EdgeInsets.zero}) async {
    usePhoneSurface(tester, size: size, safeArea: safeArea);
    await tester.pumpWidget(
      ChangeNotifierProvider<TabletLayoutProvider>.value(
        value: layout,
        child: testApp(const GameModeSelectionScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The vertical position of the one widget showing [text].
  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  group('on a phone', () {
    testWidgets('lists every mode under the heading of its category',
        (tester) async {
      await pumpSelection(tester, const Size(400, 900));

      final order = [
        'MATCH', 'X01', 'Cricket',
        'PARTY', 'Shanghai', 'Capital',
        'TRAINING', 'Around the Clock', 'Checkout Ladder',
      ];
      for (var i = 1; i < order.length; i++) {
        expect(topOf(tester, order[i - 1]), lessThan(topOf(tester, order[i])),
            reason: '${order[i - 1]} sits above ${order[i]}');
      }
    });

    testWidgets('centres the list where the screen is taller than it',
        (tester) async {
      await pumpSelection(tester, const Size(400, 2400));

      final list = tester.getRect(find.byType(CustomScrollView));
      expect(list.center.dy, closeTo((kToolbarHeight + 2400) / 2, 1));
    });

    testWidgets('starts a list longer than the screen at the top',
        (tester) async {
      await pumpSelection(tester, const Size(375, 667));

      final list = tester.getRect(find.byType(CustomScrollView));
      expect(list.top, closeTo(kToolbarHeight, 1));
      expect(list.bottom, closeTo(667, 1));
    });

    testWidgets('keeps the heading of the category being read at the top',
        (tester) async {
      await pumpSelection(tester, const Size(375, 667));
      final top = tester.getTopLeft(find.byType(CustomScrollView)).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      // Whichever category the top card belongs to, its heading is the one
      // held there; the ones above it have been pushed out of the list.
      final headings = ['MATCH', 'PARTY', 'TRAINING']
          .where((text) => find.text(text).evaluate().isNotEmpty)
          .map((text) => topOf(tester, text))
          .where((dy) => dy >= top);
      expect(headings.reduce((a, b) => a < b ? a : b), closeTo(top + 10, 1));
      expect(find.text('Checkout Ladder'), findsOneWidget);
    });

    testWidgets('shows no rules until the info button opens them',
        (tester) async {
      await pumpSelection(tester, const Size(400, 900));
      expect(find.byType(GameModeInfoPane), findsNothing);

      await tester.tap(find.byIcon(Icons.info_outline_rounded).at(1));
      await tester.pumpAndSettle();

      final pane = tester.widget<GameModeInfoPane>(find.byType(GameModeInfoPane));
      expect(pane.mode, GameModeOption.cricket);
    });
  });

  group('on an upright tablet', () {
    testWidgets('behaves like a phone, with info buttons and no second pane',
        (tester) async {
      await pumpSelection(tester, const Size(820, 1180));

      expect(find.byType(GameModeInfoPane), findsNothing);
      expect(find.byIcon(Icons.info_outline_rounded), findsNWidgets(6));
      expect(find.text('Set up game'), findsNothing);
    });

    testWidgets('centres the list between the app bar and the bottom edge',
        (tester) async {
      await pumpSelection(tester, const Size(820, 1180));

      final list = tester.getRect(find.byType(CustomScrollView));
      expect(list.center.dy, closeTo((kToolbarHeight + 1180) / 2, 1));
      expect(list.top, greaterThan(kToolbarHeight + 100));
    });
  });

  group('on a tablet in landscape', () {
    testWidgets('shows the rules of X01 beside the list to begin with',
        (tester) async {
      await pumpSelection(tester, const Size(1180, 820));

      final pane = tester.widget<GameModeInfoPane>(find.byType(GameModeInfoPane));
      expect(pane.mode, GameModeOption.x01);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      expect(tester.getRect(find.byType(CustomScrollView)).top,
          closeTo(kToolbarHeight, 1));
    });

    testWidgets('a tap on a mode swaps the rules and leaves the screen open',
        (tester) async {
      await pumpSelection(tester, const Size(1180, 820));

      await tester.tap(find.text('Capital'));
      await tester.pumpAndSettle();

      final pane = tester.widget<GameModeInfoPane>(find.byType(GameModeInfoPane));
      expect(pane.mode, GameModeOption.capital);
      expect(find.byType(GameModeSelectionScreen), findsOneWidget);
    });

    testWidgets('centres the setup button under both panes', (tester) async {
      await pumpSelection(tester, const Size(1180, 820));

      final button = tester.getRect(find.byType(FilledButton));
      final pane   = tester.getRect(find.byType(GameModeInfoPane));
      expect(button.center.dx, closeTo(590, 1));
      expect(button.top, greaterThanOrEqualTo(pane.bottom));
    });

    testWidgets('divides the same way on an unfolded phone lying on its side',
        (tester) async {
      // The inner display of a foldable, 2853x2007 at three to a point.
      await pumpSelection(tester, const Size(951, 669));

      expect(find.byType(GameModeInfoPane), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
      expect(find.text('Set up game'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('runs the bar to the edges and keeps its button off the insets',
        (tester) async {
      // An unfolded phone on its side: a home indicator below and a status
      // column on the right.
      await pumpSelection(tester, const Size(951, 669),
          safeArea: const EdgeInsets.only(bottom: 21, right: 57));

      final bar = tester.getRect(find
          .ancestor(
              of: find.byType(FilledButton), matching: find.byType(Material))
          .first);
      expect(bar.right, 951);
      expect(bar.bottom, 669);

      final button = tester.getRect(find.byType(FilledButton));
      expect(button.bottom, lessThanOrEqualTo(669 - 21 - 16));
      final pane = tester.getRect(find.byType(GameModeInfoPane));
      expect(pane.right, lessThanOrEqualTo(951 - 57));
    });

    testWidgets('follows the divider the layout provider holds',
        (tester) async {
      layout.setSplitFraction(SplitPane.modes, 0.35, landscape: true);
      await pumpSelection(tester, const Size(1180, 820));

      final pane = tester.getRect(find.byType(GameModeInfoPane));
      expect(pane.width, greaterThan(1180 * 0.6));
    });
  });
}
