import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/capital_provider.dart';
import '../utils/capital_rules.dart';
import '../utils/dartboard_geometry.dart';
import '../utils/game_labels.dart';
import '../utils/layout.dart';
import '../utils/player_label.dart';
import '../utils/segment_color.dart';
import '../utils/visit_darts.dart';
import '../widgets/visit_darts_row.dart';
import '../widgets/visit_pause.dart';

/// The live Capital screen: the capitals, the contract band, the visit and the
/// board input.
class CapitalScreen extends StatelessWidget {
  const CapitalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = context.watch<CapitalProvider>();
    if (provider.game == null) return const Scaffold(body: SizedBox.shrink());

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await provider.leaveGame();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.modeCapitalName),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              await provider.leaveGame();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: provider.canUndo ? provider.undoLastDart : null,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: contentPadding(context, top: 8, bottom: 8, innerH: 12),
            child: Column(
              children: [
                _Scoreboard(provider: provider),
                const SizedBox(height: 8),
                _ContractBand(provider: provider),
                const SizedBox(height: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: provider.visitPending ? provider.flushHeldVisit : null,
                  child: Column(
                    children: [
                      VisitDartsRow(
                        darts: [
                          for (final dart in provider.visitBuffer)
                            visitDartFrom(dart.field, dart.multiplier, l),
                        ],
                      ),
                      VisitPauseBar(pending: provider.visitPending),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _CapitalInput(provider: provider)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row per player: who they are, the capital they hold, and whether the
/// round they last finished halved them.
class _Scoreboard extends StatelessWidget {
  final CapitalProvider provider;
  const _Scoreboard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, slot) in provider.playerStates.indexed)
            ListTile(
              dense: true,
              selected: index == provider.currentPlayerIndex,
              leading: index == provider.currentPlayerIndex
                  ? const Icon(Icons.play_arrow, size: 18)
                  : const SizedBox(width: 18),
              title: Text(slot.label(l)),
              subtitle: slot.lastRoundMet == false
                  ? Text(
                      l.capitalHalved,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.error),
                    )
                  : null,
              trailing: Text(
                '${slot.total}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

/// The contract band: which round this is, what it asks, and what the visit
/// still needs once darts have landed.
class _ContractBand extends StatelessWidget {
  final CapitalProvider provider;
  const _ContractBand({required this.provider});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final contract = provider.contract;
    final met = provider.contractMet && contract != CapitalContract.capital;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: met
            ? doubleContainerColor(context)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.capitalRoundLabel(provider.currentRound),
            style: theme.textTheme.labelSmall?.copyWith(
              color: met
                  ? onDoubleContainerColor(context)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  capitalContractName(l, contract),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: met ? onDoubleContainerColor(context) : null,
                  ),
                ),
              ),
              if (met)
                Icon(Icons.check_circle,
                    size: 20, color: onDoubleContainerColor(context)),
            ],
          ),
          Text(
            capitalProgressLine(l, contract, provider.visitHits),
            style: theme.textTheme.bodySmall?.copyWith(
              color: met
                  ? onDoubleContainerColor(context)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The board input: a ring modifier, the twenty numbers, both bulls and a miss.
///
/// Capital judges where a dart actually landed rather than whether it hit a
/// named target, so unlike Shanghai it needs the whole board rather than a
/// multiplier alone.
class _CapitalInput extends StatefulWidget {
  final CapitalProvider provider;
  const _CapitalInput({required this.provider});

  @override
  State<_CapitalInput> createState() => _CapitalInputState();
}

class _CapitalInputState extends State<_CapitalInput> {
  /// The ring the next number tapped lands in, which resets after each dart.
  int _multiplier = 1;

  Future<void> _record(BoardHit hit) async {
    await widget.provider.recordDart(hit);
    if (mounted) setState(() => _multiplier = 1);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locked = widget.provider.inputLocked;

    return Column(
      children: [
        Row(
          children: [
            _ring(context, l.single, 1),
            const SizedBox(width: 6),
            _ring(context, l.double_, 2),
            const SizedBox(width: 6),
            _ring(context, l.triple, 3),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.count(
            crossAxisCount: 5,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.4,
            children: [
              for (var field = 1; field <= 20; field++)
                _button(
                  context,
                  '$field',
                  locked
                      ? null
                      : () => _record((field: field, multiplier: _multiplier)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _button(context, '25',
                  locked ? null : () => _record((field: 25, multiplier: 1))),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button(context, 'Bull',
                  locked ? null : () => _record((field: 25, multiplier: 2))),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _button(
                  context, l.miss, locked ? null : () => _record(boardMiss)),
            ),
          ],
        ),
      ],
    );
  }

  /// One ring selector, tinted the way a multiplied field is tinted elsewhere.
  Widget _ring(BuildContext context, String label, int multiplier) {
    final selected = _multiplier == multiplier;
    final background = switch (multiplier) {
      3 => tripleContainerColor(context),
      2 => doubleContainerColor(context),
      _ => Theme.of(context).colorScheme.surfaceContainerHighest,
    };
    return Expanded(
      child: FilledButton(
        onPressed: () => setState(() => _multiplier = multiplier),
        style: FilledButton.styleFrom(
          backgroundColor: selected
              ? background
              : Theme.of(context).colorScheme.surfaceContainerLow,
          foregroundColor: selected && multiplier == 3
              ? onTripleContainerColor(context)
              : selected && multiplier == 2
                  ? onDoubleContainerColor(context)
                  : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label),
      ),
    );
  }

  /// One board button.
  Widget _button(BuildContext context, String label, VoidCallback? onTap) =>
      FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        child: FittedBox(child: Text(label)),
      );
}
