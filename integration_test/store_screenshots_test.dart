import 'dart:async';
import 'dart:io';

import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/main.dart';
import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/providers/theme_provider.dart';
import 'package:dartscore_app/screens/game_screen.dart';
import 'package:dartscore_app/screens/game_summary_screen.dart';
import 'package:dartscore_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the screenshots the App Store and Google Play listings are built
/// from, on whichever simulator or emulator the run is pointed at.
///
/// It is an integration test rather than a widget test on purpose. A widget
/// test paints with the test font and a synthetic window, so its output shows
/// neither the system typeface nor the real safe-area insets; a store listing
/// that ships those pictures shows an app nobody will recognise. Driving the
/// real platform costs a boot per device and buys a pixel-exact screenshot in
/// the size the store asks for.
///
/// Run it through the driver, which writes the PNGs, never through
/// `flutter test`:
///
///     flutter drive \
///       --driver test_driver/store_screenshots_driver.dart \
///       --target integration_test/store_screenshots_test.dart \
///       -d <device id> \
///       --dart-define=device=iphone --dart-define=lang=de
///
/// One run covers one device in one language and shoots every screen in both
/// themes. `tool/store_screenshots.sh` runs the eight combinations and composes
/// the store images from what lands in `store_assets/screenshots/raw/`.
///
/// The screens are reached by driving the app's own providers and pushing the
/// screen, not by tapping through setup. Setup is several localized screens
/// deep, and a screenshot run that navigates by button label breaks the moment
/// a label is reworded.

/// Which device the run is on. Only used to name the files.
const _kDevice = String.fromEnvironment('device', defaultValue: 'device');

/// Language the app is put into before it is launched.
const _kLanguage = String.fromEnvironment('lang', defaultValue: 'en');

/// The themes every screen is shot in, in this order.
///
/// Both are taken inside one run rather than in a run each: reaching a screen
/// costs a boot, an install and a played match, while switching the theme costs
/// a frame.
const _kThemes = [ThemeMode.dark, ThemeMode.light];

/// The two players the demo match is played between, in the language of the
/// run.
///
/// Deliberately generic. A store picture is seen by everyone, so it should not
/// carry a real person's name, and a numbered player also makes it obvious that
/// the app is played by more than one.
List<String> get _playerNames => _kLanguage == 'de'
    ? const ['Spieler 1', 'Spieler 2']
    : const ['Player 1', 'Player 2'];

/// How long a pump may wait before the run is called stuck.
const _kSettleTimeout = Duration(seconds: 30);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    // Android renders into a surface the framework cannot read back. This
    // swaps it for an image the screenshot can be taken from, and it must
    // happen before the first frame.
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      // The status and navigation bars are part of the Android screenshot but
      // not of the iOS one, and the navigation bar comes out as a bright band
      // under the app. Hiding both is what makes the two platforms produce the
      // same picture, and a store image is framed anyway.
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    await _useCleanDatabase();
    await _applyPreferences();
    final players = await _seedPlayers();

    await tester.pumpWidget(const DartScoreApp());
    await _settle(tester);

    await _shootModeSelection(binding, tester);
    await _shootLiveGame(binding, tester, players);
    await _shootSummary(binding, tester);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

// ── Screens ───────────────────────────────────────────────────────────────────

/// Opens the game mode selection from the home screen and shoots it.
Future<void> _shootModeSelection(
    IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester) async {
  // The only entry point that starts a game, and an icon rather than a label,
  // so this survives a reworded button.
  await tester.tap(find.byIcon(Icons.play_arrow_rounded));
  await _settle(tester);

  await _shoot(binding, tester, 'modes');

  Navigator.of(_homeContext(tester)).pop();
  await _settle(tester);
}

/// Plays the demo match up to a checkout and shoots the live X01 screen.
///
/// It stops with the first player standing on 141, which is a finish the
/// suggestion can show in three darts, and the second on 180. Both averages
/// land in the seventies, which is what a club player throws; a scripted
/// hundred would put a number on the store page the app cannot deliver.
Future<void> _shootLiveGame(IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester, List<Player> players) async {
  final provider = _providerOf<GameProvider>(tester);

  await provider.startGame(
    Game(
      startScore:    501,
      legs:          3,
      createdAt:     DateTime.now(),
      startingOrder: StartingOrder.fixed,
    ),
    players,
  );

  // Alternating visits, so after the last one the first player is at the oche.
  for (var visit = 0; visit < _kOpeningVisits.first.length; visit++) {
    for (final script in _kOpeningVisits) {
      await _throwVisit(tester, provider, script[visit]);
    }
  }

  await _pushScreen(tester, const GameScreen());
  await _shoot(binding, tester, 'live');
}

/// Plays the demo match out and shoots the post game summary.
Future<void> _shootSummary(
    IntegrationTestWidgetsFlutterBinding binding, WidgetTester tester) async {
  final provider = _providerOf<GameProvider>(tester);

  var guard = 0;
  while (!provider.gameOver && guard++ < 400) {
    await _throwVisit(
        tester, provider, _planVisit(provider.currentPlayerState.remaining));
  }
  expect(provider.gameOver, isTrue,
      reason: 'the demo match never finished, so there is no summary to shoot');

  // The live screen is still on top of the stack, the way it is when the app
  // itself opens the summary over it.
  await _pushScreen(tester, const GameSummaryScreen());
  await _shoot(binding, tester, 'summary');
}

// ── The demo match ────────────────────────────────────────────────────────────

/// The opening visits of both players, as the darts they threw.
///
/// Written out as darts rather than as totals because the app records every
/// dart: a visit entered as one number would leave the segment statistics and
/// the heatmap on the summary screen empty.
///
/// They add up to 360 for the first player, who is then on 141, and to 321 for
/// the second, who is then on 180.
const _kOpeningVisits = <List<List<(int, int)>>>[
  [
    [(20, 3), (20, 1), (20, 1)], // 100
    [(20, 1), (20, 1), (20, 1)], //  60
    [(20, 3), (20, 1), (1, 1)],  //  81
    [(20, 1), (20, 1), (5, 1)],  //  45
    [(19, 3), (17, 1), (0, 1)],  //  74
  ],
  [
    [(19, 3), (20, 1), (8, 1)],  //  85
    [(20, 1), (20, 1), (20, 1)], //  60
    [(20, 1), (20, 1), (1, 1)],  //  41
    [(20, 3), (20, 1), (20, 1)], // 100
    [(15, 1), (20, 1), (0, 1)],  //  35
  ],
];

/// The visits the rest of the match is played with, in rotation.
///
/// A player who only ever hits the treble twenty finishes 501 in nine darts and
/// leaves a summary showing an average no human throws. These are ordinary
/// visits with ordinary misses.
const _kRallyVisits = <List<(int, int)>>[
  [(20, 3), (20, 1), (5, 1)],   //  85
  [(20, 1), (5, 1), (20, 1)],   //  45
  [(19, 3), (19, 1), (3, 1)],   //  79
  [(20, 1), (20, 1), (20, 1)],  //  60
  [(20, 3), (20, 3), (1, 1)],   // 121
  [(7, 1), (19, 1), (0, 1)],    //  26
  [(20, 3), (20, 1), (20, 1)],  // 100
  [(18, 1), (18, 1), (4, 1)],   //  40
];

/// How many rally visits have been handed out, so the rotation moves on.
int _rallyIndex = 0;

/// Picks the darts for a visit with [remaining] left.
///
/// Above the checkout range it hands back the next rally visit, and inside it
/// a route that finishes on a double, so the match always ends. The route is
/// built here rather than read from [FinishCalculator] because what is needed
/// is the darts to throw, and the calculator answers in labels meant for the
/// hint on the screen.
List<(int, int)> _planVisit(int remaining) {
  if (remaining > 170) {
    final visit = _kRallyVisits[_rallyIndex % _kRallyVisits.length];
    _rallyIndex++;
    // A rally visit that would bust or leave one point is replaced by a plain
    // sixty, which no score above 170 can bust on.
    final scored = visit.fold(0, (sum, d) => sum + _scoreOf(d));
    final left = remaining - scored;
    if (left < 2) return const [(20, 1), (20, 1), (20, 1)];
    return visit;
  }
  return _checkoutRoute(remaining);
}

/// Darts that take [remaining] (at most 170) down to zero on a double.
List<(int, int)> _checkoutRoute(int remaining) {
  final darts = <(int, int)>[];
  var left = remaining;

  while (darts.length < 3) {
    if (left == 50) {
      darts.add((25, 2));
      return darts;
    }
    if (left <= 40 && left.isEven) {
      darts.add((left ~/ 2, 2));
      return darts;
    }
    // Everything else is reduced towards 32, the double sixteen every player
    // is taught to leave, and an odd rest is made even with a single one.
    final (int, int) dart;
    if (left <= 40) {
      dart = (1, 1);
    } else if (left - 32 >= 1 && left - 32 <= 20) {
      dart = (left - 32, 1);
    } else if (left - 32 >= 3 && (left - 32) % 3 == 0 && (left - 32) ~/ 3 <= 20) {
      dart = ((left - 32) ~/ 3, 3);
    } else {
      dart = (20, 3);
    }
    darts.add(dart);
    left -= _scoreOf(dart);
  }
  return darts;
}

/// Points the dart [d] is worth, the bull included.
int _scoreOf((int, int) d) => switch (d.$1) {
      0  => 0,
      25 => d.$2 == 2 ? 50 : 25,
      _  => d.$1 * d.$2,
    };

/// Enters [darts] through the provider, one dart at a time.
///
/// It stops early when the visit has already ended, which is what a checkout
/// does: the provider moves the turn on and the darts still in the list belong
/// to nobody.
Future<void> _throwVisit(WidgetTester tester, GameProvider provider,
    List<(int, int)> darts) async {
  for (var i = 0; i < darts.length; i++) {
    await provider.tapField(darts[i].$1, darts[i].$2);
    await tester.pump();
    if (provider.gameOver) return;
    // A visit that is empty again before its last dart was submitted by the
    // provider, which only happens on a checkout. The darts still in the list
    // would land on the next player.
    if (i < darts.length - 1 && provider.dartsInVisit == 0) return;
  }
}

// ── Setup ─────────────────────────────────────────────────────────────────────

/// Points [DbHelper] at an empty database of its own and removes what a
/// previous run left there.
///
/// The app's own database is left untouched, so a screenshot run cannot
/// overwrite whatever is on the device, and every run starts from the same
/// empty state rather than from the match the last one played.
Future<void> _useCleanDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/store_screenshots.db';
  await DbHelper.debugReset();
  final file = File(path);
  if (file.existsSync()) await file.delete();
  DbHelper.debugDatabasePath = path;
}

/// Puts the app into the language this run shoots, before it starts.
///
/// [LanguageProvider] reads shared_preferences in its constructor, so writing
/// the value first is what makes the very first frame already carry it. The
/// theme is set per screenshot instead, through its provider.
Future<void> _applyPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('language_code', _kLanguage);
  await prefs.setString('theme_mode', _kThemes.first.name);
}

/// Inserts the demo players and makes the first one primary, so the app opens
/// on the home screen instead of the onboarding.
Future<List<Player>> _seedPlayers() async {
  final db = DbHelper.instance;
  final names = _playerNames;
  final players = <Player>[];
  for (final name in names) {
    final id = await db.insertPlayer(Player(
      name: name,
      // A favorite double changes what the checkout hint suggests, and a hint
      // that shows one is the more interesting picture.
      favoriteDoubles: name == names.first ? 'D16' : 'D20',
    ));
    players.add((await db.getPlayer(id))!);
  }
  await db.setPrimaryPlayer(players.first.id!);
  return players;
}

// ── Plumbing ──────────────────────────────────────────────────────────────────

/// The context of the home screen, which is where both the providers and the
/// navigator are reached from.
///
/// [skipOffstage] is off because a pushed route takes the home screen off the
/// stage without unmounting it, and every screenshot after the first is taken
/// with something on top of it.
Element _homeContext(WidgetTester tester) =>
    tester.element(find.byType(HomeScreen, skipOffstage: false));

/// The provider of type [T] the running app holds.
T _providerOf<T>(WidgetTester tester) => _homeContext(tester).read<T>();

/// Pushes [screen] onto the running app's navigator and settles.
///
/// The push future only completes when the screen is popped again, so it is
/// deliberately not awaited.
Future<void> _pushScreen(WidgetTester tester, Widget screen) async {
  final navigator = Navigator.of(_homeContext(tester));
  unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => screen)));
  await _settle(tester);
}

/// Waits for the app to come to rest, giving a database read time to finish.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
      const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate,
      _kSettleTimeout);
}

/// Takes the screenshot [name] of the current screen, once per theme.
///
/// It leaves the app in the first theme of [_kThemes], so the screen that
/// follows starts from the same place this one did.
Future<void> _shoot(IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester, String name) async {
  final theme = _providerOf<ThemeProvider>(tester);
  for (final mode in _kThemes) {
    await theme.setMode(mode);
    // A screenshot is taken outside the test's own frame scheduling, so the
    // theme crossfade has to have finished first.
    await _settle(tester);
    await binding.takeScreenshot('$_kDevice/${mode.name}/$_kLanguage/$name');
  }
  await theme.setMode(_kThemes.first);
  await _settle(tester);
}
