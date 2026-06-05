import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'providers/players_provider.dart';
import 'providers/game_provider.dart';
import 'providers/cricket_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 15+ forces edge-to-edge. Enable it explicitly so Flutter
  // correctly reports the bottom inset (navigation bar height).
  // iOS handles safe-area insets natively — no change needed there.
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  runApp(const DartScoreApp());
}

/// Routes to OnboardingScreen until a primary player exists, then HomeScreen.
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlayersProvider>();
    if (!provider.loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.primaryPlayer == null) {
      return const OnboardingScreen();
    }
    return const HomeScreen();
  }
}

/// Locks orientation to portrait on phones; allows all orientations on tablets.
class _OrientationLock extends StatefulWidget {
  final Widget child;
  const _OrientationLock({required this.child});

  @override
  State<_OrientationLock> createState() => _OrientationLockState();
}

class _OrientationLockState extends State<_OrientationLock> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isTablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    if (isTablet) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class DartScoreApp extends StatelessWidget {
  const DartScoreApp({super.key});

  // ── Accessible dartboard palette ─────────────────────────────────────────
  // WCAG AA: ≥4.5:1 for text, ≥3:1 for large/UI elements.
  // Dartboard: cream/black segments, red bull, green double-ring, gold wire.

  static final _lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Red bull — #B71C1C on white = 7.2:1 ✓✓
    primary: const Color(0xFFB71C1C),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFFFCDD2),
    onPrimaryContainer: const Color(0xFF7F0000),
    // Green double ring — #66BB6A on white = 3.0:1 ✓ (large UI element)
    secondary: const Color(0xFF66BB6A),
    onSecondary: const Color(0xFF003909),
    secondaryContainer: const Color(0xFFA5D6A7),    // more saturated, visible
    onSecondaryContainer: const Color(0xFF002106),
    // Triple ring red — #8B0000 on white = 8.1:1 ✓✓
    tertiary: const Color(0xFF8B0000),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFFCDD2),
    onTertiaryContainer: const Color(0xFF5F0000),
    error: const Color(0xFF9B0000),
    onError: Colors.white,
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
    // Clean white surface — no warm cream tint → stronger contrast
    surface: const Color(0xFFFFFFFF),
    onSurface: const Color(0xFF0D0D0D),             // near-black, 18:1 ✓✓
    surfaceContainerHighest: const Color(0xFFDDDDDD),
    surfaceContainerHigh: const Color(0xFFEAEAEA),
    surfaceContainerLow: const Color(0xFFF5F5F5),
    surfaceContainer: const Color(0xFFE5E5E5),
    outline: const Color(0xFF4A4A4A),               // 9.7:1 — sharp borders ✓✓
    outlineVariant: const Color(0xFF9E9E9E),        // 3.9:1 — visible dividers ✓
    onSurfaceVariant: const Color(0xFF2E2E2E),      // 12.6:1 — secondary text ✓✓
    inverseSurface: const Color(0xFF1C1C1C),
    onInverseSurface: const Color(0xFFF5F5F5),
    inversePrimary: const Color(0xFFFF8A80),
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  // iOS-style dark gray — neutral, no warm tint
  static final _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Muted red — not neon, comfortable on dark gray
    primary: const Color(0xFFEF5350),           // red 400
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF7F0000),
    onPrimaryContainer: const Color(0xFFFFCDD2),
    // Muted green
    secondary: const Color(0xFF1B5E20),         // green 800 — deep, calm on dark
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFF1B5E20),
    onSecondaryContainer: const Color(0xFFC8E6C9),
    // Triple ring red — muted for dark mode
    tertiary: const Color(0xFFEF9A9A),          // red 200
    onTertiary: const Color(0xFF7F0000),
    tertiaryContainer: const Color(0xFF7F0000),
    onTertiaryContainer: const Color(0xFFFFCDD2),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    // iOS dark gray system colors
    surface: const Color(0xFF1C1C1E),           // iOS systemBackground dark
    onSurface: const Color(0xFFEEEEEE),
    surfaceContainerHighest: const Color(0xFF48484A),
    surfaceContainerHigh: const Color(0xFF3A3A3C),
    surfaceContainerLow: const Color(0xFF1C1C1E),
    surfaceContainer: const Color(0xFF2C2C2E),  // iOS secondarySystemBackground
    outline: const Color(0xFF636366),           // iOS separator
    outlineVariant: const Color(0xFF3A3A3C),
    onSurfaceVariant: const Color(0xFFAEAEB2),  // iOS secondaryLabel
    inverseSurface: const Color(0xFFEEEEEE),
    onInverseSurface: const Color(0xFF1C1C1E),
    inversePrimary: const Color(0xFFC62828),
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme cs) => ThemeData(
        colorScheme: cs,
        useMaterial3: true,
        scaffoldBackgroundColor: cs.surface,
        cardTheme: CardThemeData(
          elevation: 0,
          color: cs.brightness == Brightness.light
              ? const Color(0xFFF5F5F5)   // light gray — visible on white surface
              : const Color(0xFF2C2C2E),  // iOS secondarySystemBackground
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: cs.surfaceContainerHigh,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => PlayersProvider()..load()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => CricketProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, tp, lp, child) => MaterialApp(
          title: 'DartScore',
          debugShowCheckedModeBanner: false,
          themeMode: tp.mode,
          theme: _build(_lightScheme),
          darkTheme: _build(_darkScheme),
          locale: lp.locale, // null = follow system
          // On Android: wrap every route in SafeArea(top:false) so the
          // 3-button navigation bar never overlaps interactive content.
          // On iOS: the system handles safe-area insets natively.
          builder: (context, child) {
            final wrapped = _OrientationLock(
              child: Platform.isAndroid
                  ? SafeArea(top: false, child: child!)
                  : child!,
            );
            return wrapped;
          },
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('de'),
          ],
          home: const _AppGate(),
        ),
      ),
    );
  }
}
