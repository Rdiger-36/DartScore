# Screens

The UI layer. Owns navigation, layout and the dialogs the user answers. Owns no game rules, no statistics formula and no persistence: those live in the providers, in `utils/` and in `db_helper.dart`.

## Entry Points

- `home_screen.dart`, the entry screen with navigation to setup, history and players
- `game_mode_selection_screen.dart` and `game_mode_info_screen.dart`, picking a mode and reading its rules

The mode selection lists the modes under a heading per `GameModeCategory`, match, party and training, and which category a mode belongs to is `gameModeCategory` in `game_mode_info_screen.dart`, next to `gameModeTexts`, which holds the name, tagline and rules of a mode for the card and for the rules alike. A new mode is one case in each and one in `_openSetup`; the list builds itself from `GameModeOption.values`. On a phone and on an upright tablet a tap on a card opens the setup and the info button the rules screen. The list is centred where it fits and starts at the top where it does not, and then the heading of the category being read stays pinned. A tablet in landscape puts `GameModeInfoPane`, the body of the rules screen, beside the list instead: a tap selects, the cards carry no info button, and the button on the bar under both panes opens the setup. An unfolded phone on its side is over the breakpoint and gets the same two panes.
- `onboarding_screen.dart`, the first-launch walkthrough

### One set per game mode

Every mode has the same four screens, and a fifth for the history detail:

| Mode | Setup | Live game | Summary | History detail |
|------|-------|-----------|---------|----------------|
| X01 | `game_setup_screen.dart` | `game_screen.dart` | `game_summary_screen.dart` | `history_game_summary_screen.dart` |
| Cricket | `cricket_setup_screen.dart` | `cricket_screen.dart` | `cricket_summary_screen.dart` | `cricket_history_summary_screen.dart` |
| Shanghai | `shanghai_setup_screen.dart` | `shanghai_screen.dart` | `shanghai_summary_screen.dart` | `shanghai_history_summary_screen.dart` |
| Around the Clock | `around_the_clock_setup_screen.dart` | `around_the_clock_screen.dart` | `around_the_clock_summary_screen.dart` | `around_the_clock_history_summary_screen.dart` |
| Checkout Ladder | `checkout_ladder_setup_screen.dart` | `checkout_ladder_screen.dart` | `checkout_ladder_summary_screen.dart` | `checkout_ladder_history_summary_screen.dart` |
| Capital | `capital_setup_screen.dart` | `capital_screen.dart` | `capital_summary_screen.dart` | `capital_history_summary_screen.dart` |

The Checkout Ladder is scored like X01, so its live screen is the X01 input (`DartboardInput<CheckoutLadderProvider>`) under one card per ladder, and on a tablet in landscape the input beside the ladders. In portrait a tablet stacks them instead, the ladders two to a row above an input as wide as the screen: nothing else shares the input's pane the way the statistics do in X01, so a split would leave the ladders a mostly empty column and the input half the width. It, Capital and the mode selection are the screens that do not split on every tablet, and the swap button only shows where the two games do. A training is left two ways: to be resumed from the history, or ended, which stores it as finished and shows the summary. A race can only be left, to be resumed from the history; it ends when it is decided.

Capital enters its darts through the X01 input, `DartboardInput<CapitalProvider>`, because a dart there can land on any field in any ring, exactly as in X01. It looks and behaves like every other mode on purpose: an earlier keypad painted in the board's colors was dropped for that reason, and because a soft tip board is not painted like a steel one. Which board the game is played on is the one setting its setup offers besides players and order, a `ChoiceChip` per `BoardType`, steel by default, and the game stores it. Above the input a band names the round and what its contract asks, and once darts have landed it says what the visit still needs instead of repeating the rule. The band is where the board shows: in the Colors round it puts a dot in the board's paint before the line for every dart thrown, and the line names the colors of that board, or on a soft tip board, which paints only blue and red, the four areas as single or ring of a color. The scoreboard shows one slot's arithmetic at a time, by default whoever threw last: eight players leave no room for eight sums, which is also why its rows are as short as they are, and on a phone it scrolls inside a share of the screen as the Ladder's does. A tap on a name opens the live numbers, a tap on a score pins that slot's arithmetic in place of the default, and nothing on the screen is on a long press. On a landscape tablet the input takes a pane of its own and the side follows `TabletLayoutProvider` with the swap button, as in the Ladder; upright it stacks. Its setup offers no legs, no sets and no teams: a Capital game is one pass through the fifteen rounds, played by individuals, and one player is enough. Its summary and its history detail are the same `CapitalResultCard`, whose rows unfold into the rounds behind them.

X01 has a screen of its own for the player/team info opened from the scoreboard during a game, `live_player_stats_screen.dart`. The other modes share `mode_live_info_screen.dart`: a tap on a slot's name opens it with the last three visits as dart chips and the numbers that mode is played by, and each live screen builds that data in its own `open<Mode>SlotInfo` from the stats in `utils/`. It rebuilds from the provider, so a bot's visit shows while it is open.

Capital does not share it. A tap on the name there opens `capital_live_info_screen.dart`, which lists every round the slot has played with the arithmetic behind each, through the same `CapitalRoundList` the result table unfolds, and then the same numbers. Three visits as chips suit a mode where a visit stands on its own; a Capital round only means anything against the capital it was thrown at, so its live info is the game's own history as far as the game has got. The tap is on the name alone, because the other half of the row, the score, pins that slot's arithmetic to the board.

### The rest

- `history_screen.dart`, the list of all past games across all modes
- `players_screen.dart` and `player_stats_screen.dart`, player management and lifetime stats
- `settings_screen.dart`, `about_screen.dart`, `licenses_screen.dart`, `donation_screen.dart`
- `sync_screen.dart` and `backup_screen.dart`, the two transfer screens. Their rules live in `../services/AGENTS.md`, not here

## Contracts and Invariants

- Read state with `context.watch<XProvider>()`, act with `context.read<XProvider>().method()`. A screen never holds mutable game state of its own
- No screen queries SQLite. Everything goes through the provider, which goes through `db_helper.dart`
- The X01 summary and the X01 history detail render the same result through `SummaryPlayerCard`, `FinalRankingCard` and `ThrowLogCard`. A change to one view belongs in the shared widget, not in one screen
- `GameInfoCard` is deliberately `dense: true` in all six history detail screens and default in all six post-game summaries. It looks like an oversight per mode but is a convention across both sets; change it for all twelve or for none
- A screen wide enough for two panes builds them with `SidePaneLayout` from `../utils/layout.dart`, gated on `isTabletLayout(context)`, and keeps the stacked single column for everything below it. Both branches render the same widgets; a layout that only one of the two reaches is how the phone and the tablet start drifting apart
- No screen scales its own text. The app applies the reader's text size once, in the `MaterialApp` builder in `main.dart`, so a wrapper on a single screen would only multiply it a second time there. The exception is a subtree that has to ignore the setting, like the exported summary card, which pins `TextScaler.noScaling` so the image is the same picture wherever it was made
- Only the live game, the history, the player list and the mode selection let their divider be dragged, and those four read it from `TabletLayoutProvider`, one `SplitPane` each. The rest divide in the middle and stay there: they put two things of the same kind beside each other, so there is nothing to rebalance
- The live game screens answer the system back with their quit dialog via `PopScope(canPop: false)`. That also suppresses the iOS edge swipe for as long as the game runs, which is the point: Flutter only installs the Cupertino back gesture on a route that may pop, so a confirmation cannot be shown from the gesture itself
- `licenses_screen.dart` shows what the `LicenseRegistry` holds, which is Flutter's `NOTICES` plus the native Android notices `utils/platform_notices.dart` registers at startup. It hides a package name only through `kDevelopmentOnlyPackages`, and hiding a name never hides a license: an entry shared with a shipped package still shows under that one. Over-listing a package is noise, leaving one out is a missing attribution
- Every user-visible string comes from `AppLocalizations`, every themed color from `ThemeProvider`
- A roster is `PlayersProvider.players`, which holds people only. The player list, the sync sender and the setup screens read it and so never show a computer opponent; a bot joins a game through `BotSelectSection`, whose `onAdd` asks `PlayersProvider.botFor` for the row with the lowest ordinal not yet in the selection and adds it like a person, and whose `onRemove` drops that one row
- A name on screen is `player.label(l)` or `slot.label(l)` from `utils/player_label.dart`, never `.name`: a bot is shown under its localized tier name. The start button of a setup needs a person in the selection, `any((p) => !p.isBot)`, not merely a non-empty one
- Every live screen calls `leaveGame()` on its provider before it pops on quit: that stops the bot and, in X01, records a visit still waiting out its pause. A screen that leaves a running game any other way has to do the same, or the bot keeps throwing into a game nobody is watching and the last visit is lost
- The input of every mode reads `inputLocked` and goes dim and deaf while it holds; the provider refuses the dart either way, the widget only says so. While `visitPending` holds, the throw buttons make way for a Continue button that calls `flushHeldVisit`, three buttons wide and centred, in X01 through its own `_ActionButton` with the `VisitPauseBar` under the visit row, elsewhere through `ContinueButton`, which carries the bar above itself
- The live info's recent visits card renders `ThrowRow`, the same row the throw log and the lifetime statistics use. A visit reads the same everywhere it is listed

## Patterns

Adding a screen to an existing mode: mirror the same screen in the other modes before inventing a layout. The six sets are meant to read alike.

Adding a whole mode: model, provider, then setup, live, summary and history detail here, reusing `TeamSection`, `StartingOrderSection` and `GameInfoCard` rather than rebuilding the setup blocks.

## Anti-patterns

- Do not compute an average, a high score, a bust count or a checkout rate in a screen. `ThrowStats` is the only implementation
- Do not inline checkout logic. `FinishCalculator` owns it
- Do not fix a summary layout in one mode's screen when the shared widget is what renders it
- Do not call `in_app_purchase` from `donation_screen.dart`; `DonationProvider` owns that state

## Related Context

- Providers: `../providers/AGENTS.md`
- Shared widgets these screens are built from: `../widgets/AGENTS.md`
- Sync and backup screens: `../services/AGENTS.md`
