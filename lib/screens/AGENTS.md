# Screens

The UI layer. Owns navigation, layout and the dialogs the user answers. Owns no game rules, no statistics formula and no persistence: those live in the providers, in `utils/` and in `db_helper.dart`.

## Entry Points

- `home_screen.dart`, the entry screen with navigation to setup, history and players
- `game_mode_selection_screen.dart` and `game_mode_info_screen.dart`, picking a mode and reading its rules
- `onboarding_screen.dart`, the first-launch walkthrough

### One set per game mode

Every mode has the same four screens, and a fifth for the history detail:

| Mode | Setup | Live game | Summary | History detail |
|------|-------|-----------|---------|----------------|
| X01 | `game_setup_screen.dart` | `game_screen.dart` | `game_summary_screen.dart` | `history_game_summary_screen.dart` |
| Cricket | `cricket_setup_screen.dart` | `cricket_screen.dart` | `cricket_summary_screen.dart` | `cricket_history_summary_screen.dart` |
| Shanghai | `shanghai_setup_screen.dart` | `shanghai_screen.dart` | `shanghai_summary_screen.dart` | `shanghai_history_summary_screen.dart` |
| Around the Clock | `around_the_clock_setup_screen.dart` | `around_the_clock_screen.dart` | `around_the_clock_summary_screen.dart` | `around_the_clock_history_summary_screen.dart` |

X01 has one screen the others do not: `live_player_stats_screen.dart`, the player/team info opened from the scoreboard during a game.

### The rest

- `history_screen.dart`, the list of all past games across all modes
- `players_screen.dart` and `player_stats_screen.dart`, player management and lifetime stats
- `settings_screen.dart`, `about_screen.dart`, `licenses_screen.dart`, `donation_screen.dart`
- `sync_screen.dart` and `backup_screen.dart`, the two transfer screens. Their rules live in `../services/AGENTS.md`, not here

## Contracts and Invariants

- Read state with `context.watch<XProvider>()`, act with `context.read<XProvider>().method()`. A screen never holds mutable game state of its own
- No screen queries SQLite. Everything goes through the provider, which goes through `db_helper.dart`
- The X01 summary and the X01 history detail render the same result through `SummaryPlayerCard`, `FinalRankingCard` and `ThrowLogCard`. A change to one view belongs in the shared widget, not in one screen
- `GameInfoCard` is deliberately `dense: true` in all four history detail screens and default in all four post-game summaries. It looks like an oversight per mode but is a convention across both sets; change it for all eight or for none
- A screen wide enough for two panes builds them with `SidePaneLayout` from `../utils/layout.dart`, gated on `isTabletLayout(context)`, and keeps the stacked single column for everything below it. Both branches render the same widgets; a layout that only one of the two reaches is how the phone and the tablet start drifting apart
- No screen scales its own text. The app applies the reader's text size once, in the `MaterialApp` builder in `main.dart`, so a wrapper on a single screen would only multiply it a second time there. The exception is a subtree that has to ignore the setting, like the exported summary card, which pins `TextScaler.noScaling` so the image is the same picture wherever it was made
- Only the live game, the history and the player list let their divider be dragged, and those three read it from `TabletLayoutProvider`. The rest divide in the middle and stay there: they put two things of the same kind beside each other, so there is nothing to rebalance
- The live game screens answer the system back with their quit dialog via `PopScope(canPop: false)`. That also suppresses the iOS edge swipe for as long as the game runs, which is the point: Flutter only installs the Cupertino back gesture on a route that may pop, so a confirmation cannot be shown from the gesture itself
- `licenses_screen.dart` shows what the `LicenseRegistry` holds, which is Flutter's `NOTICES` plus the native Android notices `utils/platform_notices.dart` registers at startup. It hides a package name only through `kDevelopmentOnlyPackages`, and hiding a name never hides a license: an entry shared with a shipped package still shows under that one. Over-listing a package is noise, leaving one out is a missing attribution
- Every user-visible string comes from `AppLocalizations`, every themed color from `ThemeProvider`

## Patterns

Adding a screen to an existing mode: mirror the same screen in the other three modes before inventing a layout. The four sets are meant to read alike.

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
