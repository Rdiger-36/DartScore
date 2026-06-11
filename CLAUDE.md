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
- `sqflite` + `path` — SQLite local database
- `provider` — state management
- `shared_preferences` — lightweight key/value persistence
- `mobile_scanner` + `qr_flutter` — QR-based sync between devices
- `share_plus` + `gal` + `image_picker` + `path_provider` — export/share functionality
- `in_app_purchase` — donation / supporter in-app purchases
- `package_info_plus` + `url_launcher` — app metadata and external links (about screen)
- `intl` + `flutter_localizations` — i18n (English/German)

## Architecture

The app supports four game modes: **X01** (the original "Game"), **Cricket**, **Shanghai**, and **Around the Clock**. Each non-X01 mode has its own model, provider, and set of setup/play/summary/history screens, mirroring the X01 structure.

```
lib/
├── main.dart                  # App entry point, provider setup, theme/locale init
├── database/
│   └── db_helper.dart         # Singleton SQLite wrapper; all schema definitions and migrations live here
├── models/
│   ├── player.dart                  # Player entity with favorite doubles
│   ├── game.dart                    # X01 game entity; GameMode/CheckoutMode enums, PlayerHandicap, TeamConfig
│   ├── cricket_game.dart            # Cricket entity; CricketVariant/CricketScoringMode enums, cricketFields
│   ├── shanghai_game.dart           # Shanghai entity; ShanghaiVariant enum
│   ├── around_the_clock_game.dart   # Around the Clock entity; AroundTheClockVariant enum, target order
│   └── dart_throw.dart              # Single throw record (value, multiplier, bust flag)
├── providers/
│   ├── players_provider.dart          # Player CRUD; loads from DB, notifies listeners
│   ├── game_provider.dart             # X01 state machine; score calc, bust detection, turn logic
│   ├── cricket_provider.dart          # Cricket state machine; marks, scoring, cut-throat logic
│   ├── shanghai_provider.dart         # Shanghai state machine; round targets, scoring, Shanghai-win
│   ├── around_the_clock_provider.dart # Around the Clock state machine; per-player target progress
│   ├── donation_provider.dart         # In-app purchase / supporter state via in_app_purchase
│   ├── theme_provider.dart            # Light/dark theme toggle, persisted via shared_preferences
│   └── language_provider.dart         # Locale switching (en/de), persisted via shared_preferences
├── screens/
│   ├── home_screen.dart                  # Entry screen with navigation to setup, history, players
│   ├── onboarding_screen.dart            # First-launch walkthrough
│   ├── game_mode_selection_screen.dart   # Pick a game mode (X01/Cricket/Shanghai/Around the Clock)
│   ├── game_mode_info_screen.dart        # Rules/explanation per game mode
│   ├── game_setup_screen.dart            # X01 setup: start score, in/out modes, legs/sets, players, handicaps/teams
│   ├── game_screen.dart                  # X01 live game: scoreboard, numpad, finish suggestions, undo
│   ├── game_summary_screen.dart          # X01 post-game stats: winner, averages, throw history
│   ├── cricket_setup_screen.dart         # Cricket setup: variant, scoring mode, legs/sets, players
│   ├── cricket_screen.dart               # Cricket live game
│   ├── cricket_summary_screen.dart       # Cricket post-game summary
│   ├── cricket_history_summary_screen.dart       # Detailed view of a past Cricket game
│   ├── shanghai_setup_screen.dart        # Shanghai setup
│   ├── shanghai_screen.dart              # Shanghai live game
│   ├── shanghai_summary_screen.dart      # Shanghai post-game summary
│   ├── shanghai_history_summary_screen.dart      # Detailed view of a past Shanghai game
│   ├── around_the_clock_setup_screen.dart        # Around the Clock setup
│   ├── around_the_clock_screen.dart              # Around the Clock live game
│   ├── around_the_clock_summary_screen.dart      # Around the Clock post-game summary
│   ├── around_the_clock_history_summary_screen.dart  # Detailed view of a past Around the Clock game
│   ├── history_screen.dart               # List of all past games (all modes)
│   ├── history_game_summary_screen.dart  # Detailed view of a past X01 game
│   ├── players_screen.dart               # Player management list
│   ├── player_stats_screen.dart          # Per-player lifetime stats
│   ├── settings_screen.dart              # Theme, language, data management
│   ├── about_screen.dart                 # App info, version, license (GPL-3.0), project links
│   ├── donation_screen.dart              # Support the developer via in-app purchases
│   └── sync_screen.dart                  # QR-based device-to-device data sync
├── services/
│   └── sync_service.dart      # Encode/decode game data for QR sync
├── widgets/
│   ├── numpad.dart                    # Numeric input pad for score entry
│   ├── dartboard_input.dart           # Dartboard-style tap input
│   ├── dartboard_icon.dart            # Decorative dartboard SVG widget
│   ├── dartboard_target_painter.dart  # Paints a dartboard with a target segment highlighted
│   ├── cricket_marks_widget.dart      # Renders Cricket marks (slash / X / circle-X) for a field
│   ├── finish_suggestion_widget.dart  # Checkout hint display
│   └── player_dialog.dart             # Create/edit player dialog
├── utils/
│   ├── finish_calculator.dart  # Static checkout table up to 170, respects player's favorite doubles
│   ├── triple_color.dart       # Shared blue tones for triple-field UI across all game modes
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

- All identifiers (functions, methods, classes, variables, enums, etc.) must be named in **English**
- All code comments, doc comments, commit messages, and PR descriptions must be in **English**
- Every function, method, and class must have a proper doc comment (`///`) describing what it does
- Doc comments should be detailed where it matters: go in depth for complex logic, keep it short for self-explanatory members. Do not over-comment - describe purpose, non-obvious behavior, parameters, and return value only when they add value
- Never use em dashes (`—`) in commit messages or PR titles/descriptions; use a hyphen (`-`) or rephrase
- Always create a **new branch** before making changes when the current branch is `main`
- Both platforms (Android and iOS) must be considered for every change; flag platform-specific implications when relevant
- GUI/design changes and larger changes that touch many references must be discussed and approved first before they are applied
- No inline comments unless the WHY is non-obvious (hidden constraint, workaround, subtle invariant)
- No `print()` or `debugPrint()` in committed code
- State must always go through the appropriate Provider; never manage mutable app state directly inside a widget
- DB access only via `db_helper.dart`; never query SQLite from a screen or widget directly
- When changing a model, always update the schema and migrations in `db_helper.dart`

## Key Conventions

- Each game mode keeps its enums in its own model file: `GameMode`/`CheckoutMode` in `game.dart`, `CricketVariant`/`CricketScoringMode` in `cricket_game.dart`, `ShanghaiVariant` in `shanghai_game.dart`, `AroundTheClockVariant` in `around_the_clock_game.dart`
- Each game mode follows the same layering: model + provider (state machine) + setup/play/summary/history screens; mirror this structure when adding a mode
- Finish/checkout logic is isolated in `FinishCalculator` — do not inline checkout logic elsewhere
- Triple-field colors come from `triple_color.dart`; reuse it for triple affordances across all modes
- Theme colors come from `ThemeProvider`; never hardcode colors that should follow the theme
- Localized strings go through `AppLocalizations`; no hardcoded user-visible strings
- Donation / supporter state lives in `DonationProvider`; never call `in_app_purchase` directly from a screen
