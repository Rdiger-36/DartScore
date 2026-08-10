import 'package:dartscore_app/providers/players_provider.dart';
import 'package:dartscore_app/screens/game_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

/// The X01 setup screen: the form that decides what a game will be. Players are
/// written in `setUp`, because a widget test runs in fake async where a real
/// database write never completes.
void main() {
  group('the X01 setup screen', () {
    useInMemoryDatabase();

    late PlayersProvider players;

    setUp(() async {
      await insertPlayers(['Ada', 'Zoe']);
      players = PlayersProvider();
      await players.load();
    });

    Future<void> pumpSetup(WidgetTester tester) async {
      usePhoneSurface(tester, size: const Size(400, 1600));
      await tester.pumpWidget(
          testApp(const GameSetupScreen(), players: players));
      await tester.pumpAndSettle();
    }

    /// The Start button, whichever wording it currently carries.
    ///
    /// Found through its label rather than by type: it is a
    /// `FilledButton.icon`, whose child is a private widget, so the text is
    /// not reachable from the button itself.
    Finder startButton() => find
        .ancestor(
          of: find.textContaining('Start'),
          matching: find.byType(FilledButton),
        )
        .first;

    testWidgets('will not start a game nobody is playing', (tester) async {
      await pumpSetup(tester);

      expect(find.text('Select at least 1 player'), findsOneWidget);
      final button = tester.widget<FilledButton>(startButton());
      expect(button.onPressed, isNull);
    });

    testWidgets('starts once a player is picked, and says it is a solo game',
        (tester) async {
      await pumpSetup(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('Select at least 1 player'), findsNothing);
      expect(tester.widget<FilledButton>(startButton()).onPressed, isNotNull);
      expect(find.textContaining('Solo'), findsWidgets);
    });

    testWidgets('offers every start score, on 501 by default', (tester) async {
      await pumpSetup(tester);

      for (final score in ['101', '170', '201', '301', '501', '701', '1001']) {
        expect(find.text(score), findsWidgets,
            reason: '$score should be offered as a start score');
      }
    });

    testWidgets('moves the selection when another start score is picked',
        (tester) async {
      await pumpSetup(tester);

      ChoiceChip chipFor(String score) => tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, score).first);
      expect(chipFor('501').selected, isTrue, reason: '501 is the default');

      await tester.tap(find.widgetWithText(ChoiceChip, '301'));
      await tester.pumpAndSettle();

      expect(chipFor('301').selected, isTrue);
      expect(chipFor('501').selected, isFalse);
    });

    testWidgets('offers check-in and check-out separately', (tester) async {
      await pumpSetup(tester);

      // Straight, Double and Master exist twice over: once for getting in and
      // once for getting out. A screen that lost one of the two rows would
      // still look plausible.
      expect(find.text('Straight'), findsNWidgets(2));
      expect(find.text('Double'), findsNWidgets(2));
      expect(find.text('Master'), findsNWidgets(2));
    });
  });
}
