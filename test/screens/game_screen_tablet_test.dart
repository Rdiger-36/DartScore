import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/providers/input_side_provider.dart';
import 'package:dartscore_app/screens/game_screen.dart';
import 'package:dartscore_app/screens/live_player_stats_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
import 'package:dartscore_app/widgets/dartboard_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

/// A 10.9 inch tablet, upright and on its side, with the insets it carries.
const _tabletPortrait  = Size(820, 1180);
const _tabletLandscape = Size(1180, 820);
const _tabletInsets    = EdgeInsets.only(top: 24, bottom: 20);

void main() {
  group('the live X01 screen on a tablet', () {
    useInMemoryDatabase();

    late GameProvider game;
    late InputSideProvider inputSide;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      game = GameProvider();
      inputSide = InputSideProvider();
    });

    /// Starts a two player game and renders it at the given size.
    Future<void> pumpGame(
      WidgetTester tester, {
      required Size surface,
      InputSide? side,
    }) async {
      await tester.runAsync(() async {
        final players = await insertPlayers(['Ada', 'Zoe']);
        await game.startGame(
          Game(
            startScore: 501,
            legs: 3,
            sets: 1,
            createdAt: DateTime.now(),
            startingOrder: StartingOrder.fixed,
          ),
          players,
        );
        if (side != null) await inputSide.setSide(side);
      });

      usePhoneSurface(tester, size: surface, safeArea: _tabletInsets);
      await tester.pumpWidget(
        ChangeNotifierProvider<InputSideProvider>.value(
          value: inputSide,
          child: testApp(const GameScreen(), game: game),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The horizontal centre of the input, and of the live stats beside it.
    (double, double) paneCentres(WidgetTester tester) => (
          tester.getRect(find.byType(DartboardInput)).center.dx,
          tester.getRect(find.byType(LivePlayerStatsPanel)).center.dx,
        );

    testWidgets('shows the stats of whoever is throwing beside the input',
        (tester) async {
      await pumpGame(tester, surface: _tabletLandscape);

      expect(find.byType(LivePlayerStatsPanel), findsOneWidget);
      // The panel names the slot it describes, and Ada throws first.
      expect(find.text('Ada'), findsWidgets);
      expect(find.byType(DartboardInput), findsOneWidget);
    });

    testWidgets('follows the turn without being asked', (tester) async {
      await pumpGame(tester, surface: _tabletLandscape);
      expect(game.currentPlayerIndex, 0);

      await tester.runAsync(() async {
        await game.tapField(20, 1);
        await game.tapField(20, 1);
        await game.tapField(20, 1);
      });
      await tester.pumpAndSettle();

      expect(game.currentPlayerIndex, 1);
      final panel = tester.widget<LivePlayerStatsPanel>(
          find.byType(LivePlayerStatsPanel));
      expect(panel.slotIndex, 1);
    });

    testWidgets('starts with the input on the left', (tester) async {
      await pumpGame(tester, surface: _tabletLandscape);

      final (input, stats) = paneCentres(tester);
      expect(input, lessThan(stats));
    });

    testWidgets('moves the input over when the setting says right',
        (tester) async {
      await pumpGame(tester, surface: _tabletLandscape, side: InputSide.right);

      final (input, stats) = paneCentres(tester);
      expect(input, greaterThan(stats));
    });

    testWidgets('splits only the space below the scoreboard in portrait',
        (tester) async {
      await pumpGame(tester, surface: _tabletPortrait);

      final (input, stats) = paneCentres(tester);
      expect(input, lessThan(stats));

      // The scoreboard spans the full width above both panes rather than
      // sharing a row with them.
      final board = tester.getRect(find.text('501').first);
      final inputTop = tester.getRect(find.byType(DartboardInput)).top;
      expect(board.bottom, lessThan(inputTop));
    });

    testWidgets('gives the input the full height of its pane', (tester) async {
      await pumpGame(tester, surface: _tabletLandscape);

      final pane = tester.getRect(find.byType(DartboardInput));
      final done = tester.getRect(find.widgetWithText(InkWell, 'Done').first);
      final field = tester.getRect(find.widgetWithText(InkWell, '20').first);

      // The action row ends at the bottom of the pane instead of floating in
      // the middle of it, the buttons grew past their phone size, and no hole
      // is left between the last row of numbers and the actions.
      expect(pane.bottom - done.bottom, lessThan(30));
      expect(field.height, greaterThan(45));
      expect(done.top - field.bottom, lessThan(80));
    });

    testWidgets('puts the actions beside the numbers in landscape',
        (tester) async {
      await pumpGame(tester, surface: _tabletLandscape);

      final field = tester.getRect(find.widgetWithText(InkWell, '20').first);
      final miss  = tester.getRect(find.widgetWithText(InkWell, 'Miss').first);
      final done  = tester.getRect(find.widgetWithText(InkWell, 'Done').first);

      // Beside, not below, and the column ends where the grid ends rather than
      // floating next to it.
      expect(miss.left, greaterThan(field.right));
      expect((done.bottom - field.bottom).abs(), lessThan(2));
      // The height the row under the grid used to take went to the numbers.
      expect(field.height, greaterThan(70));
    });

    testWidgets('keeps the actions under the numbers in portrait',
        (tester) async {
      // Half of a portrait tablet is too narrow to give a column away: the
      // numbers would pay for it in width.
      await pumpGame(tester, surface: _tabletPortrait);

      final field = tester.getRect(find.widgetWithText(InkWell, '20').first);
      final miss  = tester.getRect(find.widgetWithText(InkWell, 'Miss').first);

      expect(miss.top, greaterThan(field.bottom));
    });

    testWidgets('fits the larger cards on a small tablet', (tester) async {
      // The tablet sizes are the tallest the scoreboard gets, so the smallest
      // tablet on its side is where they run out of room first. An overflow
      // fails the test on its own.
      await pumpGame(tester, surface: const Size(1133, 744));

      expect(find.byType(LivePlayerStatsPanel), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Done'), findsOneWidget);
    });

    testWidgets('stays a single column on a phone sized window',
        (tester) async {
      await pumpGame(tester, surface: const Size(375, 812));

      expect(find.byType(LivePlayerStatsPanel), findsNothing);
      expect(find.byType(DartboardInput), findsOneWidget);
    });
  });
}
