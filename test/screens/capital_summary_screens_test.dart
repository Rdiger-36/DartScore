import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/capital_game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/capital_provider.dart';
import 'package:dartscore_app/screens/capital_history_summary_screen.dart';
import 'package:dartscore_app/screens/capital_summary_screen.dart';
import 'package:dartscore_app/utils/dartboard_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

BoardHit single(int field) => (field: field, multiplier: 1);

void main() {
  group('the Capital summary screens', () {
    useInMemoryDatabase();

    late CapitalProvider provider;
    late List<Player> players;

    setUp(() async {
      players = await insertPlayers(['Ada', 'Zoe']);
      provider = CapitalProvider();
      await provider.startGame(
        CapitalGame(
          legs: 1,
          sets: 1,
          createdAt: DateTime(2026, 10, 25),
          playerIds: players.map((p) => p.id!).toList(),
        ),
        players,
      );
    });

    /// Plays the whole game out: Ada throws three single twenties every round
    /// and Zoe misses every dart.
    ///
    /// Three twenties meet exactly one contract, the "20" of round one. They
    /// are not a triple, not a double, not an arc, not a run, not three colors
    /// and not 57, so Ada's capital climbs once and is halved thereafter. That
    /// still leaves her ahead of Zoe, who never scores at all.
    ///
    /// Through [WidgetTester.runAsync], because every dart is a real database
    /// write and a widget test's fake async never lets one return.
    Future<void> playToTheEnd(WidgetTester tester) =>
        tester.runAsync(() async {
          for (var round = 0; round <= CapitalContractRounds.last; round++) {
            for (var dart = 0; dart < 3; dart++) {
              await provider.recordDart(single(20));
            }
            for (var dart = 0; dart < 3; dart++) {
              await provider.recordDart(boardMiss);
            }
          }
        });

    /// Both players miss everything, so both finish on nothing.
    Future<void> playAllMissed(WidgetTester tester) =>
        tester.runAsync(() async {
          for (var round = 0; round <= CapitalContractRounds.last; round++) {
            for (var player = 0; player < 2; player++) {
              for (var dart = 0; dart < 3; dart++) {
                await provider.recordDart(boardMiss);
              }
            }
          }
        });

    testWidgets('names the winner and ranks on the capital', (tester) async {
      await playToTheEnd(tester);
      expect(provider.gameOver, isTrue);

      usePhoneSurface(tester, size: const Size(400, 1400));
      await tester.pumpWidget(testApp(
        ChangeNotifierProvider<CapitalProvider>.value(
          value: provider,
          child: const CapitalSummaryScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ada'), findsWidgets);
      expect(find.textContaining('wins!'), findsOneWidget);
      expect(find.text('1 of 14 contracts met'), findsOneWidget);
      expect(find.text('0 of 14 contracts met'), findsOneWidget);
    });

    testWidgets('says so when the top capital is shared', (tester) async {
      await playAllMissed(tester);
      expect(provider.winnerId, isNull);

      usePhoneSurface(tester, size: const Size(400, 1400));
      await tester.pumpWidget(testApp(
        ChangeNotifierProvider<CapitalProvider>.value(
          value: provider,
          child: const CapitalSummaryScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('The top capital is shared'), findsOneWidget);
    });

    testWidgets('the history detail opens on its spinner while it replays',
        (tester) async {
      await playToTheEnd(tester);
      final stored = await tester.runAsync(
          () async => (await DbHelper.instance.getCapitalGames()).single);

      usePhoneSurface(tester, size: const Size(400, 1400));
      await tester.pumpWidget(testApp(
        ChangeNotifierProvider<CapitalProvider>.value(
          value: CapitalProvider(),
          child: CapitalHistorySummaryScreen(
            game: stored!,
            players: players,
          ),
        ),
      ));
      await tester.pump();

      // The screen builds its own provider in a field initializer, so the read
      // it starts belongs to the test's fake async and cannot be let through
      // from here. What this covers is that the screen constructs and shows
      // its loading state; that the replay itself is right is covered against
      // a real database in capital_provider_db_test.dart.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

  });
}

/// The round numbers a Capital game runs through, named here so the tests read
/// as the game does rather than as a magic number.
abstract final class CapitalContractRounds {
  static const int last = 14;
}
