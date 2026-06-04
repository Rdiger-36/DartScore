# 🎯 DartScore

A feature-rich Flutter dart scoring app for Android and iOS. Track games, analyse your performance with detailed statistics, and sync profiles between devices — no internet required.

---

## Features

### Game Modes
- **501 / 301 / 201 / 701 / 1001** and other start scores
- **Solo game** — single-player countdown with no legs/sets; finishes immediately on checkout
- **Multiplayer** (2+ players, turn-based)
- **Team game** — split players into teams sharing one score
- **Legs & Sets** — configurable number of legs per set and sets per match

### Check-In / Check-Out Rules
- Straight In / Double In per player (handicap support)
- Straight Out / Double Out / Master Out per player
- Individual handicap overrides per player within the same game

### Input
- Segment-level dart input (Single / Double / Triple + field 1–20, Bull, Miss)
- Live score update after every dart
- Visit-level undo and redo
- Finish suggestions (optimal checkout routes) updated after each dart
- Automatic bust detection, including the "remaining = 1" edge case for Double/Master Out

### Statistics (per player)
| Section | What it shows |
|---|---|
| **3-Dart Average** | Hero metric with total darts, visits, and legs |
| **Highlights** | 180s, 140+, 100+, highest visit, highest checkout, perfect legs |
| **Overview** | Games played/won, legs won, total visits & darts |
| **Accuracy** | 3-dart avg, bust count, bust rate, checkout rate |
| **Score Distribution** | Horizontal bar chart bucketed in 20-point ranges |
| **Dartboard Heatmap** | Real dartboard rendered with `CustomPainter`; segments coloured by hit frequency per ring (single / double / triple) with a green → yellow → red scale |
| **Consistency** | Standard deviation of visits displayed as a progress bar with label (Very Consistent → Very Variable) |
| **Checkout by Range** | Checkout success rate split into brackets: ≤40 / 41–60 / 61–100 / 101–170 |
| **Week Comparison** | This week vs last week: average, visits, 180s with delta arrows |
| **Recent Throws** | Last 20 visits with score pill, remaining, leg, darts used, timestamp |

**All stats survive game history deletion.** Every section — heatmap, score distribution, Konstanz, checkout breakdown, week comparison, recent throws, perfect legs, games won — is folded into a persistent JSON snapshot on the player record before a game is removed. Deleting games (individually or via "Clear all") has no effect on displayed statistics.

### Sync (device-to-device, no server needed)
- **Quick QR** — encodes profile + recent throws directly into a QR code; works anywhere, no network required
- **WiFi Sync** — local HTTP server; receiver scans QR code; both devices on the same Wi-Fi
- Import new players or update existing ones
- Deduplication: already-imported throws are never doubled
- Synced stats snapshot shown when a remote player has no local throw data

### Game History
- List of finished and open (resumable) games
- Per-game summary with all throws per player
- Delete individual games or clear all history (stats are snapshotted before deletion)

### Other
- **Onboarding** — name entry on first launch, sets the primary player
- **Manage Players** — add, edit, delete (soft-delete preserves history), set favourite double
- **Dark / Light / System theme**
- **German / English** localisation (auto-detected from device locale)

---

## Getting Started

### Prerequisites

| Tool | Version |
|---|---|
| Flutter | ≥ 3.32 |
| Dart SDK | ≥ 3.12 |
| Xcode (iOS) | ≥ 15 |
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
├── database/
│   └── db_helper.dart          # SQLite setup, migrations, all queries
├── l10n/
│   └── app_localizations.dart  # DE/EN strings
├── models/
│   ├── dart_throw.dart         # Visit model incl. hits_json for heatmap
│   ├── game.dart
│   └── player.dart
├── providers/
│   ├── game_provider.dart      # Game state, submit/undo/redo logic
│   ├── language_provider.dart
│   ├── players_provider.dart
│   └── theme_provider.dart
├── screens/
│   ├── game_screen.dart
│   ├── game_setup_screen.dart
│   ├── game_summary_screen.dart
│   ├── history_game_summary_screen.dart
│   ├── history_screen.dart
│   ├── home_screen.dart
│   ├── onboarding_screen.dart
│   ├── player_stats_screen.dart  # All statistics + dartboard heatmap
│   ├── players_screen.dart
│   ├── settings_screen.dart
│   └── sync_screen.dart
├── services/
│   └── sync_service.dart       # QR / WiFi sync logic
├── utils/
│   └── finish_calculator.dart  # Checkout route calculation
└── widgets/
    ├── dartboard_input.dart    # Segment-level dart entry widget
    ├── dartboard_icon.dart
    ├── finish_suggestion_widget.dart
    └── numpad.dart
```

---

## Database Schema

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
`f` = field (1–20, 25 = bull), `m` = multiplier (1 single / 2 double / 3 triple).

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
