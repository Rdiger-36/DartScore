import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/capital_game.dart';
import '../providers/capital_provider.dart';
import '../utils/capital_stats.dart';
import '../utils/game_labels.dart';
import '../utils/player_label.dart';
import '../utils/visit_darts.dart';

/// The result of a Capital game, one row per slot over the capital each
/// finished with, every row unfolding into the fifteen rounds that produced
/// it. Shared by the post-game summary and the history detail, so the two
/// cannot drift apart.
///
/// Capital ranks on the capital alone, so a plain sort is the whole of it.
/// `utils/placement.dart` answers a different question, the per leg placement
/// points of an X01 game, and does not apply here.
class CapitalResultCard extends StatefulWidget {
  /// The slots as the provider left them, in seating order.
  final List<CapitalPlayerState> slots;

  /// The slot that finished alone on top, null when the top is shared.
  final int? winnerId;

  /// Every dart of the game. Each row keeps only its own slot's.
  final List<CapitalThrow> throws;

  const CapitalResultCard({
    super.key,
    required this.slots,
    required this.winnerId,
    required this.throws,
  });

  @override
  State<CapitalResultCard> createState() => _CapitalResultCardState();
}

class _CapitalResultCardState extends State<CapitalResultCard> {
  /// The player whose rounds are open, or null while the table is folded.
  /// One at a time: eight players unfolded at once is a page of numbers
  /// nobody is reading.
  int? _openId;

  @override
  Widget build(BuildContext context) {
    final l     = context.l10n;
    final theme = Theme.of(context);

    final sorted = List.of(widget.slots)
      ..sort((a, b) => b.total.compareTo(a.total));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.capitalSummaryTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(l.capitalTapForRounds,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            const Divider(height: 1),
            for (final slot in sorted)
              _SlotRow(
                slot:     slot,
                isWinner: widget.winnerId != null &&
                    slot.player.id == widget.winnerId,
                open:     slot.player.id == _openId,
                rounds:   slot.player.id == _openId
                    ? capitalRounds(widget.throws
                        .where((t) => t.playerId == slot.player.id)
                        .toList())
                    : const [],
                onTap: () => setState(() =>
                    _openId = _openId == slot.player.id ? null : slot.player.id),
              ),
          ],
        ),
      ),
    );
  }
}

/// One player's line, and their rounds while it is open.
class _SlotRow extends StatelessWidget {
  final CapitalPlayerState slot;
  final bool isWinner;
  final bool open;

  /// The rounds to list, empty while the row is folded: they are replayed only
  /// for the row the reader opened.
  final List<CapitalRound> rounds;

  final VoidCallback onTap;

  const _SlotRow({
    required this.slot,
    required this.isWinner,
    required this.open,
    required this.rounds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l     = context.l10n;
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                if (isWinner)
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
                      Text(
                        slot.label(l),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight:
                              isWinner ? FontWeight.bold : FontWeight.normal,
                          color: isWinner ? cs.primary : null,
                        ),
                      ),
                      Text(
                        l.capitalContractsMet(slot.contractsMet),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${slot.total}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isWinner ? cs.primary : null,
                      ),
                    ),
                    Text(
                      l.capitalFinalCapital,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                Icon(open ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 10),
            child: CapitalRoundList(rounds: rounds),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

/// One slot's rounds, oldest first. Shared by the result table, which unfolds
/// them under a finished player, and by the live info of a game still running,
/// which is the same list as far as it has got.
class CapitalRoundList extends StatelessWidget {
  final List<CapitalRound> rounds;

  const CapitalRoundList({super.key, required this.rounds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rounds.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(context.l10n.noThrowData,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final round in rounds) _RoundLine(round: round)],
    );
  }
}

/// One round: what it asked for, what was thrown, and the capital it left.
class _RoundLine extends StatelessWidget {
  final CapitalRound round;

  const _RoundLine({required this.round});

  @override
  Widget build(BuildContext context) {
    final l     = context.l10n;
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final failed = round.met == false;

    // The same arithmetic the live board shows under the thrower's name, by
    // the same formatter: a log that only named the capital would leave the
    // reader to work out how it got there.
    final sum = capitalScoreExpression(
          totalBefore: round.totalBefore,
          total:       round.total,
          met:         round.met,
          darts:       round.darts,
        ) ??
        '${round.total}';

    final nameStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: failed ? cs.error : cs.onSurfaceVariant,
    );
    final sumStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.bold,
      color: failed ? cs.error : null,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _nameWidth,
            child: Text(
              capitalContractName(l, round.contract),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: nameStyle,
            ),
          ),
          // A failed round's sum is only the halving, so the darts are the one
          // record of what was thrown at the contract. A round that scored has
          // every dart in its sum already, as 20 or 3*20, so listing them
          // again would say the same thing twice.
          if (failed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: _gap),
                child: Text(
                  round.darts
                      .map((dart) =>
                          visitDartFrom(dart.field, dart.multiplier, l).label)
                      .join('  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          if (failed)
            Text(sum, maxLines: 1, style: sumStyle)
          else
            Expanded(
              child: Text(
                sum,
                textAlign: TextAlign.end,
                maxLines: 1,
                // Ellipsized rather than wrapped: fifteen rounds over two
                // lines each is a page to scroll rather than a table to read.
                overflow: TextOverflow.ellipsis,
                style: sumStyle,
              ),
            ),
        ],
      ),
    );
  }

  /// Width the contract name column is given.
  static const double _nameWidth = 86;

  /// Space kept between the parts of a round.
  static const double _gap = 8;
}
