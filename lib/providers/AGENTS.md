# Providers

The state machines. Owns the rules of each game mode, the in-flight game state, and the only calls into `db_helper.dart`. Owns no layout and no wire format.

## Entry Points

- `game_provider.dart`, X01: score calculation, bust detection, turn logic
- `cricket_provider.dart`, Cricket: marks, scoring, cut-throat logic
- `shanghai_provider.dart`, Shanghai: round targets, scoring, the Shanghai win
- `around_the_clock_provider.dart`, Around the Clock: per-player target progress
- `players_provider.dart`, player CRUD, loads from the DB and notifies listeners
- `donation_provider.dart`, in-app purchase / supporter state via `in_app_purchase`
- `theme_provider.dart` and `language_provider.dart`, light/dark and en/de, both persisted via `shared_preferences`
- `tablet_layout_provider.dart`, which side the input sits on and where each divider stands, persisted via `shared_preferences`
- `text_scale_provider.dart`, the text size the reader picked, persisted via `shared_preferences`

## Contracts and Invariants

- A provider is the only place mutable app state lives. A widget that keeps game state of its own is a bug, not a shortcut
- Persistence goes through `db_helper.dart` and nowhere else. `notifyListeners()` after the write, not before
- Changing a model means changing the schema and the migrations in `db_helper.dart` in the same step
- Statistics come from `ThrowStats` in `utils/throw_stats.dart`. A provider does not carry a second formula for an average, a high, a bust count or a checkout rate
- `DonationProvider` owns everything `in_app_purchase` touches. No screen talks to the plugin
- `TextScaleProvider` holds a factor, not a font size, and the app applies it in one place: the `MaterialApp` builder in `main.dart`, and only on a tablet sized window. A screen that scales its own text again is a screen the setting no longer describes
- `TabletLayoutProvider` keys a divider by the screen **and** the orientation it belongs to. A scoreboard next to an input divides differently than a list next to a page of statistics, and a share that reads well across a landscape tablet leaves an upright one with two columns too narrow. The values are loaded on a phone too, they are simply never read there

## Patterns

A new game mode gets its own provider next to these, with the same shape: load the game, accept a throw, decide the turn, decide the leg and set, write the result. Mirror the existing four rather than inventing a new lifecycle.

## Anti-patterns

- No `print()` or `debugPrint()`, here or anywhere else in committed code
- Do not reach into another mode's provider to reuse a rule. Shared rules belong in `utils/`
- Do not reorder `StartingOrder`: `random` is index 0 because that is the DB default

## Related Context

- Screens that read these: `../screens/AGENTS.md`
- Sync and backup, which write player and game rows outside the normal game flow: `../services/AGENTS.md`
