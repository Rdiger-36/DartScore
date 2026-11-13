import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/tablet_layout_provider.dart';
import '../utils/layout.dart';
import 'game_mode_info_screen.dart';
import 'game_setup_screen.dart';
import 'cricket_setup_screen.dart';
import 'shanghai_setup_screen.dart';
import 'around_the_clock_setup_screen.dart';
import 'checkout_ladder_setup_screen.dart';
import 'capital_setup_screen.dart';

/// Lets the user pick a game mode, listed under what it is played for.
///
/// On a phone and on an upright tablet a tap on a mode opens its setup and
/// the info button its rules. A tablet in landscape puts the rules of the
/// selected mode beside the list instead: a tap selects, and the button on
/// the bar under both panes opens the setup.
class GameModeSelectionScreen extends StatefulWidget {
  const GameModeSelectionScreen({super.key});

  @override
  State<GameModeSelectionScreen> createState() =>
      _GameModeSelectionScreenState();
}

class _GameModeSelectionScreenState extends State<GameModeSelectionScreen> {
  /// The mode whose rules the second pane shows. Only read in two panes.
  GameModeOption _selected = GameModeOption.x01;

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.sizeOf(context);
    final split = isTabletLayout(context) && size.width >= size.height;

    final list = _ModeList(
      selected: split ? _selected : null,
      onTap:    split
          ? (mode) => setState(() => _selected = mode)
          : _openSetup,
      onInfo:   split ? null : _openInfo,
      centered: !split,
    );

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.selectGameMode)),
      body: split ? _twoPaneBody(context, list) : SafeArea(child: list),
    );
  }

  /// The list beside the rules of the selected mode, with the button that
  /// opens its setup on a bar under both.
  ///
  /// The divider can be dragged, because the two panes are a list against
  /// what it opens: a reader of long rules wants them wider than the names.
  ///
  /// The panes keep clear of the system insets and the bar does not: it runs
  /// to the edges of the screen and only holds its button clear of them, or
  /// the home indicator and a status column at the side would leave a strip
  /// of the background showing around it.
  Widget _twoPaneBody(BuildContext context, Widget list) {
    final theme  = Theme.of(context);
    final layout = context.watch<TabletLayoutProvider>();

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: SidePaneLayout(
              side: InputSide.left,
              fraction: layout.splitFraction(SplitPane.modes, landscape: true),
              minPaneWidth: kMinListPaneWidth,
              onFractionChanged: (f) =>
                  layout.setSplitFraction(SplitPane.modes, f, landscape: true),
              onFractionSettled: () {
                layout.persistSplitFraction(SplitPane.modes, landscape: true);
              },
              primary: list,
              secondary: GameModeInfoPane(
                key: ValueKey(_selected),
                mode: _selected,
              ),
            ),
          ),
        ),
        Material(
          color: theme.colorScheme.surface,
          elevation: 3,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: FilledButton.icon(
                  onPressed: () => _openSetup(_selected),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(context.l10n.modeSetUpGame),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    textStyle: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the setup screen of [mode].
  void _openSetup(GameModeOption mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => switch (mode) {
          GameModeOption.x01            => const GameSetupScreen(),
          GameModeOption.cricket        => const CricketSetupScreen(),
          GameModeOption.shanghai       => const ShanghaiSetupScreen(),
          GameModeOption.aroundTheClock => const AroundTheClockSetupScreen(),
          GameModeOption.checkoutLadder => const CheckoutLadderSetupScreen(),
          GameModeOption.capital        => const CapitalSetupScreen(),
        },
      ),
    );
  }

  /// Opens the rules screen of [mode].
  void _openInfo(GameModeOption mode) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameModeInfoScreen(mode: mode)),
    );
  }
}

/// Every mode as a card, under a heading per [GameModeCategory].
///
/// Where the list is longer than the screen, on a small phone or with large
/// text, the heading of the category being read stays at the top until the
/// next one pushes it out.
class _ModeList extends StatelessWidget {
  /// The mode drawn as selected, or null where nothing is.
  final GameModeOption? selected;

  /// Called with the mode of the card that was tapped.
  final ValueChanged<GameModeOption> onTap;

  /// Called with the mode whose info button was tapped. Without it the cards
  /// show no info button.
  final ValueChanged<GameModeOption>? onInfo;

  /// Centres a list shorter than the screen instead of leaving it at the top,
  /// where it would sit above nothing, on an upright tablet half a screen of
  /// it. A list longer than the screen starts at the top and scrolls either
  /// way. Beside the rules it stays at the top, level with them.
  final bool centered;

  const _ModeList({
    required this.selected,
    required this.onTap,
    required this.onInfo,
    required this.centered,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = max(
          16.0,
          (constraints.maxWidth - contentMaxWidth(context)) / 2,
        );
        final padding = EdgeInsets.symmetric(horizontal: side);

        // Shrink wrapped, so a short list has a height to be aligned by; a
        // long one fills the screen and scrolls as it would anyway.
        return Align(
          alignment: centered ? Alignment.center : Alignment.topCenter,
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              for (final category in GameModeCategory.values)
                SliverMainAxisGroup(
                  slivers: [
                    PinnedHeaderSliver(
                      child: _CategoryHeading(
                        label:   gameModeCategoryLabel(category, l),
                        padding: padding,
                      ),
                    ),
                    SliverPadding(
                      padding: padding,
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final mode in GameModeOption.values)
                              if (gameModeCategory(mode) == category)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ModeCard(
                                    mode: mode,
                                    selected: mode == selected,
                                    onTap: () => onTap(mode),
                                    onInfo: onInfo == null
                                        ? null
                                        : () => onInfo!(mode),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 4)),
            ],
          ),
        );
      },
    );
  }
}

/// The name of a category with a line running from it to the edge.
class _CategoryHeading extends StatelessWidget {
  final String label;

  /// The side margins of the cards, so the heading lines up with them.
  final EdgeInsets padding;

  const _CategoryHeading({required this.label, required this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Opaque, or the cards would show through the heading they pass under.
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: padding + const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Divider(color: cs.outlineVariant, height: 1)),
          ],
        ),
      ),
    );
  }
}

/// A game mode as a card with its icon, name and tagline, and an info button
/// where [onInfo] is given.
class _ModeCard extends StatelessWidget {
  final GameModeOption mode;

  /// Draws the card in the primary color, as the one the second pane shows.
  final bool selected;

  final VoidCallback onTap;
  final VoidCallback? onInfo;

  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    final (name, tagline, _) = gameModeTexts(mode, l);
    final onCard = selected ? cs.onPrimaryContainer : cs.onSurface;

    return Card(
      margin: EdgeInsets.zero,
      color: selected ? cs.primaryContainer : Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? cs.primary : cs.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 12, onInfo == null ? 14 : 4, 12),
          child: Row(
            children: [
              gameModeIcon(mode, size: 32, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onCard,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onCard.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (onInfo != null)
                IconButton(
                  onPressed: onInfo,
                  icon: Icon(Icons.info_outline_rounded, color: cs.primary),
                  tooltip: l.modeInfoTitle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
