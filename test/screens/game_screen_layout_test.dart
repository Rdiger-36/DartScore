import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

/// The screen of an iPhone SE (2nd/3rd generation), the shortest phone the app
/// targets and the one the input used to run off the bottom of.
const _seSurface = Size(375, 667);

void main() {
  group('the live X01 screen on a short phone', () {
    useInMemoryDatabase();

    late GameProvider provider;

    setUp(() {
      provider = GameProvider();
    });

    /// Starts a game with [names] and renders it on a [surface] sized screen.
    ///
    /// [teams] is built from the inserted players, which is why it is a callback
    /// rather than a value: the ids only exist once the players are written.
    ///
    /// Starting the game runs inside `runAsync` because it writes rows, and a
    /// widget test otherwise runs in fake async where a real write never
    /// returns and the test simply hangs.
    Future<void> pumpGame(
      WidgetTester tester,
      List<String> names, {
      Size surface = _seSurface,
      List<TeamConfig> Function(List<Player>)? teams,
    }) async {
      await tester.runAsync(() async {
        final players = await insertPlayers(names);
        await provider.startGame(
          Game(
            startScore: 501,
            legs: 3,
            sets: 1,
            createdAt: DateTime.now(),
            startingOrder: StartingOrder.fixed,
            teams: teams?.call(players),
          ),
          players,
        );
      });

      usePhoneSurface(tester, size: surface);
      await tester.pumpWidget(testApp(const GameScreen(), game: provider));
      await tester.pumpAndSettle();
    }

    /// Fails unless every button of the action row is fully on screen.
    ///
    /// Geometry, not a plain `findsOneWidget`: the row used to be laid out
    /// below the bottom edge inside a scroll view, where it is built and found
    /// like any other widget while the player cannot see or reach it.
    void expectActionRowVisible(WidgetTester tester, Size surface) {
      for (final label in ['Miss', 'Bull (25)', 'Done']) {
        final rect = tester.getRect(find.widgetWithText(InkWell, label).first);
        expect(rect.bottom, lessThanOrEqualTo(surface.height),
            reason: '"$label" runs past the bottom of the screen');
      }
    }

    testWidgets('keeps the action row on screen with two players',
        (tester) async {
      await pumpGame(tester, ['Ada', 'Zoe']);

      expectActionRowVisible(tester, _seSurface);
    });

    testWidgets('keeps the action row on screen with four players',
        (tester) async {
      // Four players add the compact score strip below the two big cards.
      await pumpGame(tester, ['Ada', 'Zoe', 'Ben', 'Cleo']);

      expectActionRowVisible(tester, _seSurface);
    });

    testWidgets('keeps the action row on screen with teams', (tester) async {
      // A team slot carries a second line under the name, the tallest the
      // scoreboard ever gets.
      await pumpGame(
        tester,
        ['Ada', 'Zoe', 'Ben', 'Cleo'],
        teams: (p) => [
          TeamConfig(name: 'Team 1', playerIds: [p[0].id!, p[2].id!]),
          TeamConfig(name: 'Team 2', playerIds: [p[1].id!, p[3].id!]),
        ],
      );

      expect(find.text('Team 1'), findsOneWidget);
      expectActionRowVisible(tester, _seSurface);
    });

    testWidgets('still offers all twenty fields and the modifiers',
        (tester) async {
      await pumpGame(tester, ['Ada', 'Zoe', 'Ben', 'Cleo']);

      for (var field = 1; field <= 20; field++) {
        expect(find.widgetWithText(InkWell, '$field'), findsWidgets,
            reason: 'field $field is missing from the compact grid');
      }
      expect(find.text('Triple'), findsOneWidget);
    });

    testWidgets('a field button stays large enough to hit', (tester) async {
      await pumpGame(tester, ['Ada', 'Zoe', 'Ben', 'Cleo']);

      final button = tester.getSize(find.widgetWithText(InkWell, '20').first);
      expect(button.height, greaterThanOrEqualTo(30));
      expect(button.width, greaterThanOrEqualTo(44));
    });
  });
}
