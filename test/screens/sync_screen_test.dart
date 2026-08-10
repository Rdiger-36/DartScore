import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/players_provider.dart';
import 'package:dartscore_app/screens/sync_screen.dart';
import 'package:dartscore_app/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/test_app.dart';
import '../support/test_db.dart';

/// The sync screen, minus the camera. Tapping "Scan QR code" is what starts
/// MobileScanner, so everything up to that point renders without a camera and
/// without the plugin being involved at all.
///
/// Every throw is seeded in `setUp`, never in a test body: seeding writes rows,
/// and a widget test runs in fake async where a real database write never
/// completes.
void main() {
  late Player player;
  late PlayersProvider players;

  /// Pumps the screen and lets the payload finish being built.
  ///
  /// Preparing reads the player's throws out of the database, which is real I/O
  /// that fake async never gets to, so it is let through explicitly. Nothing
  /// here settles: an animated transfer shows an indeterminate progress bar,
  /// and `pumpAndSettle` would wait on an animation that never ends.
  Future<void> pumpSync(WidgetTester tester, {Player? initial}) async {
    usePhoneSurface(tester, size: const Size(400, 1400));
    await tester.pumpWidget(
        testApp(SyncScreen(initialPlayer: initial), players: players));

    // Preparing reads the throws and encodes them, and how long that takes
    // depends on how many there are, so wait for the code rather than for a
    // guessed duration. A fixed delay is either flaky or slow.
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      if (initial == null || find.byType(QrImageView).evaluate().isNotEmpty) {
        break;
      }
    }
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('the sync screen with a short history', () {
    useInMemoryDatabase();

    setUp(() async {
      player = (await insertPlayers(['Nik'])).single;
      await seedThrows(player.id!, 5);
      players = PlayersProvider();
      await players.load();
    });

    testWidgets('opens on Receive when it was not given a player',
        (tester) async {
      await pumpSync(tester);

      expect(find.text('Scan QR code'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('starts no camera until the user asks for one', (tester) async {
      // The receiver tab builds without MobileScanner. If that ever changed,
      // opening the screen would take the camera on every visit, which is the
      // sort of thing nobody notices until a green dot appears.
      await pumpSync(tester);

      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Scan QR code'), findsOneWidget);
    });

    testWidgets('opens on Send when it was handed one, showing one still code',
        (tester) async {
      await pumpSync(tester, initial: player);

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Nik'), findsWidgets);
    });

    testWidgets('offers every range to pick from', (tester) async {
      await pumpSync(tester, initial: player);

      expect(find.byType(ChoiceChip), findsNWidgets(SyncRange.values.length));
    });

    testWidgets('a still code does not tick', (tester) async {
      // Only the animated transport has a frame loop. A payload that fits in
      // one code must not be re-encoding itself ten times a second.
      await pumpSync(tester, initial: player);
      final before = tester.widget<QrImageView>(find.byType(QrImageView));

      await tester.pump(const Duration(milliseconds: 500));

      expect(
          identical(
              tester.widget<QrImageView>(find.byType(QrImageView)), before),
          isTrue);
    });
  });

  group('the sync screen with a history too large for one code', () {
    useInMemoryDatabase();

    setUp(() async {
      player = (await insertPlayers(['Nik'])).single;
      // Enough visits that the payload outgrows a single code and the sender
      // falls back to the animated transport, the one with a loop to stop.
      await seedThrows(player.id!, 3000);
      players = PlayersProvider();
      await players.load();
    });

    /// The code itself is not readable off the widget, but every tick rebuilds
    /// it, so a fresh instance means the loop ran and the same one means it
    /// did not.
    QrImageView code(WidgetTester tester) =>
        tester.widget<QrImageView>(find.byType(QrImageView));

    /// Lets the frame loop run for several ticks and draws the result.
    ///
    /// The frame timer is a fake one despite the payload being prepared inside
    /// `runAsync`, so the fake clock is what moves it. Letting real time pass
    /// does nothing at all here.
    Future<void> letFramesRun(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 400));

    testWidgets('cycles through frames', (tester) async {
      await pumpSync(tester, initial: player);
      final before = code(tester);

      await letFramesRun(tester);

      expect(identical(code(tester), before), isFalse);
    });

    testWidgets('stops advancing once the app goes to the background',
        (tester) async {
      await pumpSync(tester, initial: player);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final atPause = code(tester);
      await letFramesRun(tester);

      expect(identical(code(tester), atPause), isTrue,
          reason: 'a sender nobody can see should not keep encoding');
    });

    testWidgets('picks up again when the app comes back', (tester) async {
      await pumpSync(tester, initial: player);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await letFramesRun(tester);
      final whileAway = code(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await letFramesRun(tester);

      expect(identical(code(tester), whileAway), isFalse);
    });
  });
}
