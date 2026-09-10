# Providers

The state machines. Owns the rules of each game mode, the in-flight game state, and the only calls into `db_helper.dart`. Owns no layout and no wire format.

## Entry Points

- `game_provider.dart`, X01: score calculation, bust detection, turn logic, and the bot runner: when the slot on turn is a bot, a timer per dart aims through `x01Target`, lands through `BotThrower` and goes down the same `_addDart` path a tap does
- `cricket_provider.dart`, Cricket: marks, scoring, cut-throat logic
- `shanghai_provider.dart`, Shanghai: round targets, scoring, the Shanghai win
- `around_the_clock_provider.dart`, Around the Clock: per-player target progress
- `players_provider.dart`, player CRUD, loads from the DB and notifies listeners. Keeps the computer opponents apart in `bots` and creates a tier's row on first use through `botFor`
- `donation_provider.dart`, in-app purchase / supporter state via `in_app_purchase`
- `theme_provider.dart` and `language_provider.dart`, light/dark and en/de, both persisted via `shared_preferences`
- `tablet_layout_provider.dart`, which side the input sits on and where each divider stands, persisted via `shared_preferences`
- `text_scale_provider.dart`, the text size the reader picked, persisted via `shared_preferences`

## Contracts and Invariants

- A provider is the only place mutable app state lives. A widget that keeps game state of its own is a bug, not a shortcut
- Persistence goes through `db_helper.dart` and nowhere else. `notifyListeners()` after the write, not before
- Changing a model means changing the schema and the migrations in `db_helper.dart` in the same step
- Statistics come from `ThrowStats` in `utils/throw_stats.dart`. A provider does not carry a second formula for an average, a high, a bust count or a checkout rate
- `GameProvider` is the one place that decides `DartThrow.checkoutDarts`, in `_submitVisit`, via `checkoutDartsInVisit`. It is stored rather than derived because nothing downstream can work it out again: counting the darts that flew while a single dart could have finished needs the individual darts and the player's own check-out rule, and a throw that arrives over sync carries neither. Two statistics rest on it, the check-out rate over visits and the double rate over darts, so a second formula anywhere would make them disagree
- Undo, redo and resume all rebuild the board from the stored throws, and everything about the turn is read off those throws, never counted from how many visits a leg happens to hold. Whose turn it is comes from who threw last, the member of a team from the member who threw its last visit (in Cricket, from the member who threw its last dart, since a visit there is counted in darts), and the leg and set from `openLegAndSet`, which moves past a leg its last visit already decided. Visit counts only describe a game whose every leg opened with the first slot and the first member, and no leg after the first one does: the slot after the winner opens it, and a team's rotation runs on across legs and sets
- `DonationProvider` owns everything `in_app_purchase` touches. No screen talks to the plugin
- The bot runner schedules after every change of turn (`_scheduleBot`) and is held back (`_botSuspended`) while undo and redo rebuild the board, so no bot dart lands on a half restored visit. `resumeGame` is the public rebuild that releases the bot; undo and redo use `_rebuildFromDb` and release it themselves at the end. `stopBot` is what the live screen calls on quit, and the provider watches the app lifecycle itself so a bot pauses in the background on both platforms
- `isBotTurn` locks the input, undo and redo. Bot visits are never undone on their own: `undoLastDart` skips back over every trailing bot visit to the last human dart, and `canUndoDart` is false when only bots have thrown. Tests drive the bot with `botDartDelay = Duration.zero` and a seeded `BotThrower`, and wait on `isBotTurn || botThrowing`, never on a guessed duration
- `TextScaleProvider` holds a factor, not a font size, and the app applies it in one place: the `MaterialApp` builder in `main.dart`, and only on a tablet sized window. A screen that scales its own text again is a screen the setting no longer describes
- `TabletLayoutProvider` keys a divider by the screen **and** the orientation it belongs to. A scoreboard next to an input divides differently than a list next to a page of statistics, and a share that reads well across a landscape tablet leaves an upright one with two columns too narrow. The values are loaded on a phone too, they are simply never read there

## Patterns

A new game mode gets its own provider next to these, with the same shape: load the game, accept a throw, decide the turn, decide the leg and set, write the result. Mirror the existing four rather than inventing a new lifecycle.

## Anti-patterns

- No `print()` or `debugPrint()`, here or anywhere else in committed code
- Do not reach into another mode's provider to reuse a rule. Shared rules belong in `utils/`
- Do not reorder `StartingOrder`: `random` is index 0 because that is the DB default
- Do not reorder `BotLevel` either, and do not insert a bot row by hand: `PlayersProvider.botFor` is the one place that makes one, so a tier stays a single row that every game against it shares

## Related Context

- Screens that read these: `../screens/AGENTS.md`
- Sync and backup, which write player and game rows outside the normal game flow: `../services/AGENTS.md`
