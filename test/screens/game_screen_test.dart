import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

void main() {
  group('the live X01 screen', () {
    useInMemoryDatabase();

    late GameProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = GameProvider();
      players = await insertPlayers(['Ada', 'Zoe']);
      await provider.startGame(
        Game(
          startScore: 501,
          legs: 3,
          sets: 1,
          createdAt: DateTime.now(),
          startingOrder: StartingOrder.fixed,
        ),
        players,
      );
    });

    /// Pumps the screen with the game already running.
    Future<void> pumpGame(WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(testApp(const GameScreen(), game: provider));
      await tester.pumpAndSettle();
    }

    /// Taps a field button on the dartboard input.
    Future<void> tapField(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(InkWell, label).first);
      await tester.pump();
    }

    testWidgets('shows both players on their start score', (tester) async {
      await pumpGame(tester);

      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Zoe'), findsOneWidget);
      expect(find.text('501'), findsNWidgets(2));
    });

    testWidgets('counts a visit down and hands the turn on', (tester) async {
      await pumpGame(tester);
      final firstUp = provider.currentPlayerState.player.name;

      // Driven through the provider inside runAsync, because the third dart
      // closes the visit and that writes a row. A widget test otherwise runs
      // in fake async, where a real database write never completes.
      await tester.runAsync(() async {
        await provider.tapField(20, 1);
        await provider.tapField(20, 1);
        await provider.tapField(20, 1);
      });
      await tester.pumpAndSettle();

      expect(find.text('441'), findsOneWidget);
      expect(find.text('501'), findsOneWidget);
      expect(provider.currentPlayerState.player.name, isNot(firstUp));
    });

    testWidgets('takes a dart back when undo is tapped', (tester) async {
      await pumpGame(tester);

      await tapField(tester, '20');
      expect(provider.dartsInVisit, 1);

      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();

      expect(provider.dartsInVisit, 0);
      expect(find.text('501'), findsNWidgets(2));
    });

    testWidgets('scores a triple when the triple segment is selected',
        (tester) async {
      await pumpGame(tester);

      await tester.tap(find.text('Triple'));
      await tester.pumpAndSettle();
      await tapField(tester, '20');
      await tester.pumpAndSettle();

      // 501 - 60, shown live while the visit is still open.
      expect(find.text('441'), findsOneWidget);
    });

    testWidgets('asks before leaving when the close button is used',
        (tester) async {
      await pumpGame(tester);

      // Scoped to the app bar: the Miss button on the dartboard carries a
      // close icon of its own, and tapping that would score instead of asking
      // anything.
      await tester.tap(find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.close_rounded),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('answers the system back with the same question', (tester) async {
      // CLAUDE.md makes this a convention across all four live screens: a
      // running game must not be lost to a stray back gesture, so the route
      // refuses to pop and asks instead.
      await pumpGame(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(GameScreen), findsOneWidget);
    });

    testWidgets('stays in the game when the question is declined',
        (tester) async {
      await pumpGame(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(GameScreen), findsOneWidget);
    });
  });
}
