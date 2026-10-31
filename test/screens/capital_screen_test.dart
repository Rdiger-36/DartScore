import 'package:dartscore_app/models/capital_game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/bot_runner.dart';
import 'package:dartscore_app/providers/capital_provider.dart';
import 'package:dartscore_app/screens/capital_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
import 'package:dartscore_app/utils/segment_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

void main() {
  group('the live Capital screen', () {
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

    /// Pumps the screen with the game's own provider, which `testApp` does not
    /// supply: a screen whose provider is missing should fail loudly.
    Future<void> pumpScreen(WidgetTester tester,
        {Size size = const Size(400, 900)}) async {
      usePhoneSurface(tester, size: size);
      await tester.pumpWidget(
        testApp(
          ChangeNotifierProvider<CapitalProvider>.value(
            value: provider,
            child: const CapitalScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Taps the board key labelled [label], letting the dart's database write
    /// through: a widget test runs in fake async, where a real write never
    /// returns and the visit would never settle.
    Future<void> tapKey(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(InkWell, label).first);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }

    /// Taps the board key labelled [label] without waiting for the frames to
    /// stop, for the tests that hold a visit pending: the pause bar animates
    /// for as long as the pause lasts, so `pumpAndSettle` would never return.
    Future<void> tapKeyPending(WidgetTester tester, String label) async {
      await tester.tap(find.widgetWithText(InkWell, label).first);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    /// Taps the score of the slot named [name], the half of the row that pins
    /// the arithmetic. The name half opens the live numbers instead.
    Future<void> tapScore(
        WidgetTester tester, String name, String total) async {
      final row =
          find.ancestor(of: find.text(name), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.text(total)));
      await tester.pumpAndSettle();
    }

    /// The fill of the key labelled [label].
    Color keyColor(WidgetTester tester, String label) {
      final material = tester.widget<Material>(
          find.widgetWithText(Material, label).first);
      return material.color!;
    }

    group('the contract band', () {
      testWidgets('opens on the capital round, which is not a contract',
          (tester) async {
        await pumpScreen(tester);
        expect(find.text('Opening round'), findsOneWidget);
        expect(find.text('Capital'), findsWidgets);
        expect(find.text('Your three darts become your capital'), findsOneWidget);
      });

      testWidgets('numbers the contracts from one once they begin',
          (tester) async {
        await pumpScreen(tester);
        for (var i = 0; i < 6; i++) {
          await tapKey(tester, '20');
        }
        expect(find.text('Contract 1 of 14'), findsOneWidget);
        expect(find.text('Any ring counts'), findsOneWidget);
      });

      testWidgets('replaces the reminder with what the visit still needs',
          (tester) async {
        await pumpScreen(tester);
        // Six completed rounds, the capital and contracts one to five, which
        // leaves the game on round six, Side by Side.
        for (var round = 0; round < 6; round++) {
          for (var player = 0; player < 2; player++) {
            for (var dart = 0; dart < 3; dart++) {
              await tapKey(tester, 'Miss');
            }
          }
        }
        expect(find.text('Side by Side'), findsOneWidget);
        expect(find.text('3 adjacent segments'), findsOneWidget);

        await tapKey(tester, '20');
        // Every arc through the 20, listed rather than described.
        expect(find.text('Make 20-1-18, 12-5-20 or 5-20-1'), findsOneWidget);
      });
    });

    group('the keypad', () {
      testWidgets('paints each key the color that field is on the board',
          (tester) async {
        await pumpScreen(tester);
        // The 20 opens the segment order and the 1 follows it, so one is a
        // black single and the other cream.
        expect(keyColor(tester, '20'), BoardPaint.black);
        expect(keyColor(tester, '1'), BoardPaint.cream);
        expect(keyColor(tester, '25'), BoardPaint.green);
        expect(keyColor(tester, 'Bull'), BoardPaint.red);
      });

      testWidgets('repaints red and green when the ring changes',
          (tester) async {
        await pumpScreen(tester);
        await tester.tap(find.text('Double'));
        await tester.pumpAndSettle();

        expect(keyColor(tester, '20'), BoardPaint.red);
        expect(keyColor(tester, '1'), BoardPaint.green);
      });

      testWidgets('picks the ring from one bar, as the X01 input does',
          (tester) async {
        await pumpScreen(tester);

        expect(find.byType(SegmentedButton<int>), findsOneWidget);
      });

      testWidgets('names what a multiplied key is worth, as X01 does',
          (tester) async {
        await pumpScreen(tester);
        expect(find.text('60'), findsNothing);

        await tester.tap(find.text('Triple'));
        await tester.pumpAndSettle();

        // The 20 reads 20 over 60. No other field triples to 60.
        expect(find.text('60'), findsOneWidget);
        // The bull is one value whatever the ring, so it gains no second line
        // that would only repeat its label.
        expect(find.text('50'), findsNothing);
      });

      testWidgets('returns to singles after a dart, so a ring is never sticky',
          (tester) async {
        await pumpScreen(tester);
        await tester.tap(find.text('Triple'));
        await tester.pumpAndSettle();
        await tapKey(tester, '20');

        expect(keyColor(tester, '20'), BoardPaint.black,
            reason: 'the ring should have fallen back to single');
      });
    });

    group('the scoreboard', () {
      testWidgets('shows the arithmetic of the slot that just threw',
          (tester) async {
        await pumpScreen(tester);
        for (var dart = 0; dart < 3; dart++) {
          await tapKey(tester, '20');
        }
        expect(find.text('20 + 20 + 20 = 60'), findsOneWidget);
      });

      testWidgets('shows only one slot at a time', (tester) async {
        await pumpScreen(tester);
        for (var player = 0; player < 2; player++) {
          for (var dart = 0; dart < 3; dart++) {
            await tapKey(tester, '20');
          }
        }
        // Both have thrown the same visit, so both sums would read alike. Only
        // the slot that threw last shows one.
        expect(find.text('20 + 20 + 20 = 60'), findsOneWidget);
      });

      testWidgets('pins another player when their score is tapped',
          (tester) async {
        await pumpScreen(tester);
        for (var dart = 0; dart < 3; dart++) {
          await tapKey(tester, '20');
        }
        expect(find.byIcon(Icons.push_pin), findsNothing);

        await tapScore(tester, 'Zoe', '0');
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
        // Zoe has thrown nothing, so pinning her clears the sum from view.
        expect(find.text('20 + 20 + 20 = 60'), findsNothing);

        await tapScore(tester, 'Zoe', '0');
        expect(find.byIcon(Icons.push_pin), findsNothing);
        expect(find.text('20 + 20 + 20 = 60'), findsOneWidget);
      });

      testWidgets('shows a halving in the ceiling brackets it was rounded by',
          (tester) async {
        await pumpScreen(tester);
        for (var player = 0; player < 2; player++) {
          for (var dart = 0; dart < 3; dart++) {
            await tapKey(tester, '20');
          }
        }
        // Round one wants a 20, and three misses do not give one.
        for (var dart = 0; dart < 3; dart++) {
          await tapKey(tester, 'Miss');
        }
        expect(find.text('⌈60/2⌉ = 30'), findsOneWidget);
      });
    });

    group('the visit pause', () {
      testWidgets('hands the bottom row of keys over to Continue',
          (tester) async {
        TurnPacing.debugVisitPause = const Duration(hours: 1);
        await pumpScreen(tester);

        for (var dart = 0; dart < 3; dart++) {
          await tapKeyPending(tester, '20');
        }

        expect(provider.visitPending, isTrue);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text('Miss'), findsNothing, reason: 'its place is taken');
        expect(find.text('Bull'), findsNothing);
        // Only the three at the bottom make way. The board itself stays put,
        // dimmed and deaf, so the reader can still read it.
        expect(find.widgetWithText(InkWell, '20'), findsOneWidget);

        // Ending the visit is a real write, let through.
        await tester.runAsync(() async {
          await tester.tap(find.text('Continue'));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();

        expect(provider.visitPending, isFalse);
        expect(find.text('Continue'), findsNothing);
        expect(find.text('Miss'), findsOneWidget);
      });
    });

    group('the window it is given', () {
      testWidgets('keeps one column on a phone', (tester) async {
        await pumpScreen(tester);
        expect(find.byType(SidePaneLayout), findsNothing);
      });

      testWidgets('divides on a landscape tablet', (tester) async {
        await pumpScreen(tester, size: const Size(1180, 820));
        // The keypad is the tall thing, so it takes a pane of its own and
        // leaves the capitals the full height beside it.
        expect(find.byType(SidePaneLayout), findsOneWidget);
        expect(find.widgetWithText(InkWell, '20'), findsOneWidget);
        expect(find.text('Opening round'), findsOneWidget);
      });

      testWidgets('keeps one column on an upright tablet', (tester) async {
        // Upright there is height to spare and width to lose, so dividing
        // would leave both halves too narrow.
        await pumpScreen(tester, size: const Size(820, 1180));
        expect(find.byType(SidePaneLayout), findsNothing);
      });
    });

    group('the live numbers', () {
      testWidgets('open on a tap on the name, as in every other mode',
          (tester) async {
        await pumpScreen(tester);
        for (var dart = 0; dart < 3; dart++) {
          await tapKey(tester, '20');
        }

        await tester.tap(find.text('Ada'));
        await tester.pumpAndSettle();

        expect(find.text('Contracts'), findsOneWidget);
        expect(find.text('Times halved'), findsOneWidget);
        // The opening round is not a contract, so none has been met yet.
        expect(find.text('0/14'), findsOneWidget);
      });

      testWidgets('list every round so far with its arithmetic',
          (tester) async {
        await pumpScreen(tester);
        for (var dart = 0; dart < 3; dart++) {
          await tapKey(tester, '20');
        }

        await tester.tap(find.text('Ada'));
        await tester.pumpAndSettle();

        // The round log rather than the last three visits as chips: a Capital
        // round only means anything against the capital it was thrown at.
        expect(find.text('Rounds so far'), findsOneWidget);
        expect(find.text('20 + 20 + 20 = 60'), findsOneWidget);
        expect(find.text('Last visits'), findsNothing);
      });
    });

    group('leaving', () {
      testWidgets('asks before abandoning a game in progress', (tester) async {
        await pumpScreen(tester);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('Leave Game'), findsOneWidget);
        expect(find.text('Really quit the current game?'), findsOneWidget);
      });
    });
  });
}
