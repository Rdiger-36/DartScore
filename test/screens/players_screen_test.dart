import 'package:dartscore_app/providers/players_provider.dart';
import 'package:dartscore_app/providers/tablet_layout_provider.dart';
import 'package:dartscore_app/screens/player_stats_screen.dart';
import 'package:dartscore_app/screens/players_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

void main() {
  group('the player list', () {
    useInMemoryDatabase();

    late PlayersProvider players;
    late TabletLayoutProvider layout;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      layout = TabletLayoutProvider();
      await insertPlayers(['Ada', 'Zoe']);
      players = PlayersProvider();
    });

    /// Renders the list at [size] with its players loaded.
    Future<void> pumpPlayers(WidgetTester tester, Size size) async {
      await tester.runAsync(players.load);

      usePhoneSurface(tester, size: size);
      await tester.pumpWidget(
        ChangeNotifierProvider<TabletLayoutProvider>.value(
          value: layout,
          child: testApp(const PlayersScreen(), players: players),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Taps the statistics action of the player named [name].
    ///
    /// Bounded pumps rather than a settle: what is asserted is where the pane
    /// goes and whose numbers it is asked for, both of which are decided a
    /// frame later, while the read behind it is real I/O this clock never
    /// reaches. Opening a second player in the same test is deliberately not
    /// covered here, because the second read deadlocks against the first.
    Future<void> openStats(WidgetTester tester, String name) async {
      await tester.tap(find.descendant(
        of: find.ancestor(
          of: find.text(name),
          matching: find.byType(Card),
        ),
        matching: find.byIcon(Icons.bar_chart_rounded),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('opens the statistics beside the list on a tablet',
        (tester) async {
      await pumpPlayers(tester, const Size(1180, 820));

      expect(find.textContaining('Pick a player'), findsOneWidget);

      await openStats(tester, 'Zoe');

      final stats = tester.widget<PlayerStatsScreen>(
          find.byType(PlayerStatsScreen));
      expect(stats.embedded, isTrue);
      expect(stats.player.name, 'Zoe');
      expect(find.textContaining('Pick a player'), findsNothing);

      // Beside: the list is still on screen, to the left of the pane.
      final list = tester.getRect(find.byType(ListView).first);
      final title = tester.getRect(find.textContaining('Zoe ·').first);
      expect(title.left, greaterThan(list.right));
    });

    testWidgets('opens them on top of the list on a phone', (tester) async {
      await pumpPlayers(tester, const Size(390, 844));

      await openStats(tester, 'Zoe');

      final stats = tester.widget<PlayerStatsScreen>(
          find.byType(PlayerStatsScreen));
      expect(stats.embedded, isFalse);
    });

    testWidgets('keeps its two buttons over the list', (tester) async {
      await pumpPlayers(tester, const Size(1180, 820));

      // Both act on the list, so they belong on its side of the divider and
      // not over the statistics, which is where a scaffold would float them.
      final divider = tester.getRect(find.byKey(kPaneDividerKey));
      for (final label in ['Add Player', 'Sync Profile']) {
        final button = tester.getRect(find.widgetWithText(
            FloatingActionButton, label));
        expect(button.right, lessThan(divider.left));
      }
    });
  });
}
