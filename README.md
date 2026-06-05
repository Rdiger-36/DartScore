<p align="center">
  <img src="assets/icon/app_icon.png" width="120" alt="DartScore icon" />
</p>

<h1 align="center">DartScore</h1>

<p align="center">
  A feature-rich dart scoring app for Android and iOS.<br/>
  Track games, analyse your performance, and sync profiles between devices — no internet required.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue?style=flat-square" alt="version" />
  <img src="https://img.shields.io/badge/Flutter-%E2%89%A53.32-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-%E2%89%A53.12-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey?style=flat-square" alt="platform" />
  <img src="https://img.shields.io/badge/maintained-yes-brightgreen?style=flat-square" alt="maintained" />
  <img src="https://img.shields.io/badge/status-active-brightgreen?style=flat-square" alt="status" />
</p>

---

## Features

### Game Mode Selection

A dedicated mode selection screen greets you when starting a new game. Each mode has an info page explaining its rules. Currently available:

- **X01** — classic countdown game (201 / 301 / 501 / 701 / 1001)
- **Cricket** — mark-based game on fields 15–20 and Bull

Coming soon (visible in the UI, not yet playable):

- **Shanghai** — score on the target number each round
- **Around the Clock** — hit each number 1–20 in order

---

### X01 Game Modes

- **501 / 301 / 201 / 701 / 1001** and other start scores
- **Solo game** — single-player countdown with no legs/sets; finishes immediately on checkout
- **Multiplayer** (2+ players, turn-based)
- **Team game** — split players into multiple teams sharing one score per team; the current thrower's name is shown inside the team slot
- **Legs & Sets** — configurable number of legs per set and sets per match
- Players can be created directly from the game setup screen; setting a favourite double is required

#### Check-In / Check-Out Rules (X01)

- **Check-In:** Straight In / Double In / Master In per player
- **Check-Out:** Straight Out / Double Out / Master Out per player
- Individual handicap overrides per player within the same game
- Check-In is enforced in leg 1 / set 1 only; subsequent legs always start Straight In

#### Input (X01)

- Segment-level dart input via dartboard widget (Single / Double / Triple + field 1–20, Bull, Miss)
- Each field button shows the notation and resulting score (e.g. `T20 / 60`)
- Live score update after every dart
- Visit-level undo and redo
- Finish suggestion always visible — blue when the checkout is reachable, red when it is not
- Automatic bust detection, including the "remaining = 1" edge case for Double/Master Out

---

### Cricket Game Mode

Cricket is a mark-based game played on fields **15, 16, 17, 18, 19, 20** and **Bull (25)**. Each field needs 3 marks to be "closed". Hitting a single counts as 1 mark, a double as 2, a triple as 3.

#### Variants

| Variant | Scoring rule |
|---|---|
| **Normal** | Once you close a field, extra marks score points for you. Win condition: all fields closed AND highest score. |
| **Cut Throat** | Once you close a field, extra marks score points on every opponent who hasn't closed it yet. Win condition: all fields closed AND lowest score. |

#### Scoring Modes

| Mode | Description |
|---|---|
| **Standard** | Tracks which specific dart (single / double / triple) hit each field — used for accurate marks display. |
| **Simple** | Only counts the number of marks per field; no individual dart breakdown. |

- Minimum 2 players required
- No legs/sets — always a single leg
- Undo support (dart-by-dart)
- History and resume support (like X01)
- Game ends when all players have closed all fields

---

### Statistics (per player)

| Section | What it shows |
|---|---|
| **3-Dart Average** | Hero metric with total darts, visits, and legs |
| **Highlights** | 180s, 140+, 100+, highest visit, highest checkout, perfect legs |
| **Overview** | Games played/won, legs won, total visits & darts |
| **Accuracy** | 3-dart avg, bust count, bust rate, checkout rate |
| **Score Distribution** | Horizontal bar chart bucketed in 20-point ranges |
| **Dartboard Heatmap** | Real dartboard rendered with `CustomPainter`; segments coloured by hit frequency per ring (single / double / triple) with a green → yellow → red scale |
| **Consistency** | Standard deviation of visits displayed as a progress bar with label (Very Consistent -> Very Variable) |
| **Checkout by Range** | Checkout success rate split into brackets: <=40 / 41-60 / 61-100 / 101-170 |
| **Week Comparison** | This week vs last week: average, visits, 180s with delta arrows |
| **Recent Throws** | Last 20 visits with score pill, remaining, leg, darts used, timestamp |

**All stats survive game history deletion.** Every section — heatmap, score distribution, consistency, checkout breakdown, week comparison, recent throws, perfect legs, games won — is folded into a persistent JSON snapshot on the player record before a game is removed. Deleting games (individually or via "Clear all") has no effect on displayed statistics.

---

### Sync (device-to-device, no server needed)

- **Quick QR** — encodes profile + recent throws directly into a QR code; works anywhere, no network required
- **WiFi Sync** — local HTTP server; receiver scans QR code; both devices on the same Wi-Fi (automatically used when data is too large for a QR code)
- Import new players or update existing ones
- Transfers complete stats snapshot and all recorded throws
- Deduplication: already-imported throws are never doubled
- Synced stats snapshot shown when a remote player has no local throw data

---

### Game History

- List of finished and open (resumable) games — both X01 and Cricket
- Per-game summary with all throws per player
- Delete individual games or clear all history (stats are snapshotted before deletion)

---

### Other

- **Onboarding** — name entry on first launch, sets the primary player
- **Manage Players** — add, edit, delete (soft-delete preserves history), set favourite double
- **Dark / Light / System theme**
- **German / English** localisation (auto-detected from device locale)
- **Responsive layout** — content width capped on tablets to phone proportions; portrait orientation locked on phones

---

## Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| Flutter | >= 3.32 |
| Dart SDK | >= 3.12 |
| Xcode (iOS) | >= 15 |
| Android SDK | API 21+ |

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
# iOS Simulator
flutter run -d ios

# Android emulator / device
flutter run -d android
```

---

## App Icon

The icon source file is at `assets/icon/app_icon.png`.  
Generation uses [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons), which is already configured in `pubspec.yaml`.

To regenerate icons after replacing `app_icon.png`:

```bash
dart run flutter_launcher_icons
```

This writes the correctly-sized icons into `android/app/src/main/res/` and `ios/Runner/Assets.xcassets/AppIcon.appiconset/` automatically.

> **iOS note:** `remove_alpha_ios: true` is set in `pubspec.yaml` — the App Store requires icons without an alpha channel.

---

## Project Structure

```
lib/
├── main.dart
├── database/
│   └── db_helper.dart               # SQLite setup, migrations, all queries
├── l10n/
│   └── app_localizations.dart       # DE/EN strings
├── models/
│   ├── cricket_game.dart            # CricketGame, CricketThrow, enums
│   ├── dart_throw.dart              # X01 visit model incl. hits_json for heatmap
│   ├── game.dart                    # X01 Game entity; GameMode/CheckoutMode enums
│   └── player.dart
├── providers/
│   ├── cricket_provider.dart        # Cricket game state machine
│   ├── game_provider.dart           # X01 game state, submit/undo/redo logic
│   ├── language_provider.dart
│   ├── players_provider.dart
│   └── theme_provider.dart
├── screens/
│   ├── cricket_history_summary_screen.dart  # Detailed view of a past Cricket game
│   ├── cricket_screen.dart                  # Live Cricket game: board, input, undo
│   ├── cricket_setup_screen.dart            # Configure variant, scoring mode, players
│   ├── cricket_summary_screen.dart          # Post-Cricket game stats
│   ├── game_mode_info_screen.dart           # Per-mode rules info page
│   ├── game_mode_selection_screen.dart      # Entry point: pick X01, Cricket, etc.
│   ├── game_screen.dart                     # Live X01 game: scoreboard, numpad, finish suggestions
│   ├── game_setup_screen.dart               # Configure start score, in/out modes, legs/sets
│   ├── game_summary_screen.dart             # Post-X01 game stats
│   ├── history_game_summary_screen.dart     # Detailed view of a past X01 game
│   ├── history_screen.dart                  # List of all past games (X01 + Cricket)
│   ├── home_screen.dart
│   ├── onboarding_screen.dart
│   ├── player_stats_screen.dart             # All statistics + dartboard heatmap
│   ├── players_screen.dart
│   ├── settings_screen.dart
│   └── sync_screen.dart
├── services/
│   └── sync_service.dart            # QR / WiFi sync logic
├── utils/
│   ├── finish_calculator.dart       # X01 checkout route calculation
│   └── layout.dart                  # Responsive max-width helper
└── widgets/
    ├── cricket_marks_widget.dart    # Field/marks grid for the Cricket scoreboard
    ├── dartboard_input.dart         # Segment-level dart entry widget
    ├── dartboard_icon.dart
    ├── finish_suggestion_widget.dart
    ├── numpad.dart
    └── player_dialog.dart           # Create/edit player dialog
```

---

## Database Schema

### X01

```sql
players      (id, name, favorite_doubles, is_deleted, is_primary,
              uuid, last_synced_at, synced_stats, local_stats_json)

games        (id, start_score, game_mode, checkout_mode, legs, sets,
              created_at, finished_at, is_synced, team_config_json)

game_players (game_id, player_id, sort_order)

dart_throws  (id, game_id, player_id, score, darts_used, leg, set_,
              remaining_before, thrown_at, bust, hits_json)
```

`hits_json` stores individual dart hits as a compact JSON array:
```json
[{"f": 20, "m": 3}, {"f": 5, "m": 1}, {"f": 1, "m": 2}]
```
`f` = field (1-20, 25 = bull), `m` = multiplier (1 single / 2 double / 3 triple).

### Cricket

```sql
cricket_games   (id, variant, scoring_mode, legs, sets,
                 created_at, finished_at, player_ids)

cricket_throws  (id, game_id, player_id, field, multiplier,
                 leg, set_, thrown_at)
```

`player_ids` is a JSON-encoded array of player IDs (turn order).  
`field`: 15-20 for numbered fields, 25 for Bull, 0 for miss.  
`multiplier`: 1 single / 2 double / 3 triple, 0 for miss.

---

## Dependencies

| Package | Purpose |
|---|---|
| `sqflite` | SQLite database |
| `provider` | State management |
| `intl` | Date formatting, localisation |
| `shared_preferences` | Theme / language persistence |
| `qr_flutter` | QR code generation |
| `mobile_scanner` | QR code scanning |
| `image_picker` | Import QR from photo library |
| `share_plus` | Share QR image |
| `gal` | Save image to photo library |
| `path_provider` | App directories |
| `flutter_launcher_icons` | Icon generation (dev) |
