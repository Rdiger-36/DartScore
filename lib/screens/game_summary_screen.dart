import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/game_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/game_labels.dart';
import '../utils/throw_stats.dart';
import '../widgets/final_ranking_card.dart';
import '../widgets/game_info_card.dart';
import '../widgets/rematch_button.dart';
import '../widgets/summary_body.dart';
import '../widgets/summary_player_card.dart';
import '../widgets/throw_log_card.dart';
import 'game_screen.dart';

/// Post-game summary for X01: winner, per-player/team stats and throw history,
/// with options to save or share the result card as an image.
class GameSummaryScreen extends StatefulWidget {
  const GameSummaryScreen({super.key});

  @override
  State<GameSummaryScreen> createState() => _GameSummaryScreenState();
}

class _GameSummaryScreenState extends State<GameSummaryScreen> {
  final _cardKey = GlobalKey();

  /// The share button itself, because iPadOS anchors the share sheet to a
  /// rectangle on screen and refuses the call without one.
  final _shareKey = GlobalKey();

  bool _saving = false;

  /// Rasterizes the result card widget to a high-resolution image.
  ///
  /// Waits for the pending frame first: setting [_saving] swaps the export
  /// actions for a spinner, and that frame must be laid out and painted before
  /// the boundary is grabbed.
  Future<ui.Image> _renderCard() async {
    await WidgetsBinding.instance.endOfFrame;
    final ctx = _cardKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      throw StateError('Card widget is not mounted');
    }
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    return boundary.toImage(pixelRatio: 3.0);
  }

  /// Renders the result card and saves it to the device photo gallery.
  Future<void> _saveToPhotos() async {
    setState(() => _saving = true);
    try {
      final img = await _renderCard();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await Gal.putImageBytes(bytes!.buffer.asUint8List());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.savedToPhotos)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${context.l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Where the share sheet should point on a tablet.
  ///
  /// On an iPad the sheet is a popover that has to be anchored to something,
  /// and share_plus reports an error rather than opening without an anchor,
  /// which is why sharing did nothing there. Read before the spinner replaces
  /// the button, or there is nothing left to measure.
  Rect? _shareOrigin() {
    final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Renders the result card to a temporary PNG and opens the share sheet.
  Future<void> _shareCard() async {
    final origin = _shareOrigin();
    setState(() => _saving = true);
    final shareSubject = context.l10n.shareSubject;
    try {
      final img = await _renderCard();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/dartscore_ergebnis.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: shareSubject,
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${context.l10n.error}: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<GameProvider>();
    final states = provider.playerStates;
    final winner = states.firstWhere(
      (s) => s.players.any((p) => p.id == provider.winnerId),
      orElse: () => states.first,
    );
    final cs = Theme.of(context).colorScheme;
    final l = context.l10n;
    // What a leg checked out in the fewest darts the start score allows is
    // called, for the card of whoever managed one.
    final minDarts = minimumDartsForScore[provider.game!.startScore];
    final perfectLabel =
        minDarts == 9 ? l.nineDarter : l.perfectGameLabel(minDarts ?? 0);

    // Name of every player in the game, keyed by id, for the throw log.
    final throwerNames = {
      for (final s in states)
        for (final p in s.players) p.id: p.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l.gameOverview),
        automaticallyImplyLeading: false,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: l.saveToPhotos,
              onPressed: _saveToPhotos,
            ),
            IconButton(
              key: _shareKey,
              icon: const Icon(Icons.ios_share_rounded),
              tooltip: l.share,
              onPressed: _shareCard,
            ),
          ],
        ],
      ),
      // The captured card travels as one block: split across two columns, the
      // saved image would lose whichever half did not go with it.
      body: SummaryBody(
        result: [
          // The card that gets captured as image
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              color: cs.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  // Winner banner
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.emoji_events_rounded,
                              size: 52, color: cs.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l.wins(winner.displayName),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  // What the game was played with, so the saved or shared card
                  // carries its settings too.
                  GameInfoCard(rows: [
                    (l.gameLabel, l.modeX01Name),
                    (
                      l.matchFormat,
                      provider.game!.placementMode
                          ? l.placementMode
                          : l.standardMode
                    ),
                    (
                      l.gameMode_,
                      l.gameSummaryInfo(
                        provider.game!.startScore,
                        provider.game!.legs,
                        provider.game!.sets,
                        placementMode: provider.game!.placementMode,
                      )
                    ),
                    // A solo game has nobody to be ordered against.
                    if (states.length > 1)
                      (
                        l.startingOrder,
                        startingOrderLabel(l, provider.game!.startingOrder)
                      ),
                  ]),
                  const SizedBox(height: 16),
                  // Final ranking (placement mode only)
                  if (provider.game!.placementMode) ...[
                    FinalRankingCard(
                      throwsById:   {
                        for (var i = 0; i < states.length; i++) i: states[i].throws,
                      },
                      namesById:    {
                        for (var i = 0; i < states.length; i++) i: states[i].displayName,
                      },
                      legsWon:      {
                        for (var i = 0; i < states.length; i++) i: states[i].legsWon,
                      },
                      placementSum: {
                        for (var i = 0; i < states.length; i++) i: states[i].placementSum,
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Per-team or per-player stats
                  ...states.map((s) => SummaryPlayerCard(
                        name:    s.isTeam ? s.displayName : s.player.name,
                        throws:  s.throws,
                        // In placement mode every slot checks out every leg, so
                        // legs won come from the provider's tally instead of
                        // counting checkout visits.
                        legsWon: provider.game!.placementMode
                            ? s.legsWon
                            : legsWonFromThrows(s.throws),
                        // A single-set match has no set tally worth showing.
                        setsWon: provider.game!.sets > 1 ? s.setsWon : null,
                        members: s.isTeam
                            ? [
                                for (final p in s.players)
                                  (p.name, throwsOfPlayer(s.throws, p.id ?? -1)),
                              ]
                            : const [],
                        badge: s.perfectLegs > 0 ? perfectLabel : null,
                      )),
                ],
              ),
            ),
          ),
        ],
        details: [
          // Throw history (outside captured area: too long for image)
          ThrowLogCard(
            throws: provider.allThrows(),
            // Look the thrower up across every slot member: a team slot's
            // `player` is only whoever throws next, so matching on that alone
            // misses the team's other members.
            playerName: (id) => throwerNames[id] ?? '',
            showSet: provider.game!.sets > 1,
          ),
        ],
        actions: [
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home_rounded),
            label: Text(l.backToHome),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          RematchButton(
            modeName: l.modeX01Name,
            details: [
              (
                l.matchFormat,
                provider.game!.placementMode ? l.placementMode : l.standardMode
              ),
              (
                l.gameMode_,
                l.gameSummaryInfo(
                  provider.game!.startScore,
                  provider.game!.legs,
                  provider.game!.sets,
                  placementMode: provider.game!.placementMode,
                )
              ),
              // With handicaps the game defaults say little, so the per-player
              // rows of the summary carry the rules instead.
              if (!provider.game!.hasHandicaps) ...[
                (l.checkIn, checkInLabel(l, provider.game!.gameMode)),
                (l.checkOut, checkOutLabel(l, provider.game!.checkoutMode)),
              ],
            ],
            slots: states
                .map((s) => s.isTeamSlot
                    ? RematchSlot.team(
                        s.displayName,
                        s.players
                            .map((p) => RematchSlot.player(p.name,
                                rules: handicapRulesLabel(
                                    l, provider.game!, p.id)))
                            .toList())
                    : RematchSlot.player(
                        s.displayName,
                        rules: handicapRulesLabel(
                            l, provider.game!, s.player.id),
                      ))
                .toList(),
            onRematch: () => provider.startRematch(
              provider.game!,
              provider.playerStates.expand((s) => s.players).toList(),
            ),
            destination: (_) => const GameScreen(),
          ),
        ],
      ),
    );
  }
}
