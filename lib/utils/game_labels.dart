import '../l10n/app_localizations.dart';
import '../models/around_the_clock_game.dart';
import '../models/checkout_ladder_game.dart' show CheckoutLadderGame, CheckoutLadderVariant;
import '../models/cricket_game.dart';
import '../models/game.dart';
import '../models/shanghai_game.dart';
import 'capital_rules.dart';
import 'dartboard_geometry.dart';

/// Localized display names for the per-mode game settings, shared by the
/// history lists, the history detail screens and the rematch dialog so the
/// same setting always reads the same way.

/// Localized display name for an X01 check-in [mode].
String checkInLabel(AppLocalizations l, GameMode mode) {
  switch (mode) {
    case GameMode.straightIn:
      return l.straight;
    case GameMode.doubleIn:
      return l.double_;
    case GameMode.masterIn:
      return l.master;
  }
}

/// Localized display name for an X01 check-out [mode].
String checkOutLabel(AppLocalizations l, CheckoutMode mode) {
  switch (mode) {
    case CheckoutMode.straightOut:
      return l.straight;
    case CheckoutMode.doubleOut:
      return l.double_;
    case CheckoutMode.masterOut:
      return l.master;
  }
}

/// Localized "check-in to check-out" summary of one player's X01 rules, used
/// where the per-player rules matter more than the game defaults.
String checkInOutLabel(AppLocalizations l, GameMode checkIn, CheckoutMode checkOut) =>
    '${checkInLabel(l, checkIn)} → ${checkOutLabel(l, checkOut)}';

/// The check-in/check-out label for [playerId] in [game], or null when the game
/// is played without handicaps and the game-wide rules already say everything.
String? handicapRulesLabel(AppLocalizations l, Game game, int? playerId) =>
    game.hasHandicaps
        ? checkInOutLabel(
            l, game.checkInFor(playerId), game.checkOutFor(playerId))
        : null;

/// Localized display name for how a game's throwing [order] was determined.
String startingOrderLabel(AppLocalizations l, StartingOrder order) {
  switch (order) {
    case StartingOrder.random:
      return l.startingOrderRandom;
    case StartingOrder.fixed:
      return l.startingOrderFixed;
  }
}

/// Names one board segment: the [field] hit and with which [multiplier]
/// (1 single, 2 double, 3 triple), as `S20`, `D20` or `T20`.
///
/// Field 0 is a miss and field 25 the bull, whose outer ring counts 25 and
/// whose centre is the bull's eye. Deliberately not the same notation as
/// `DartEntry.label`: that one names a dart as it is entered, where a single
/// carries no prefix, while a statistics list is only scannable when every
/// entry is spelled the same way.
String segmentLabel(AppLocalizations l, int field, int multiplier) {
  if (field == 0)  return l.miss;
  if (field == 25) return multiplier == 2 ? l.bull : '25';
  switch (multiplier) {
    case 2:
      return 'D$field';
    case 3:
      return 'T$field';
    default:
      return 'S$field';
  }
}

/// Localized display name for a Cricket [variant].
String cricketVariantLabel(AppLocalizations l, CricketVariant variant) {
  switch (variant) {
    case CricketVariant.normal:
      return l.cricketVariantNormal;
    case CricketVariant.cutThroat:
      return l.cricketVariantCutThroat;
  }
}

/// Localized display name for a Cricket scoring [mode].
String cricketScoringModeLabel(AppLocalizations l, CricketScoringMode mode) {
  switch (mode) {
    case CricketScoringMode.standard:
      return l.cricketStandard;
    case CricketScoringMode.simple:
      return l.cricketSimple;
  }
}

/// Localized display name for a Shanghai [variant].
String shanghaiVariantLabel(AppLocalizations l, ShanghaiVariant variant) {
  switch (variant) {
    case ShanghaiVariant.classic:
      return l.shanghaiClassic;
    case ShanghaiVariant.clockwise:
      return l.shanghaiClockwise;
    case ShanghaiVariant.sequential:
      return l.shanghaiSequential;
  }
}

/// Localized display name for an Around the Clock [variant].
String aroundTheClockVariantLabel(
    AppLocalizations l, AroundTheClockVariant variant) {
  switch (variant) {
    case AroundTheClockVariant.basic:
      return l.aroundClockBasic;
    case AroundTheClockVariant.fullSegments:
      return l.aroundClockFullSegments;
    case AroundTheClockVariant.skipRules:
      return l.aroundClockSkipRules;
  }
}

/// Localized display name for a Checkout Ladder [variant].
String checkoutLadderVariantLabel(
    AppLocalizations l, CheckoutLadderVariant variant) {
  switch (variant) {
    case CheckoutLadderVariant.training:
      return l.ladderTraining;
    case CheckoutLadderVariant.race:
      return l.ladderRace;
  }
}

/// The darts an attempt of [game] holds, with the step when there is one:
/// `6`, or `6, from 110: 9`.
String checkoutLadderDartsLabel(AppLocalizations l, CheckoutLadderGame game) =>
    game.stepFrom != null && game.stepDarts != null
        ? '${game.dartsPerAttempt}, ${l.ladderStepFrom} ${game.stepFrom}: ${game.stepDarts}'
        : '${game.dartsPerAttempt}';

/// The settings of a Checkout Ladder [game] as label and value pairs, in the
/// order the summary, the history detail and the rematch dialog list them.
List<(String, String)> checkoutLadderSettingRows(
        AppLocalizations l, CheckoutLadderGame game) =>
    [
      (l.ladderVariant, checkoutLadderVariantLabel(l, game.variant)),
      (l.ladderStartNumber, '${game.startNumber}'),
      if (game.isRace && game.targetNumber != null)
        (l.ladderTargetNumber, '${game.targetNumber}'),
      (l.ladderDartsPerAttempt, checkoutLadderDartsLabel(l, game)),
      (l.checkOut, checkOutLabel(l, game.checkOut)),
    ];
// ── Capital ──────────────────────────────────────────────────────────────────

/// The name a Capital [contract] is shown under.
///
/// The seven numbered contracts are named by their sector, which reads the
/// same in every language and so carries no localization entry.
String capitalContractName(AppLocalizations l, CapitalContract contract) {
  if (contract.sector case final sector?) return '$sector';
  return switch (contract) {
    CapitalContract.capital    => l.capitalContractCapital,
    CapitalContract.anyTriple  => l.capitalContractTriple,
    CapitalContract.anyDouble  => l.capitalContractDouble,
    CapitalContract.side       => l.capitalContractSideBySide,
    CapitalContract.run        => l.capitalContractRun,
    CapitalContract.colors     => l.capitalContractColors,
    CapitalContract.fiftySeven => '57',
    CapitalContract.center     => l.capitalContractCenter,
    _                          => '',
  };
}

/// The one line reminder shown under a contract's name before any dart lands.
String capitalContractReminder(AppLocalizations l, CapitalContract contract) {
  if (contract.sector != null) return l.capitalReminderAnyRing;
  return switch (contract) {
    CapitalContract.capital    => l.capitalReminderCapital,
    CapitalContract.anyTriple  => l.capitalReminderTriple,
    CapitalContract.anyDouble  => l.capitalReminderDouble,
    CapitalContract.side       => l.capitalReminderSideBySide,
    CapitalContract.run        => l.capitalReminderRun,
    CapitalContract.colors     => l.capitalReminderColors,
    CapitalContract.fiftySeven => l.capitalReminderFiftySeven,
    CapitalContract.center     => l.capitalReminderCenter,
    _                          => '',
  };
}

/// The localized name of a board [color].
String boardColorLabel(AppLocalizations l, BoardColor color) =>
    switch (color) {
      BoardColor.black => l.capitalColorBlack,
      BoardColor.white => l.capitalColorWhite,
      BoardColor.red   => l.capitalColorRed,
      BoardColor.green => l.capitalColorGreen,
    };

/// What the band says once [darts] have landed in the current visit.
///
/// Falls back to the standing reminder for the eleven contracts whose answer
/// never changes, and for a visit that has not started. The four that do
/// change report what is still open, listing every combination rather than
/// describing it: a dart already thrown may be the low end, the middle or the
/// high end of its run, so no short description of the remainder is true.
String capitalProgressLine(
  AppLocalizations l,
  CapitalContract contract,
  List<BoardHit> darts,
) {
  if (darts.isEmpty) return capitalContractReminder(l, contract);

  switch (contract) {
    case CapitalContract.run:
      return _shapeLine(l, remainingRuns(darts), darts, l.capitalNoRun);
    case CapitalContract.side:
      return _shapeLine(l, remainingArcs(darts), darts, l.capitalNoArc);
    case CapitalContract.colors:
      final open = unusedColors(darts);
      if (open.isEmpty) return capitalContractReminder(l, contract);
      final thrown = darts
          .map((dart) => boardColorLabel(l, colorOf(dart)!))
          .join(', ');
      if (darts.length == 2) {
        return '$thrown. ${l.capitalNeed(_join(l, open.map((c) => boardColorLabel(l, c)).toList(), l.capitalOr))}';
      }
      return '$thrown. ${l.capitalNeedOtherColors(3 - darts.length)}';
    case CapitalContract.fiftySeven:
      final left = pointsToFiftySeven(darts);
      if (left == null || left == 0) return capitalContractReminder(l, contract);
      return l.capitalNeedPoints(left);
    default:
      return capitalContractReminder(l, contract);
  }
}

/// The line for the two shape contracts, which share their structure.
///
/// Before the last dart every surviving combination is listed whole, because
/// which of them the player goes for is still open. Once two darts are down
/// the combinations differ only in the one field left, so only that is named.
String _shapeLine(
  AppLocalizations l,
  List<List<int>> combinations,
  List<BoardHit> darts,
  String impossible,
) {
  if (combinations.isEmpty) return impossible;
  final thrown = darts.map((dart) => dart.field).toSet();
  if (darts.length >= 2) {
    final missing = combinations
        .expand((combination) => combination)
        .where((field) => !thrown.contains(field))
        .toSet()
        .toList();
    return l.capitalNeed(_join(l, missing.map((f) => '$f').toList(), l.capitalOr));
  }
  if (combinations.length == 1) {
    final missing = combinations.single.where((f) => !thrown.contains(f));
    return l.capitalNeed(
        _join(l, missing.map((f) => '$f').toList(), l.capitalAnd));
  }
  return l.capitalMake(_join(
    l,
    combinations.map((combination) => combination.join('-')).toList(),
    l.capitalOr,
  ));
}

/// Joins [parts] with commas and [conjunction] before the last.
String _join(AppLocalizations l, List<String> parts, String conjunction) {
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} $conjunction ${parts.last}';
}

/// The arithmetic that produced a slot's capital, shown after its visit.
///
/// A met contract reads as the capital it started from plus the visit in
/// brackets, so the three darts stay visibly one group and cannot be mistaken
/// for a fourth term: `11 + (3*20 + 20 + 2*5) = 136`. A failed one reads as
/// the halving that was applied, in ceiling brackets because the rounding is
/// up: `⌈57/2⌉ = 29`. The opening round has no capital to add to, so it shows
/// the darts alone.
///
/// Every operator is spaced the same way, so each throw is its own block at a
/// glance. Returns null before the slot has completed a visit.
String? capitalScoreExpression({
  required int totalBefore,
  required int total,
  required bool? met,
  required List<BoardHit> darts,
}) {
  if (darts.isEmpty) return null;
  if (met == false) return '\u2308$totalBefore/2\u2309 = $total';

  final scored = darts.where((dart) => scoreOf(dart) > 0).map(_dartTerm);
  final terms = scored.isEmpty ? '0' : scored.join(' + ');
  if (met == null) return '$terms = $total';
  return '$totalBefore + ($terms) = $total';
}

/// One dart as the expression writes it.
///
/// A single is the bare number, and a double or triple shows the ring it
/// landed in multiplied by the number, so the sum can be followed without
/// knowing which ring each dart found. Both bulls are written as the points
/// they score, because a player reads the bull as fifty rather than as twice
/// twenty five.
String _dartTerm(BoardHit dart) {
  if (dart.field == 25) return '${scoreOf(dart)}';
  if (dart.multiplier == 1) return '${dart.field}';
  return '${dart.multiplier}*${dart.field}';
}
