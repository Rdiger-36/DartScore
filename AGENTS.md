# DartScore App

Flutter-based dart scoring tracker for Android and iOS.

## Intent Layer

**Before changing code in one of these directories, read its `AGENTS.md` first.** It holds the local patterns and invariants that this file only summarises.

- **Screens**: `lib/screens/AGENTS.md`, the UI layer, one setup/play/summary/history set per game mode
- **Providers**: `lib/providers/AGENTS.md`, the state machines and the only path to the database
- **Services**: `lib/services/AGENTS.md`, sync and backup, the two subsystems with the most rules per line
- **Widgets**: `lib/widgets/AGENTS.md`, the shared building blocks the screens are assembled from

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

# Shoot the raw store screenshots on all four simulators/emulators
tool/store_screenshots.sh

# Frame them into the pictures the two listings show (needs librsvg)
dart run tool/compose_store_screenshots.dart
```

## Tech Stack

- Flutter + Dart (SDK ^3.12.0)
- `sqflite` + `path` — SQLite local database
- `provider` — state management
- `shared_preferences` — lightweight key/value persistence
- `mobile_scanner` + `qr_flutter` — QR-based sync between devices (see `lib/services/AGENTS.md`)
- `share_plus` + `gal` + `path_provider` — export/share functionality
- No file picking package. The document picker for the backup restore is written by hand on both platforms (see `lib/services/AGENTS.md`)
- `in_app_purchase` — donation / supporter in-app purchases
- `package_info_plus` + `url_launcher` — app metadata and external links (about screen)
- `intl` + `flutter_localizations` — i18n (English/German); strings are maintained by hand, see Key Conventions

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
│   ├── team_config.dart             # Shared TeamConfig + JSON encode/decode for the team_config_json columns
│   ├── starting_order.dart          # Shared StartingOrder enum for the starting_order columns (random/fixed)
│   └── dart_throw.dart              # Single throw record (value, multiplier, bust flag)
├── providers/                 # State machines, one per game mode plus the app-wide ones. See providers/AGENTS.md
├── screens/                   # Setup, live game, summary and history per mode, plus the app screens. See screens/AGENTS.md
├── services/                  # Sync codec, sync transport, device identity, backup, document picker. See services/AGENTS.md
├── widgets/                   # Shared UI building blocks. See widgets/AGENTS.md
├── utils/
│   ├── finish_calculator.dart  # Static checkout table up to 170, respects player's favorite doubles; canFinishWithOneDart is the one-dart rule per check-out mode
│   ├── game_labels.dart        # Localized names for per-mode settings (variants, check-in/out, handicaps)
│   ├── throw_stats.dart        # ThrowStats: the one aggregation over recorded throws, used live, in the summaries and by the DB snapshot; checkoutDartsInVisit classifies a visit as it is recorded
│   ├── match_format.dart       # Match format presets (best of N, PDC sets, ...)
│   ├── placement.dart          # Placement-mode ranking and points helpers
│   ├── team_color.dart         # Shared team accent palette
│   ├── segment_color.dart      # Shared tones for multiplied fields: blue for triples, green for doubles
│   ├── platform_notices.dart   # Licenses of the Android libraries the plugins pull in through Gradle, registered into the LicenseRegistry at startup
│   └── layout.dart             # Tablet breakpoint, max widths, SidePaneLayout, input side, text scale
└── l10n/
    └── app_localizations.dart  # Hand-written localization strings (no .arb, no codegen)
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
- Doc comments should be detailed where it matters: go in depth for complex logic, keep it short for self-explanatory members. Do not over-comment, describe purpose, non-obvious behavior, parameters, and return value only when they add value
- Never use a dash as punctuation anywhere: not the em dash (`—`) and not a standalone hyphen (` - `). This covers UI strings, doc comments, inline comments, commit messages and PR titles/descriptions. Rephrase, or use a comma, colon or full stop. Hyphens inside compound words (`cut-throat`, `Co-Authored-By`) are fine
- Always create a **new branch** before making changes when the current branch is `main`
- Name the branch after everything it ends up holding, not just its first commit. Rename it when the scope grows
- Never open a pull request on your own. Commit, push, report the branch, and wait: a PR may only be created once the user has given an explicit go-ahead for that specific PR. A general permission is not a standing one, ask again for the next
- Both platforms (Android and iOS) must be considered for every change; flag platform-specific implications when relevant
- GUI/design changes and larger changes that touch many references must be discussed and approved first before they are applied
- No inline comments unless the WHY is non-obvious (hidden constraint, workaround, subtle invariant)
- No `print()` or `debugPrint()` in committed code
- State must always go through the appropriate Provider; never manage mutable app state directly inside a widget
- DB access only via `db_helper.dart`; never query SQLite from a screen or widget directly
- When changing a model, always update the schema and migrations in `db_helper.dart`

## Global Invariants

These hold in every directory, whatever the local node says.

- State goes through a Provider, database access goes through `db_helper.dart`, and no screen or widget touches SQLite
- Statistics derived from X01 visits go through `ThrowStats` in `throw_stats.dart`, the single implementation for the live info screen, the summary and history screens and the snapshot `db_helper.dart` writes before a game is deleted. Never recompute an average, a high, a bust count or a checkout rate inline; a second formula is how the live numbers and the lifetime numbers start disagreeing
- Finish/checkout logic is isolated in `FinishCalculator`, do not inline checkout logic elsewhere
- Whether a visit was an attempt at the finish, and how many of its darts flew at one, is decided once when the visit is recorded and stored as `dart_throws.checkout_darts`. Deciding it needs the individual darts and the player's own check-out rule, neither of which reaches every place the statistics are counted. Never re-derive it from `remaining_before`
- A rebuild of a board (undo, redo, resume) reads the turn and the position off the stored throws, which carry the player, the leg and the set of every visit. Never count them from the number of visits a leg holds: that count only describes a leg that opened with the first slot and the first team member, and the leg after a checkout opens with the slot behind the winner. See `providers/AGENTS.md`
- Localized strings go through `AppLocalizations`; no hardcoded user-visible strings
- Theme colors come from `ThemeProvider`; never hardcode colors that should follow the theme
- Colors that stand for a multiplied field come from `segment_color.dart`, blue for a triple and green for a double; reuse them for those affordances across all modes
- Two panes side by side come from `SidePaneLayout` in `layout.dart`, and whether a window gets them is `isTabletLayout(context)`, never a width read by hand. The same rule drives the orientation lock in `main.dart`, so a window that may rotate is exactly a window that divides
- Never run `dart format`. The codebase aligns constructor arguments and the `=>` of the localization getters in columns by hand, and the formatter collapses all of it

## Key Conventions

### Models and schema

- Each game mode keeps its enums in its own model file: `GameMode`/`CheckoutMode` in `game.dart`, `CricketVariant`/`CricketScoringMode` in `cricket_game.dart`, `ShanghaiVariant` in `shanghai_game.dart`, `AroundTheClockVariant` in `around_the_clock_game.dart`
- Settings that every mode shares live in their own model file and are re-exported by each game model, so screens need no extra import: `TeamConfig` in `team_config.dart`, `StartingOrder` in `starting_order.dart`
- `StartingOrder.random` is index 0 on purpose, because that is the DB default and describes how every game before the setting existed was played. Never reorder the enum
- Each game mode follows the same layering: model + provider (state machine) + setup/play/summary/history screens; mirror this structure when adding a mode

### Localization

- `app_localizations.dart` is hand-written, not generated. There are no `.arb` files and no codegen step. A new string is one getter in `class AppLocalizations` using `_t('<en>', '<de>')`, placed under the matching `// ── Section ──` banner; parameterized strings become methods instead of getters
