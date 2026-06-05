# DartScore App

Flutter-based dart scoring tracker for Android and iOS.

## Commands

```bash
# Run app (connected device or emulator)
flutter run

# Build Android APK (debug)
flutter build apk --debug

# Build Android APK (release)
flutter build apk --release

# Build iOS (release)
flutter build ios --release

# Run tests
flutter test

# Lint check (run after every change)
flutter analyze

# Generate launcher icons
dart run flutter_launcher_icons
```

## Tech Stack

- Flutter + Dart (SDK ^3.12.0)
- `sqflite` — SQLite local database
- `provider` — state management
- `shared_preferences` — lightweight key/value persistence
- `mobile_scanner` + `qr_flutter` — QR-based sync between devices
- `share_plus` + `gal` — export/share functionality
- `intl` + `flutter_localizations` — i18n (English/German)

## Architecture

```
lib/
├── main.dart                  # App entry point, provider setup, theme/locale init
├── database/
│   └── db_helper.dart         # Singleton SQLite wrapper; all schema definitions and migrations live here
├── models/
│   ├── player.dart            # Player entity with favorite doubles
│   ├── game.dart              # Game entity; GameMode and CheckoutMode enums
│   └── dart_throw.dart        # Single throw record (value, multiplier, bust flag)
├── providers/
│   ├── players_provider.dart  # Player CRUD; loads from DB, notifies listeners
│   ├── game_provider.dart     # Active game state machine; score calc, bust detection, turn logic
│   ├── theme_provider.dart    # Light/dark theme toggle, persisted via shared_preferences
│   └── language_provider.dart # Locale switching (en/de), persisted via shared_preferences
├── screens/
│   ├── home_screen.dart           # Entry screen with navigation to setup, history, players
│   ├── onboarding_screen.dart     # First-launch walkthrough
│   ├── game_setup_screen.dart     # Configure start score, in/out modes, legs/sets, player selection
│   ├── game_screen.dart           # Live game: scoreboard, numpad, finish suggestions, undo
│   ├── game_summary_screen.dart   # Post-game stats: winner, averages, throw history
│   ├── history_screen.dart        # List of all past games
│   ├── history_game_summary_screen.dart  # Detailed view of a past game
│   ├── players_screen.dart        # Player management list
│   ├── player_stats_screen.dart   # Per-player lifetime stats
│   ├── settings_screen.dart       # Theme, language, data management
│   └── sync_screen.dart           # QR-based device-to-device data sync
├── services/
│   └── sync_service.dart      # Encode/decode game data for QR sync
├── widgets/
│   ├── numpad.dart                 # Numeric input pad for score entry
│   ├── dartboard_input.dart        # Dartboard-style tap input
│   ├── dartboard_icon.dart         # Decorative dartboard SVG widget
│   ├── finish_suggestion_widget.dart  # Checkout hint display
│   └── player_dialog.dart          # Create/edit player dialog
├── utils/
│   ├── finish_calculator.dart  # Static checkout table up to 170, respects player's favorite doubles
│   └── layout.dart             # Shared layout helpers/constants
└── l10n/
    └── app_localizations.dart  # Generated localization strings
```

### Data flow

1. Screens read state via `context.watch<XProvider>()`
2. Screens trigger actions via `context.read<XProvider>().method()`
3. Providers call `db_helper.dart` for persistence and call `notifyListeners()`
4. No widget accesses the database directly

## Coding Rules

- All code comments, commit messages, and PR descriptions must be in **English**
- Never use em dashes (`—`) in commit messages or PR titles/descriptions; use a hyphen (`-`) or rephrase
- Always create a **new branch** before making changes when the current branch is `main`
- Both platforms (Android and iOS) must be considered for every change; flag platform-specific implications when relevant
- No inline comments unless the WHY is non-obvious (hidden constraint, workaround, subtle invariant)
- No `print()` or `debugPrint()` in committed code
- State must always go through the appropriate Provider; never manage mutable app state directly inside a widget
- DB access only via `db_helper.dart`; never query SQLite from a screen or widget directly
- When changing a model, always update the schema and migrations in `db_helper.dart`

## Key Conventions

- Enums (`GameMode`, `CheckoutMode`) live in `lib/models/game.dart`
- Finish/checkout logic is isolated in `FinishCalculator` — do not inline checkout logic elsewhere
- Theme colors come from `ThemeProvider`; never hardcode colors that should follow the theme
- Localized strings go through `AppLocalizations`; no hardcoded user-visible strings
