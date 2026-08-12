import 'package:dartscore_app/models/around_the_clock_game.dart';
import 'package:dartscore_app/models/cricket_game.dart';
import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/models/shanghai_game.dart';
import 'package:dartscore_app/providers/around_the_clock_provider.dart';
import 'package:dartscore_app/providers/cricket_provider.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/providers/shanghai_provider.dart';
import 'package:dartscore_app/screens/around_the_clock_summary_screen.dart';
import 'package:dartscore_app/screens/cricket_summary_screen.dart';
import 'package:dartscore_app/screens/game_summary_screen.dart';
import 'package:dartscore_app/screens/shanghai_summary_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
import 'package:dartscore_app/widgets/summary_player_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

/// The four post-game summaries, each rendered from a game that was really
/// played to its end through its provider.
///
/// The games are played in `setUp`, because every visit writes a row and a
/// widget test runs in fake async where a real database write never returns.
void main() {
  // ── X01 ─────────────────────────────────────────────────────────────────────

  group('the X01 summary', () {
    useInMemoryDatabase();

    late GameProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = GameProvider();
      players = await insertPlayers(['Ada', 'Zoe']);
      await provider.startGame(
        Game(
          startScore:    101,
          legs:          1,
          sets:          1,
          createdAt:     DateTime(2026, 4, 1),
          startingOrder: StartingOrder.fixed,
        ),
        players,
      );
      // 101 in one visit: T20, 9, D16. The double checks Ada out and, with a
      // single leg, ends the game.
      await provider.tapField(20, 3);
      await provider.tapField(9, 1);
      await provider.tapField(16, 2);
    });

    Future<void> pumpSummary(WidgetTester tester) async {
      usePhoneSurface(tester, size: const Size(400, 2400));
      await tester.pumpWidget(
          testApp(const GameSummaryScreen(), game: provider));
      await tester.pumpAndSettle();
    }

    testWidgets('crowns whoever checked out', (tester) async {
      expect(provider.gameOver, isTrue,
          reason: 'the setup has to leave a finished game behind');

      await pumpSummary(tester);

      expect(find.text('Game Summary'), findsOneWidget);
      expect(find.text('🎯 Ada wins!'), findsOneWidget);
    });

    testWidgets('gives both players a card and keeps the export actions',
        (tester) async {
      await pumpSummary(tester);

      expect(find.text('Ada'), findsWidgets);
      expect(find.text('Zoe'), findsWidgets);
      // Saving and sharing the result card are the two things this screen can
      // do that no other summary offers.
      expect(find.byIcon(Icons.download_rounded), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);
    });

    testWidgets('keeps the shared card whole beside the throw log on a tablet',
        (tester) async {
      usePhoneSurface(tester, size: const Size(1180, 820));
      await tester.pumpWidget(
          testApp(const GameSummaryScreen(), game: provider));
      await tester.pumpAndSettle();

      // Divided: the log stands to the right of the result.
      expect(find.byKey(kPaneDividerKey), findsOneWidget);
      expect(tester.getRect(find.text('All Throws')).left,
          greaterThan(tester.getRect(find.text('🎯 Ada wins!')).right));

      // What the image is taken of is the boundary the screen keys, and it
      // still holds every part of the result. Divided, the saved card would
      // quietly lose whichever half stayed behind.
      final captured = find
          .ancestor(
            of: find.text('🎯 Ada wins!'),
            matching: find.byWidgetPredicate(
                (w) => w is RepaintBoundary && w.key is GlobalKey),
          )
          .first;
      expect(
        find.descendant(of: captured, matching: find.byType(SummaryPlayerCard)),
        findsNWidgets(2),
      );
      // The log is what the boundary was drawn around rather than over: too
      // long for an image, and the proof that this is the card, not the screen.
      expect(
        find.descendant(of: captured, matching: find.text('All Throws')),
        findsNothing,
      );
    });
  });

  // ── Cricket ─────────────────────────────────────────────────────────────────

  group('the Cricket summary', () {
    useInMemoryDatabase();

    late CricketProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = CricketProvider();
      players = await insertPlayers(['Ada', 'Zoe']);
      await provider.startGame(
        CricketGame(
          variant:       CricketVariant.normal,
          scoringMode:   CricketScoringMode.standard,
          legs:          1,
          sets:          1,
          createdAt:     DateTime(2026, 4, 1),
          playerIds:     players.map((p) => p.id!).toList(),
          startingOrder: StartingOrder.fixed,
        ),
        players,
      );

      // Ada closes every field with a triple while Zoe throws her visits away.
      for (final field in cricketFields) {
        await provider.recordDart(field, 3);
        if (provider.gameOver) break;
        if (provider.dartsInVisit == 0) {
          for (var i = 0; i < 3; i++) {
            await provider.recordDart(0, 0);
          }
        }
      }
    });

    Future<void> pumpSummary(WidgetTester tester) async {
      usePhoneSurface(tester, size: const Size(400, 2400));
      await tester.pumpWidget(testApp(
        ChangeNotifierProvider<CricketProvider>.value(
          value: provider,
          child: const CricketSummaryScreen(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('crowns the player who closed the board', (tester) async {
      expect(provider.gameOver, isTrue);

      await pumpSummary(tester);

      expect(find.text('🎯 Ada wins!'), findsOneWidget);
    });

    testWidgets('counts the closed fields per player', (tester) async {
      await pumpSummary(tester);

      expect(find.text('7/7 Fields closed'), findsOneWidget);
      expect(find.text('0/7 Fields closed'), findsOneWidget);
    });

    testWidgets('lists every Cricket field in the marks grid', (tester) async {
      await pumpSummary(tester);

      expect(find.text('Marks'), findsOneWidget);
      for (final field in [20, 19, 18, 17, 16, 15]) {
        expect(find.text('$field'), findsWidgets, reason: '$field is a row');
      }
      expect(find.text('Bull'), findsOneWidget,
          reason: '25 is shown as Bull, not as a number');
    });

    testWidgets('repeats the settings the game was played under',
        (tester) async {
      await pumpSummary(tester);

      expect(find.text('Cricket'), findsWidgets);
      expect(find.text('Normal'), findsWidgets);
      expect(find.text('Fixed'), findsWidgets,
          reason: 'the starting order belongs in the info card');
    });
  });

  // ── Shanghai ────────────────────────────────────────────────────────────────

  group('the Shanghai summary', () {
    useInMemoryDatabase();

    late ShanghaiProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = ShanghaiProvider();
      players = await insertPlayers(['Ada', 'Zoe']);
      await provider.startGame(
        ShanghaiGame(
          variant:       ShanghaiVariant.classic,
          legs:          1,
          sets:          1,
          createdAt:     DateTime(2026, 4, 1),
          playerIds:     players.map((p) => p.id!).toList(),
          startingOrder: StartingOrder.fixed,
        ),
        players,
      );

      // Ada scores a triple with every dart, Zoe misses every one, over all
      // nine rounds. Ada throws no single-double-triple round, so the game is
      // decided on points rather than by an instant Shanghai.
      while (!provider.gameOver) {
        await provider.recordDart(provider.currentPlayerIndex == 0 ? 3 : 0);
      }
    });

    Future<void> pumpSummary(WidgetTester tester) async {
      usePhoneSurface(tester, size: const Size(400, 2400));
      await tester.pumpWidget(testApp(
        ChangeNotifierProvider<ShanghaiProvider>.value(
          value: provider,
          child: const ShanghaiSummaryScreen(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('crowns the player with the higher score', (tester) async {
      await pumpSummary(tester);

      expect(find.text('🎯 Ada wins!'), findsOneWidget);
    });

    testWidgets('shows both final scores', (tester) async {
      await pumpSummary(tester);

      // Nine rounds, three triples each, on the targets 1 to 9.
      final expected = List.generate(9, (i) => (i + 1) * 9).reduce((a, b) => a + b);
      expect(provider.playerStates[0].score, expected);
      expect(find.text('$expected'), findsOneWidget);
      expect(find.text('0'), findsOneWidget, reason: 'Zoe never scored');
      expect(find.text('Total Score'), findsNWidgets(2));
    });

    testWidgets('names the variant it was played in', (tester) async {
      await pumpSummary(tester);

      expect(find.text('Shanghai'), findsWidgets);
      expect(find.text('Classic (1-9)'), findsWidgets);
    });
  });

  // ── Around the Clock ────────────────────────────────────────────────────────

  group('the Around the Clock summary', () {
    useInMemoryDatabase();

    late AroundTheClockProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = AroundTheClockProvider();
      players = await insertPlayers(['Ada', 'Zoe']);
      await provider.startGame(
        AroundTheClockGame(
          variant:       AroundTheClockVariant.basic,
          legs:          1,
          sets:          1,
          createdAt:     DateTime(2026, 4, 1),
          playerIds:     players.map((p) => p.id!).toList(),
          startingOrder: StartingOrder.fixed,
        ),
        players,
      );

      // Ada hits her target with every dart, Zoe never hits hers.
      while (!provider.gameOver) {
        if (provider.currentPlayerIndex == 0) {
          await provider.recordDart(provider.activeTarget, 1);
        } else {
          await provider.recordDart(0, 0);
        }
      }
    });

    Future<void> pumpSummary(WidgetTester tester) async {
      usePhoneSurface(tester, size: const Size(400, 2400));
      await tester.pumpWidget(testApp(
        ChangeNotifierProvider<AroundTheClockProvider>.value(
          value: provider,
          child: const AroundTheClockSummaryScreen(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('crowns whoever reached the Bull first', (tester) async {
      await pumpSummary(tester);

      expect(find.text('🎯 Ada wins!'), findsOneWidget);
    });

    testWidgets('reports how far each player got', (tester) async {
      await pumpSummary(tester);

      final total = aroundTheClockOrder.length;
      expect(find.text('$total/$total hit'), findsOneWidget);
      expect(find.text('0/$total hit'), findsOneWidget);
      expect(find.text('$total darts'), findsOneWidget,
          reason: 'one dart per target is what the winner needed');
    });
  });
}
