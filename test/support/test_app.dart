import 'package:dartscore_app/l10n/app_localizations.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/providers/players_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Wraps [child] in the localizations and [MaterialApp] a screen needs to
/// build, so a widget test can pump one screen instead of the app.
///
/// Only [PlayersProvider] is supplied by default, and only because several
/// screens read it without depending on its contents. A mode's provider is
/// deliberately *not* handed out: a screen whose provider is missing should
/// fail with a clear ProviderNotFound, not quietly bind to an empty one and
/// spin on its loading indicator forever. Tests wrap their own, with the
/// concrete type, so `Consumer<CricketProvider>` actually finds it.
///
/// The theme providers are left out too: they read shared_preferences, and no
/// screen under test depends on which theme is active.
Widget testApp(
  Widget child, {
  PlayersProvider? players,
  GameProvider? game,
  Locale locale = const Locale('en'),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PlayersProvider>.value(
          value: players ?? PlayersProvider()),
      if (game != null)
        ChangeNotifierProvider<GameProvider>.value(value: game),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: child,
    ),
  );
}

/// Gives the widget a surface tall enough that the screens under test lay out
/// without overflowing, and undoes it afterwards.
///
/// The default test surface is 800x600, which is shorter than any phone these
/// screens were built for, so a scoreboard plus a numpad does not fit and every
/// assertion drowns in overflow errors.
void usePhoneSurface(WidgetTester tester, {Size size = const Size(400, 900)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
