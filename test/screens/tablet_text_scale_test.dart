import 'package:dartscore_app/providers/players_provider.dart';
import 'package:dartscore_app/screens/players_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

void main() {
  group('the text of a list and settings screen', () {
    useInMemoryDatabase();

    /// Renders the players screen at [size] and returns the height its title
    /// takes, which is the text size the reader gets.
    Future<double> titleHeight(WidgetTester tester, Size size) async {
      final players = PlayersProvider();
      await tester.runAsync(players.load);

      usePhoneSurface(tester, size: size);
      await tester.pumpWidget(
          testApp(const PlayersScreen(), players: players));
      await tester.pumpAndSettle();

      return tester.getRect(find.text('Players').first).height;
    }

    testWidgets('grows with the device it is read on', (tester) async {
      final phone = await titleHeight(tester, const Size(390, 844));
      final tablet = await titleHeight(tester, const Size(820, 1180));
      final large = await titleHeight(tester, const Size(1024, 1366));

      expect(tablet, greaterThan(phone));
      expect(large, greaterThan(tablet));
      // And stops growing before it turns into a headline of its own.
      expect(large / phone, lessThan(1.4));
    });

    testWidgets('leaves a phone exactly as it was', (tester) async {
      late double factor;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: Builder(builder: (context) {
          factor = TabletTextScale.factorOf(context);
          return const SizedBox.shrink();
        }),
      ));

      expect(factor, 1.0);
    });
  });
}
