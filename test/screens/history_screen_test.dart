import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/cricket_game.dart';
import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/screens/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

/// The history list. Everything is written in `setUp`, because a widget test
/// runs in fake async where a real database write never completes.
void main() {
  group('the history list', () {
    useInMemoryDatabase();

    late List<Player> players;

    setUp(() async {
      players = await insertPlayers(['Ada', 'Zoe']);
      final ids = players.map((p) => p.id!).toList();
      final db = DbHelper.instance;

      // An unfinished X01 game with both players, in that order.
      await db.insertGame(
        Game(startScore: 501, createdAt: DateTime(2026, 3, 1)),
        ids,
      );
      // A finished X01 game, so the two tabs have something to separate.
      await db.insertGame(
        Game(
          startScore: 301,
          createdAt:  DateTime(2026, 2, 1),
          finishedAt: DateTime(2026, 2, 1, 1),
        ),
        ids,
      );
      // An unfinished Cricket game, to give the mode filter something to do.
      await db.insertCricketGame(CricketGame(
        variant:     CricketVariant.normal,
        scoringMode: CricketScoringMode.standard,
        legs:        1,
        sets:        1,
        createdAt:   DateTime(2026, 3, 2),
        playerIds:   ids,
      ));
    });

    /// Pumps the screen and lets the list load.
    ///
    /// The body is a FutureBuilder over a database read, which is real I/O the
    /// fake clock never reaches, so it has to be let through before anything
    /// settles on the spinner standing in for it.
    Future<void> pumpHistory(WidgetTester tester) async {
      usePhoneSurface(tester, size: const Size(400, 1200));
      await tester.pumpWidget(testApp(const HistoryScreen()));

      // Wait for the read rather than for a guessed duration: settling on the
      // spinner would wait on an animation that only stops once the future is
      // done, and a fixed delay is either flaky or slow.
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
    }

    testWidgets('names both players of a game, in turn order', (tester) async {
      // The line-ups come from one batched read rather than a query per game.
      // If that ever regressed to returning nothing, the title would collapse
      // to an empty string rather than fail loudly.
      await pumpHistory(tester);

      expect(find.text('Ada vs Zoe'), findsWidgets);
    });

    testWidgets('keeps unfinished games apart from finished ones',
        (tester) async {
      await pumpHistory(tester);

      // Open: the 501 game and the Cricket one. The finished 301 is elsewhere.
      expect(find.textContaining('501'), findsOneWidget);
      expect(find.textContaining('301'), findsNothing);

      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      expect(find.textContaining('301'), findsOneWidget);
    });

    testWidgets('offers a filter only for the modes actually present',
        (tester) async {
      await pumpHistory(tester);

      // The open tab holds an X01 and a Cricket game and nothing else, so
      // Shanghai and Around the Clock have no chip to offer.
      expect(find.widgetWithText(FilterChip, 'Cricket'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Shanghai'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'Around the Clock'), findsNothing);
    });

    testWidgets('narrows the list to the chosen mode', (tester) async {
      await pumpHistory(tester);
      expect(find.textContaining('501'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Cricket'));
      await tester.pumpAndSettle();

      expect(find.textContaining('501'), findsNothing);
      expect(find.text('Ada vs Zoe'), findsOneWidget);
    });
  });
}
