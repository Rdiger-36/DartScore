import 'package:dartscore_app/models/capital_game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/capital_provider.dart';
import 'package:dartscore_app/screens/capital_screen.dart';
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
    Future<void> pumpScreen(WidgetTester tester) async {
      usePhoneSurface(tester, size: const Size(400, 900));
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
      await tester.tap(find.widgetWithText(FilledButton, label).first);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
    }

    /// The fill of the key labelled [label].
    Color keyColor(WidgetTester tester, String label) {
      final button =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, label).first);
      return button.style!.backgroundColor!
          .resolve(<WidgetState>{}) as Color;
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
        await tester.tap(find.widgetWithText(FilledButton, 'Double'));
        await tester.pumpAndSettle();

        expect(keyColor(tester, '20'), BoardPaint.red);
        expect(keyColor(tester, '1'), BoardPaint.green);
      });

      testWidgets('returns to singles after a dart, so a ring is never sticky',
          (tester) async {
        await pumpScreen(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Triple'));
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

      testWidgets('pins another player when their row is tapped',
          (tester) async {
        await pumpScreen(tester);
        for (var dart = 0; dart < 3; dart++) {
          await tapKey(tester, '20');
        }
        expect(find.byIcon(Icons.push_pin), findsNothing);

        await tester.tap(find.text('Zoe'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.push_pin), findsOneWidget);
        // Zoe has thrown nothing, so pinning her clears the sum from view.
        expect(find.text('20 + 20 + 20 = 60'), findsNothing);

        await tester.tap(find.text('Zoe'));
        await tester.pumpAndSettle();
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
