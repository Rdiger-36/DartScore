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
- `mobile_scanner` + `qr_flutter` — QR-based sync between devices (see the Sync section under Key Conventions)
- `share_plus` + `gal` + `path_provider` — export/share functionality
- No file picking package. The document picker for the backup restore is written by hand on both platforms, see the Backup section under Key Conventions
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
│   ├── live_player_stats_screen.dart     # X01 live player/team info opened from the scoreboard
│   ├── history_screen.dart               # List of all past games (all modes)
│   ├── history_game_summary_screen.dart  # Detailed view of a past X01 game
│   ├── players_screen.dart               # Player management list
│   ├── player_stats_screen.dart          # Per-player lifetime stats
│   ├── settings_screen.dart              # Theme, language, donation and about links
│   ├── about_screen.dart                 # App info, version, license (GPL-3.0), project links
│   ├── licenses_screen.dart              # Licenses of the packages the app is built on
│   ├── donation_screen.dart              # Support the developer via in-app purchases
│   ├── sync_screen.dart                  # Device-to-device data sync (QR and Wi-Fi)
│   └── backup_screen.dart                # Backup and restore of the whole local database
├── services/
│   ├── sync_codec.dart        # Sync wire format: binary packet, base45, fountain coded frames
│   ├── sync_service.dart      # Sync payload types, the Wi-Fi server and its client
│   ├── device_identity.dart   # This device's sync id, the attribution key for all origin tracking
│   ├── backup_service.dart    # Writing the database out as one file and reading one back in
│   └── document_picker.dart   # Dart side of the hand-written system file picker
├── widgets/
│   ├── dartboard_input.dart           # Dartboard-style tap input
│   ├── dartboard_icon.dart            # Decorative dartboard SVG widget
│   ├── dartboard_target_painter.dart  # Paints a dartboard with a target segment highlighted
│   ├── cricket_marks_widget.dart      # Renders Cricket marks (slash / X / circle-X) for a field
│   ├── finish_suggestion_widget.dart  # Checkout hint display
│   ├── favorite_double_picker.dart    # Picks a player's favorite doubles
│   ├── team_section.dart              # Shared team setup block (naming, add/remove, assignment) for every mode
│   ├── starting_order_section.dart    # Shared starting-order block (random vs. fixed + drag-to-sort list)
│   ├── game_info_card.dart            # Shared card listing a finished game's settings
│   ├── summary_player_card.dart       # Shared player/team stat card for the X01 summary and history screens
│   ├── final_ranking_card.dart        # Shared placement-mode ranking card and per-leg table
│   ├── stat_row.dart                  # Shared label/value row used by every stat list
│   ├── throw_log_card.dart            # Shared "All Throws" log for the X01 summary and history screens
│   ├── rematch_button.dart            # "Play Again" button + its confirmation dialog
│   └── player_dialog.dart             # Create/edit player dialog
├── utils/
│   ├── finish_calculator.dart  # Static checkout table up to 170, respects player's favorite doubles
│   ├── game_labels.dart        # Localized names for per-mode settings (variants, check-in/out, handicaps)
│   ├── throw_stats.dart        # ThrowStats: the one aggregation over recorded throws, used live, in the summaries and by the DB snapshot
│   ├── match_format.dart       # Match format presets (best of N, PDC sets, ...)
│   ├── placement.dart          # Placement-mode ranking and points helpers
│   ├── team_color.dart         # Shared team accent palette
│   ├── triple_color.dart       # Shared blue tones for triple-field UI across all game modes
│   └── layout.dart             # Shared layout helpers/constants
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
- Doc comments should be detailed where it matters: go in depth for complex logic, keep it short for self-explanatory members. Do not over-comment - describe purpose, non-obvious behavior, parameters, and return value only when they add value
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

## Key Conventions

- Each game mode keeps its enums in its own model file: `GameMode`/`CheckoutMode` in `game.dart`, `CricketVariant`/`CricketScoringMode` in `cricket_game.dart`, `ShanghaiVariant` in `shanghai_game.dart`, `AroundTheClockVariant` in `around_the_clock_game.dart`
- Settings that every mode shares live in their own model file and are re-exported by each game model, so screens need no extra import: `TeamConfig` in `team_config.dart`, `StartingOrder` in `starting_order.dart`
- `StartingOrder.random` is index 0 on purpose, because that is the DB default and describes how every game before the setting existed was played. Never reorder the enum
- Each game mode follows the same layering: model + provider (state machine) + setup/play/summary/history screens; mirror this structure when adding a mode
- Finish/checkout logic is isolated in `FinishCalculator` — do not inline checkout logic elsewhere
- Statistics derived from X01 visits go through `ThrowStats` in `throw_stats.dart`, the single implementation for the live info screen, the summary and history screens and the snapshot `db_helper.dart` writes before a game is deleted. Never recompute an average, a high, a bust count or a checkout rate inline; a second formula is how the live numbers and the lifetime numbers start disagreeing
- The X01 summary and the X01 history detail render the same result through `SummaryPlayerCard`, `FinalRankingCard` and `ThrowLogCard`; a change to one view belongs in the shared widget, not in one screen
- `GameInfoCard` is deliberately `dense: true` in all four history detail screens and default in all four post-game summaries. It looks like an oversight per mode but is a convention across both sets; change it for all eight or for none
- The live game screens answer the system back with their quit dialog via `PopScope(canPop: false)`. That also suppresses the iOS edge swipe for as long as the game runs, which is the point: Flutter only installs the Cupertino back gesture on a route that may pop, so a confirmation cannot be shown from the gesture itself
- Triple-field colors come from `triple_color.dart`; reuse it for triple affordances across all modes
- Theme colors come from `ThemeProvider`; never hardcode colors that should follow the theme
- Localized strings go through `AppLocalizations`; no hardcoded user-visible strings
- `app_localizations.dart` is hand-written, not generated — there are no `.arb` files and no codegen step. A new string is one getter in `class AppLocalizations` using `_t('<en>', '<de>')`, placed under the matching `// ── Section ──` banner; parameterized strings become methods instead of getters
- Never run `dart format` — the codebase aligns constructor arguments and the `=>` of the localization getters in columns by hand, and the formatter collapses all of it
- Donation / supporter state lives in `DonationProvider`; never call `in_app_purchase` directly from a screen

### Backup

- A backup is the SQLite file itself, not a dump of it. That keeps a restore exact and costs no second serialiser to keep in step with the schema. The price is that a file from a newer schema version cannot be read, which is why `inspectBackup` reports the version and the service refuses anything above `DbHelper.schemaVersion`
- `prepareBackup` checkpoints the write-ahead log before the file is copied. Without it a copy of `dartscore.db` alone misses whatever still sits in the `-wal` companion, and nothing about the resulting backup looks wrong until someone needs it. For the same reason a restore deletes `-wal` and `-shm`: they belong to the replaced database
- A backup carries the device id from `DeviceIdentity` in its `app_meta` table, and a restore adopts it. Every game is filed under the device that played it, so coming back up under a fresh id would leave the whole restored history attributed to a device that no longer answers. The other side of that is that two live devices must never end up on one id, which is what the warning in the restore dialog is for
- Backup is not sync and must not be built on `sync_codec.dart`. A sync merges two devices and folds what it cannot carry into snapshots; a restore replaces this device wholesale, identity included
- Where the file goes is the platform's business. `share_plus` on the way out, the document picker on the way back in, so iCloud Drive, Google Drive, Files and mail are all covered without the app hosting anything or knowing which one was used
- The document picker is written by hand in `DocumentPickerHandler.swift` and `MainActivity.kt` because every file picking package still requires CocoaPods on iOS, which this project deliberately does not use. Adding one back would undo that. A new Swift file also has to be added to the `DartScore` target in `project.pbxproj`; it is not picked up on its own
- The picked file is always a copy in a cache directory, on both platforms. It is meant to be used at once and thrown away, not kept

### Sync

- A sync carries a player's whole history whatever range the user picks. Only the individual throws are cut off; everything left out is folded into the stats snapshot that travels along, and what the throws that do travel cannot carry is folded in too. Break either fold and the receiving device's lifetime numbers read low, which is invisible in the app
- A synced throw arrives without its game: every throw of an import lands in one hidden sync-game that has no start score and counts for no game played. So everything a game knows about itself has to travel folded into the snapshot, through `addTravellingGameFacts`: the perfect legs, the best game average, the games played and finished, and the dartboard segments. None of it can be recomputed on the other side, and none of it can double count there, because the sync-game contributes nothing to any of it
- The range cuts this device's own history along whole games, not at the throw. Half a game has no perfect leg and no average worth the name, and a game cut down the middle would be claimed twice, once folded and once travelling. Throws that came from elsewhere are cut at the throw instead: their games are already aggregates, so there is nothing left to keep whole
- Every device has an id from `DeviceIdentity`, and every piece of a player's history is filed under the device it was played on: `games.origin_device` for throws, `player_origin_stats` for aggregates, with `players.local_stats_json` holding this device's own and nothing else. That split is what makes syncing in both directions safe, and every rule below rests on it
- A throw is only ever folded into the snapshot of the device it was played on, and a device passing on what it received keeps the original attribution. Fold foreign throws into the sending device's own total and they come home to whoever played them as somebody else's numbers, on top of the throws still sitting there, which is a silent overcount
- The receiver drops anything a packet attributes to its own id, throws and snapshot alike. Nothing else prevents a full round trip from counting the same leg twice
- An incoming packet is authoritative for what the sending device holds, and for that device only: its throws (`games.origin_device`) and its snapshot are deleted before importing, otherwise a snapshot covering throws an earlier sync already delivered counts them again. What a third device sent is left alone, and a snapshot only passed on by the sender is kept when the local copy covers more darts
- The legacy bucket (`origin_device = ''`) is data from before devices were told apart. It travels as throws whatever the range asks for, because there is no snapshot it could safely be folded into, and an import replaces it wholesale. One sync per device pair clears it for good
- `thrownAt` in milliseconds is the deduplication key on import. Do not round it
- The origin fields ride in a trailer after the throws rather than in a new format version, so an app that predates them reads the packet up to the last throw and imports it instead of refusing a version number it does not know. `local_stats_json` in a packet is every origin added together, kept for exactly those readers
- All three transports build on the same bytes from `sync_codec.dart`. What differs is only the framing: base45 for one code, fountain coded frames for an animated one, HTTP for the Wi-Fi transfer
- QR payloads are base45 so a code can use its alphanumeric mode, which holds about a third more than the byte mode. Every character a code carries, headers included, has to stay inside that set, and the codes are built through `buildQrCode` in `sync_screen.dart` because `QrCode.fromData` always picks the byte mode
- Animated frames are LT coded: the receiver needs any set of frames slightly larger than the block count, not particular ones. Seeds are scrambled before use and each transfer starts at a random point in the seed space; both are load bearing, without them the overhead goes from about 1.25 to 4 times the block count
- The Wi-Fi server hands its payload to one peer, once, after the user confirms a pairing number, and then stops. A request without the session token is refused without disturbing the user. The state may only reach `served` after the response has finished writing, or the screen shuts the socket down mid-body
