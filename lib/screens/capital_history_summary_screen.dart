import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/capital_game.dart';
import '../models/player.dart';
import '../providers/capital_provider.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../utils/player_label.dart';
import '../widgets/game_info_card.dart';
import '../widgets/rematch_button.dart';
import '../widgets/summary_body.dart';
import 'capital_screen.dart';

/// Detailed view of a finished Capital game from history, rebuilt by replaying
/// its stored darts through a fresh provider.
class CapitalHistorySummaryScreen extends StatefulWidget {
  final CapitalGame game;
  final List<Player> players;

  /// Whether this sits inside a pane that brings its own title bar, as the
  /// master detail layout of the history does on a tablet.
  final bool embedded;

  const CapitalHistorySummaryScreen({
    super.key,
    required this.game,
    required this.players,
    this.embedded = false,
  });

  @override
  State<CapitalHistorySummaryScreen> createState() =>
      _CapitalHistorySummaryScreenState();
}

class _CapitalHistorySummaryScreenState
    extends State<CapitalHistorySummaryScreen> {
  /// Started once and kept, not started again on every build: a pane whose
  /// divider is being dragged rebuilds every frame, and a read begun in
  /// `build` would fall back to its spinner for the length of the drag.
  late Future<CapitalProvider> _future = _load();

  @override
  void didUpdateWidget(CapitalHistorySummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.id != widget.game.id) _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    return _wrap(
      context,
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: FutureBuilder<CapitalProvider>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final provider = snap.data;
              if (provider == null) {
                return Center(child: Text(context.l10n.noThrowData));
              }
              return _Body(
                game: widget.game,
                players: widget.players,
                provider: provider,
              );
            },
          ),
        ),
      ),
    );
  }

  /// Puts the screen around [content], or hands it over bare when embedded in
  /// a pane that already has a title bar of its own.
  Widget _wrap(BuildContext context, Widget content) => widget.embedded
      ? content
      : Scaffold(
          appBar: AppBar(
            title: Text(
                DateFormat('dd.MM.yy  HH:mm').format(widget.game.createdAt)),
          ),
          body: content,
        );

  /// Replays the game's darts through a standalone provider, so the totals and
  /// the contracts met are recomputed by the one scoring rule rather than by a
  /// second one written for this screen.
  Future<CapitalProvider> _load() async {
    final provider = CapitalProvider();
    await provider.resumeGame(widget.game, widget.players);
    return provider;
  }
}

/// Renders the replayed game: who finished where, and on what.
class _Body extends StatelessWidget {
  final CapitalGame game;
  final List<Player> players;
  final CapitalProvider provider;

  const _Body({
    required this.game,
    required this.players,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = context.l10n;
    final states = provider.playerStates;
    final winnerId = provider.winnerId;

    final sorted = List.of(states)
      ..sort((a, b) => b.total.compareTo(a.total));

    return SummaryBody(
      top: 8,
      bottom: 16,
      result: [
        GameInfoCard(rows: [
          (l.gameLabel, l.modeCapitalName),
          (l.startingOrder, startingOrderLabel(l, game.startingOrder)),
        ]),
      ],
      details: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.capitalSummaryTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                for (final slot in sorted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        if (winnerId != null && slot.player.id == winnerId)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Icon(Icons.emoji_events_rounded, size: 18),
                          )
                        else
                          const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(slot.label(l),
                                  style: theme.textTheme.titleSmall),
                              Text(
                                l.capitalContractsMet(slot.contractsMet),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${slot.total}',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      actions: [
        RematchButton(
          modeName: l.modeCapitalName,
          details: const [],
          slots:
              states.map((s) => RematchSlot.player(s.label(l))).toList(),
          onRematch: () => context
              .read<CapitalProvider>()
              .startRematch(game, states.map((s) => s.player).toList()),
          destination: (_) => const CapitalScreen(),
        ),
      ],
    );
  }
}
