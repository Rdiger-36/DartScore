import 'package:dartscore_app/providers/players_provider.dart';
import 'package:dartscore_app/screens/game_setup_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
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

    testWidgets('keeps the settings above the players on a phone',
        (tester) async {
      await pumpSetup(tester);

      // The order a phone has always shown: the game first, then who plays it.
      expect(find.byKey(kPaneDividerKey), findsNothing);
      expect(tester.getRect(find.text('Start Score')).bottom,
          lessThan(tester.getRect(find.text('Players')).top));
    });
  });

  group('the X01 setup screen on a tablet', () {
    useInMemoryDatabase();

    late PlayersProvider players;

    setUp(() async {
      await insertPlayers(['Ada', 'Zoe']);
      players = PlayersProvider();
      await players.load();
    });

    /// Renders the setup at [size]. No layout provider is wrapped around it on
    /// purpose: this screen divides in the middle and keeps nothing.
    Future<void> pumpSetup(WidgetTester tester, Size size) async {
      usePhoneSurface(tester, size: size);
      await tester.pumpWidget(
          testApp(const GameSetupScreen(), players: players));
      await tester.pumpAndSettle();
    }

    /// The Start button, found through its label as on the phone.
    Finder startButton() => find
        .ancestor(
          of: find.textContaining('Start '),
          matching: find.byType(FilledButton),
        )
        .first;

    testWidgets('stands the players beside the settings', (tester) async {
      await pumpSetup(tester, const Size(1180, 820));

      final settings = tester.getRect(find.text('Start Score'));
      final picker   = tester.getRect(find.text('Players'));
      expect(picker.left, greaterThan(settings.right));
      expect(find.byKey(kPaneDividerKey), findsOneWidget);
    });

    testWidgets('puts the start button under both columns', (tester) async {
      await pumpSetup(tester, const Size(1180, 820));

      // Each column scrolls on its own, so the button may not belong to one of
      // them: it sits below both, and so does the reason it is disabled.
      final button = tester.getRect(startButton());
      for (final column in tester.widgetList(find.byType(ListView))) {
        expect(button.top,
            greaterThanOrEqualTo(tester.getRect(find.byWidget(column)).bottom));
      }
      expect(tester.widget<FilledButton>(startButton()).onPressed, isNull);
      expect(find.text('Select at least 1 player'), findsOneWidget);
    });

    testWidgets('divides in the middle and stays there', (tester) async {
      await pumpSetup(tester, const Size(1180, 820));

      final divider = tester.getRect(find.byKey(kPaneDividerKey));
      expect(divider.center.dx, closeTo(1180 / 2, 8));

      // Both columns hold the same kind of thing, so there is nothing to
      // rebalance: the divider is a line, not a grip.
      await tester.drag(find.byKey(kPaneDividerKey), const Offset(120, 0),
          touchSlopX: 0);
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(kPaneDividerKey)), divider);
    });

    testWidgets('lays both columns out full, upright and on its side',
        (tester) async {
      // Two players is where the screen is at its fullest: the format, the
      // handicaps, the teams and the throwing order all appear at once.
      await pumpSetup(tester, const Size(820, 1180));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(Checkbox).at(i));
        await tester.pumpAndSettle();
      }

      expect(find.text('Match Format'), findsOneWidget);
      expect(find.text('Starting order'), findsOneWidget);
      expect(tester.widget<FilledButton>(startButton()).onPressed, isNotNull);

      // Turned on its side. The screen keeps its state, so nothing is picked
      // twice, and both columns lay out again at the other shape.
      await pumpSetup(tester, const Size(1180, 820));

      expect(find.text('Match Format'), findsOneWidget);
      expect(find.text('Starting order'), findsOneWidget);
      expect(tester.getRect(find.text('Players')).left,
          greaterThan(tester.getRect(find.text('Match Format')).right));
    });

    testWidgets('stays one column where two would be too narrow',
        (tester) async {
      // A small tablet upright: wide enough for two panes by the breakpoint,
      // not wide enough for two of these.
      await pumpSetup(tester, const Size(620, 1000));

      expect(find.byKey(kPaneDividerKey), findsNothing);
      expect(tester.getRect(find.text('Start Score')).bottom,
          lessThan(tester.getRect(find.text('Players')).top));
    });
  });
}
