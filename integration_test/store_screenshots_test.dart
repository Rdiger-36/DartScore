import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/l10n/app_localizations.dart';
import 'package:dartscore_app/main.dart';
import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/providers/theme_provider.dart';
import 'package:dartscore_app/screens/game_screen.dart';
import 'package:dartscore_app/screens/home_screen.dart';
import 'package:dartscore_app/screens/player_stats_screen.dart';
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
/// the store images from what lands in
/// `store_assets/screenshots/raw/<device>/<screen>_<theme>_<language>.png`.
///
/// The screens are reached by driving the app's own providers and pushing the
/// screen, not by tapping through setup. Setup is several localized screens
/// deep, and a screenshot run that navigates by button label breaks the moment
/// a label is reworded.
///
/// Five screens are shot, in this order: the mode selection, the top of the
/// player statistics, its dartboard heatmap, a two player X01 leg and a solo
/// X01 leg. The statistics come from a season of games the run plays first, so
/// the numbers on those two pictures are the numbers this app produces out of
/// ordinary club darts.

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

/// The two players the demo games are played between, in the language of the
/// run.
///
/// Deliberately generic. A store picture is seen by everyone, so it should not
/// carry a real person's name, and a numbered player also makes it obvious that
/// the app is played by more than one.
List<String> get _playerNames => _kLanguage == 'de'
    ? const ['Spieler 1', 'Spieler 2']
    : const ['Player 1', 'Player 2'];

/// The score every demo game is played from.
const _kStartScore = 501;

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

    // Before the first screenshot, because the statistics pictures show what
    // it produced and the live pictures should not be part of it.
    await _seedHistory(tester, players);

    await _shootModeSelection(binding, tester);
    await _shootPlayerStats(binding, tester, players.first);
    await _shootDuoGame(binding, tester, players);
    await _shootSoloGame(binding, tester, players.first);
  }, timeout: const Timeout(Duration(minutes: 30)));
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
  await _popScreen(tester);
}

/// Shoots the two statistics pictures of [player]: the top of the screen with
/// the average and the highlight tiles, and the dartboard heatmap further down.
///
/// The heatmap is scrolled to rather than shot from a fixed offset. The list
/// above it grows with every section that gets added, and an offset in pixels
/// would quietly start showing the wrong card.
Future<void> _shootPlayerStats(IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester, Player player) async {
  await _pushScreen(tester, PlayerStatsScreen(player: player));
  // The screen counts every throw the player ever made in another isolate, so
  // the first frames are a spinner.
  await _settle(tester);

  await _shoot(binding, tester, 'stats_header');

  final title = find.text(_homeContext(tester).l10n.dartboardHeatmap);
  final list  = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  await tester.dragUntilVisible(title, list, const Offset(0, -320));
  await _settle(tester);
  // The drag stops as soon as the title is on screen, which leaves it at the
  // bottom edge with the heatmap itself still below it.
  await Scrollable.ensureVisible(tester.element(title),
      alignment: 0.03, duration: Duration.zero);
  await _settle(tester);

  await _shoot(binding, tester, 'stats_heatmap');
  await _popScreen(tester);
}

/// Plays a two player leg up to a checkout and shoots the live X01 screen.
///
/// It stops with the first player standing on 141, which is a finish the
/// suggestion shows in three darts, and the second on 180. Both are six visit
/// legs in the sixties, the same range the seeded season averages, so the live
/// picture and the statistics pictures do not contradict each other.
Future<void> _shootDuoGame(IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester, List<Player> players) async {
  final provider = _providerOf<GameProvider>(tester);
  await _startGame(provider, players);

  // Alternating visits, so after the last one the first player is at the oche.
  for (var visit = 0; visit < _kDuoVisits.first.length; visit++) {
    for (final script in _kDuoVisits) {
      await _throwVisit(tester, provider, script[visit]);
    }
  }

  await _pushScreen(tester, const GameScreen());
  await _shoot(binding, tester, 'live_duo');
  await _popScreen(tester);
}

/// Plays a solo leg and shoots the live X01 screen with a single player on it.
///
/// It stops on 96, a two dart finish, so the two live pictures do not show the
/// same checkout twice.
Future<void> _shootSoloGame(IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester, Player player) async {
  final provider = _providerOf<GameProvider>(tester);
  await _startGame(provider, [player]);

  for (final visit in _kSoloVisits) {
    await _throwVisit(tester, provider, visit);
  }

  await _pushScreen(tester, const GameScreen());
  await _shoot(binding, tester, 'live_solo');
  await _popScreen(tester);
}

// ── The demo games ────────────────────────────────────────────────────────────

/// Starts a 501 game over three legs between [players], in the order given.
Future<void> _startGame(GameProvider provider, List<Player> players) {
  return provider.startGame(
    Game(
      startScore:    _kStartScore,
      legs:          3,
      createdAt:     DateTime.now(),
      startingOrder: StartingOrder.fixed,
    ),
    players,
  );
}

/// The visits of the two player leg, as the darts they threw.
///
/// Written out as darts rather than as totals because the app records every
/// dart: a visit entered as one number would leave the segment statistics and
/// the heatmap empty.
///
/// They add up to 360 for the first player, who is then on 141, and to 321 for
/// the second, who is then on 180.
const _kDuoVisits = <List<List<(int, int)>>>[
  [
    [(20, 3), (20, 1), (20, 1)], // 100
    [(20, 3), (20, 1), (1, 1)],  //  81
    [(20, 1), (20, 1), (5, 1)],  //  45
    [(20, 1), (20, 1), (20, 1)], //  60
    [(7, 1), (19, 1), (0, 1)],   //  26
    [(20, 1), (20, 1), (8, 1)],  //  48
  ],
  [
    [(19, 3), (20, 1), (8, 1)],  //  85
    [(20, 1), (20, 1), (20, 1)], //  60
    [(20, 1), (20, 1), (1, 1)],  //  41
    [(20, 1), (20, 1), (5, 1)],  //  45
    [(17, 3), (4, 1), (0, 1)],   //  55
    [(15, 1), (20, 1), (0, 1)],  //  35
  ],
];

/// The visits of the solo leg. They add up to 405, which leaves 96.
const _kSoloVisits = <List<(int, int)>>[
  [(20, 3), (20, 1), (20, 1)], // 100
  [(20, 3), (20, 1), (1, 1)],  //  81
  [(20, 1), (20, 1), (5, 1)],  //  45
  [(7, 1), (19, 1), (0, 1)],   //  26
  [(20, 1), (20, 1), (20, 1)], //  60
  [(20, 1), (20, 1), (1, 1)],  //  41
  [(17, 3), (1, 1), (0, 1)],   //  52
];

/// Enters [darts] through the provider, one dart at a time.
///
/// It stops early when the visit has already ended, which is what a checkout
/// and a bust do: the provider moves the turn on and the darts still in the
/// list belong to nobody.
Future<void> _throwVisit(WidgetTester tester, GameProvider provider,
    List<(int, int)> darts) async {
  for (var i = 0; i < darts.length; i++) {
    await provider.tapField(darts[i].$1, darts[i].$2);
    if (provider.gameOver) return;
    if (i < darts.length - 1 && provider.dartsInVisit == 0) return;
  }
  await tester.pump();
}

// ── The seeded season ─────────────────────────────────────────────────────────

/// The games the statistics are counted from, as how many days ago each was
/// played.
///
/// They are spread over the last six weeks, with two of them inside this week
/// and three inside the last one, so the week comparison card has both of its
/// columns filled. The dates are written onto the rows afterwards; the games
/// themselves are played now, because a provider timestamps what it records.
const _kSeasonDaysAgo = [40, 37, 33, 30, 26, 24, 19, 17, 12, 10, 4, 2];

/// Which seeded game opens with a maximum, and which slot throws it.
///
/// A player who throws around sixty hits a 180 every few hundred visits, which
/// over a season this size is a coin flip. Placing three of them by hand is
/// what keeps the highlight tiles from reading as zeroes on one run and as
/// twos on the next, and three in twelve games is what an amateur board sees.
const _kMaximumIn = <int, int>{2: 0, 5: 1, 9: 0};

/// How accurate a seeded player is, as the share of darts that land where they
/// were aimed.
///
/// Amateur numbers on purpose. The averages these produce sit in the fifties
/// and low sixties and the checkout rate around a third, which is what a club
/// player throws; a store page that advertises a hundred average describes an
/// app for somebody else.
class _Skill {
  /// Darts aimed at a treble that land in it.
  final double treble;

  /// Darts aimed at a field that land in its single, the treble missed
  /// included.
  final double single;

  /// Darts aimed at a double that land in it.
  final double doubleOut;

  const _Skill({
    required this.treble,
    required this.single,
    required this.doubleOut,
  });
}

/// The two profiles, the first player being the slightly stronger one.
const _kSkills = [
  _Skill(treble: 0.12, single: 0.56, doubleOut: 0.34),
  _Skill(treble: 0.09, single: 0.55, doubleOut: 0.28),
];

/// The board's fields in the order they sit around it, so a dart that misses
/// its field lands in one that really is next to it.
const _kBoardRing = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
];

/// Plays the season the statistics screens show and backdates it.
///
/// The games run through [GameProvider] rather than being written into the
/// database directly. Whether a visit was an attempt at the finish is decided
/// once, when the visit is recorded, and a row inserted behind the provider's
/// back would carry a `checkout_darts` somebody had to guess.
Future<void> _seedHistory(WidgetTester tester, List<Player> players) async {
  final provider = _providerOf<GameProvider>(tester);
  // Fixed, so both languages and all four devices show the same numbers.
  final rng = Random(20260819);

  for (var index = 0; index < _kSeasonDaysAgo.length; index++) {
    // Alternating, so neither player throws first in every game.
    final order = index.isEven ? players : players.reversed.toList();
    await _startGame(provider, order);
    final gameId = provider.game!.id!;

    var maximumLeft = _kMaximumIn.containsKey(index);
    var guard = 0;
    while (!provider.gameOver && guard++ < 900) {
      final slot = provider.currentPlayerIndex;
      // The slot order was reversed for half the games, so the skill follows
      // the player rather than the seat.
      final player = provider.currentPlayerState.player;
      final skill  = _kSkills[players.indexWhere((p) => p.id == player.id)];

      if (maximumLeft &&
          _kMaximumIn[index] == (index.isEven ? slot : 1 - slot) &&
          provider.currentPlayerState.remaining == _kStartScore) {
        maximumLeft = false;
        await _throwVisit(tester, provider,
            const [(20, 3), (20, 3), (20, 3)]);
        continue;
      }

      await _throwSeededVisit(provider, rng, skill);
    }
    expect(provider.gameOver, isTrue,
        reason: 'seeded game $index never finished');

    await tester.pump();
    await _backdate(gameId, Duration(days: _kSeasonDaysAgo[index]));
  }
}

/// Throws one visit of a seeded game, dart by dart.
///
/// Every dart is aimed at what the score in front of it asks for and then
/// scattered by the player's own accuracy, so the busts, the missed doubles and
/// the ton visits in the statistics are all thrown rather than counted out.
Future<void> _throwSeededVisit(
    GameProvider provider, Random rng, _Skill skill) async {
  for (var dart = 0; dart < 3; dart++) {
    final aim = _aimFor(provider.liveRunningRemaining);
    final hit = _land(rng, skill, aim.$1, aim.$2);
    await provider.tapField(hit.$1, hit.$2);
    if (provider.gameOver) return;
    // Empty again before the third dart means the provider closed the visit,
    // which is a checkout or a bust.
    if (dart < 2 && provider.dartsInVisit == 0) return;
  }
}

/// What a player aims at with [remaining] left.
///
/// Above the checkout range that is the treble twenty. Inside it, the double
/// when the rest is one, the treble that leaves an even rest of at most forty
/// when it is three, and the single that makes an odd rest even in between.
(int, int) _aimFor(int remaining) {
  if (remaining > 170) return (20, 3);
  if (remaining == 50) return (25, 2);
  if (remaining <= 40 && remaining.isEven) return (remaining ~/ 2, 2);
  // An odd rest under forty is made even with a single one, which is the shot
  // every player is taught rather than the one a table would pick.
  if (remaining <= 40) return (1, 1);
  if (remaining <= 60) {
    final setup = remaining - 40;
    if (setup >= 1 && setup <= 20) return (setup, 1);
    return (20, 1);
  }
  for (final field in [20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10]) {
    final left = remaining - field * 3;
    if (left >= 2 && left <= 40 && left.isEven) return (field, 3);
  }
  return (20, 3);
}

/// Where a dart aimed at [field] with [multiplier] actually lands.
(int, int) _land(Random rng, _Skill skill, int field, int multiplier) {
  final roll = rng.nextDouble();

  if (field == 25) {
    if (roll < skill.doubleOut) return (25, 2);
    if (roll < skill.doubleOut + 0.30) return (25, 1);
    return (_beside(rng, 20), 1);
  }

  switch (multiplier) {
    case 3:
      if (roll < skill.treble) return (field, 3);
      if (roll < skill.treble + skill.single) return (field, 1);
      if (roll < skill.treble + skill.single + 0.05) return (_beside(rng, field), 3);
      if (roll < skill.treble + skill.single + 0.09) return (0, 1);
      return (_beside(rng, field), 1);
    case 2:
      if (roll < skill.doubleOut) return (field, 2);
      // A double missed inwards is the single of the same number, which is
      // what leaves the odd rest the next visit has to repair.
      if (roll < skill.doubleOut + 0.30) return (field, 1);
      if (roll < skill.doubleOut + 0.42) return (_beside(rng, field), 1);
      // Everything else went over the wire, off the board.
      return (0, 1);
    default:
      if (roll < 0.74) return (field, 1);
      if (roll < 0.78) return (field, 3);
      if (roll < 0.94) return (_beside(rng, field), 1);
      return (0, 1);
  }
}

/// One of the two fields sitting next to [field] on the board.
int _beside(Random rng, int field) {
  final at = _kBoardRing.indexOf(field);
  if (at < 0) return field;
  final step = rng.nextBool() ? 1 : -1;
  return _kBoardRing[(at + step + _kBoardRing.length) % _kBoardRing.length];
}

/// Moves the game [gameId] and every throw of it [by] into the past.
///
/// A provider stamps what it records with the moment it recorded it, so a
/// season played in one run would all land on today: no week comparison, and
/// an activity that is one very busy day. Rewriting the timestamps afterwards
/// keeps the order inside a game and only moves the whole game.
///
/// The raw statement is the one place in the project that writes SQL outside
/// `db_helper.dart`. It exists for the screenshots only, and the app has no
/// reason to ever backdate a game.
Future<void> _backdate(int gameId, Duration by) async {
  final db = await DbHelper.instance.db;
  final ms = by.inMilliseconds;
  await db.rawUpdate(
      'UPDATE games SET created_at = created_at - ?, '
      'finished_at = finished_at - ? WHERE id = ?',
      [ms, ms, gameId]);
  await db.rawUpdate(
      'UPDATE dart_throws SET thrown_at = thrown_at - ? WHERE game_id = ?',
      [ms, gameId]);
}

// ── Setup ─────────────────────────────────────────────────────────────────────

/// Points [DbHelper] at an empty database of its own and removes what a
/// previous run left there.
///
/// The app's own database is left untouched, so a screenshot run cannot
/// overwrite whatever is on the device, and every run starts from the same
/// empty state rather than from the season the last one played.
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

/// Pops whatever the last screenshot was taken on, back to the home screen.
Future<void> _popScreen(WidgetTester tester) async {
  Navigator.of(_homeContext(tester)).pop();
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
/// The theme and the language go into the file name rather than into folders
/// above it, so a raw picture says what it is wherever it is looked at, a
/// review folder and a chat window included.
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
    await binding.takeScreenshot(
        '$_kDevice/${name}_${mode.name}_$_kLanguage');
  }
  await theme.setMode(_kThemes.first);
  await _settle(tester);
}
