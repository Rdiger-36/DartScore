# Widgets

The building blocks the screens are assembled from. Owns rendering and local UI interaction. Owns no app state, no database access and no statistics formula.

## Entry Points

### Input and dartboard

- `dartboard_input.dart`, dartboard-style tap input
- `dartboard_icon.dart`, decorative dartboard SVG widget
- `dartboard_target_painter.dart`, paints a dartboard with a target segment highlighted
- `cricket_marks_widget.dart`, renders Cricket marks (slash / X / circle-X) for a field
- `finish_suggestion_widget.dart`, checkout hint display
- `favorite_double_picker.dart`, picks a player's favorite doubles

### Shared setup blocks, used by every mode

- `team_section.dart`, team naming, add/remove and assignment
- `starting_order_section.dart`, random vs. fixed plus the drag-to-sort list

### Shared result rendering

- `game_info_card.dart`, the card listing a finished game's settings
- `summary_player_card.dart`, the player/team stat card for the X01 summary and history screens
- `final_ranking_card.dart`, the placement-mode ranking card and per-leg table
- `stat_row.dart`, the label/value row used by every stat list
- `throw_log_card.dart`, the "All Throws" log for the X01 summary and history screens
- `rematch_button.dart`, "Play Again" plus its confirmation dialog

### Transfers and players

- `wifi_pairing.dart`, the QR scanner, the pairing number dialog and the QR card, shared by sync and backup
- `player_dialog.dart`, create/edit player dialog

## Contracts and Invariants

- A widget never holds mutable app state and never touches SQLite. It takes what it renders as a parameter or reads a provider
- The shared result widgets are shared on purpose: the X01 summary and the X01 history detail render the same result through `SummaryPlayerCard`, `FinalRankingCard` and `ThrowLogCard`. Fix the widget, not one of the two screens
- `GameInfoCard` takes `dense: true` from the four history detail screens and the default from the four post-game summaries. That split is a convention across both sets, not a per-mode oversight
- Colors come from `ThemeProvider`, team accents from `utils/team_color.dart`, triple affordances from `utils/triple_color.dart`
- Strings come from `AppLocalizations`, and the per-mode setting names from `utils/game_labels.dart`

## Patterns

A block that a second game mode is about to need belongs here, parameterised, rather than copied into the second setup screen. `TeamSection` and `StartingOrderSection` are what that looks like when it is done.

## Anti-patterns

- Do not compute stats in a widget. `ThrowStats` is the one aggregation
- Do not hardcode a color that should follow the theme
- Do not copy `wifi_pairing.dart` for a third transfer flow; both sync and backup already share it

## Related Context

- Screens that compose these: `../screens/AGENTS.md`
- What the pairing UI is driving: `../services/AGENTS.md`
