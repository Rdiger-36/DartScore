import 'dart:math';

import '../models/dart_throw.dart';

/// Aggregated statistics derived from a list of X01 visits.
///
/// The single implementation of these formulas in the app. The live info screen
/// computes them from the visits held in memory, the summary and history screens
/// from the visits of one finished game, and `DbHelper` from the visits it is
/// about to archive, so a number read during a game means exactly what the same
/// number means on the lifetime stats screen years later.
///
/// The values are pinned by hand-computed cases in
/// `test/utils/throw_stats_test.dart`; that a snapshot stores them under the
/// right keys is a separate concern, checked by
/// `test/database/stats_snapshot_keys_test.dart`.
///
/// Two deliberate omissions:
/// * Legs won is not part of this record. The live screens read
///   `PlayerState.legsWon`, which the game provider maintains correctly for the
///   placement mode where a leg is played out by everyone.
/// * Only committed visits are counted. Darts of a visit that is still being
///   entered are not included, because folding them in would make every average
///   jump back once the visit is committed.
class ThrowStats {
  /// Number of committed visits (turns), busts included.
  final int totalVisits;
  /// Number of darts thrown across all visits, busts included.
  final int totalDarts;
  /// Points scored across all visits; a bust contributes nothing.
  final int totalScored;
  /// Number of visits that busted.
  final int busts;

  /// Highest score of a single visit; busts are ignored.
  final int highestVisit;
  /// Highest score that finished a leg.
  final int highestCheckout;

  final int count180;
  final int count140plus;
  final int count100plus;

  /// Visits that started on a finishable remaining, busts included: starting a
  /// visit below 171 is an attempt at the finish whether or not it overshot.
  final int checkoutAttempts;
  /// Attempts that actually finished the leg.
  final int checkoutSuccesses;

  /// Sum of the squared visit scores, used for [scoreStdDev].
  final int scoreSumSquares;

  /// Darts used in the opening three visits of every leg.
  final int first9Darts;
  /// Points scored in the opening three visits of every leg.
  final int first9Scored;

  final int coAttemptSub40;
  final int coSuccessSub40;
  final int coAttemptSub60;
  final int coSuccessSub60;
  final int coAttemptSub100;
  final int coSuccessSub100;
  final int coAttemptSub170;
  final int coSuccessSub170;

  const ThrowStats._({
    required this.totalVisits,
    required this.totalDarts,
    required this.totalScored,
    required this.busts,
    required this.highestVisit,
    required this.highestCheckout,
    required this.count180,
    required this.count140plus,
    required this.count100plus,
    required this.checkoutAttempts,
    required this.checkoutSuccesses,
    required this.scoreSumSquares,
    required this.first9Darts,
    required this.first9Scored,
    required this.coAttemptSub40,
    required this.coSuccessSub40,
    required this.coAttemptSub60,
    required this.coSuccessSub60,
    required this.coAttemptSub100,
    required this.coSuccessSub100,
    required this.coAttemptSub170,
    required this.coSuccessSub170,
  });

  /// Stats of a player who has not thrown yet: every counter is zero.
  static const ThrowStats empty = ThrowStats._(
    totalVisits:       0,
    totalDarts:        0,
    totalScored:       0,
    busts:             0,
    highestVisit:      0,
    highestCheckout:   0,
    count180:          0,
    count140plus:      0,
    count100plus:      0,
    checkoutAttempts:  0,
    checkoutSuccesses: 0,
    scoreSumSquares:   0,
    first9Darts:       0,
    first9Scored:      0,
    coAttemptSub40:    0,
    coSuccessSub40:    0,
    coAttemptSub60:    0,
    coSuccessSub60:    0,
    coAttemptSub100:   0,
    coSuccessSub100:   0,
    coAttemptSub170:   0,
    coSuccessSub170:   0,
  );

  /// Aggregates [throws] into one stats record.
  ///
  /// [throws] is expected in throwing order, which is how the game provider and
  /// the database both hand it out. The order only matters for the first 9
  /// values, which take the opening visits of each leg.
  factory ThrowStats.fromThrows(List<DartThrow> throws) {
    if (throws.isEmpty) return empty;

    int totalDarts = 0, totalScored = 0, busts = 0;
    int highestVisit = 0, highestCheckout = 0;
    int count180 = 0, count140plus = 0, count100plus = 0;
    int checkoutAttempts = 0, checkoutSuccesses = 0;
    int scoreSumSquares = 0;
    int first9Darts = 0, first9Scored = 0;
    int coAt40 = 0, coOk40 = 0;
    int coAt60 = 0, coOk60 = 0;
    int coAt100 = 0, coOk100 = 0;
    int coAt170 = 0, coOk170 = 0;

    // Visits already seen per leg, so the opening three of each leg can be
    // picked out without sorting the list.
    final visitsPerLeg = <String, int>{};

    for (final t in throws) {
      totalDarts += t.dartsUsed;

      final legKey    = '${t.set}-${t.leg}';
      final legVisits = visitsPerLeg[legKey] ?? 0;
      visitsPerLeg[legKey] = legVisits + 1;
      if (legVisits < 3) {
        first9Darts  += t.dartsUsed;
        first9Scored += t.bust ? 0 : t.score;
      }

      if (t.bust) {
        busts++;
      } else {
        totalScored     += t.score;
        scoreSumSquares += t.score * t.score;
        if (t.score > highestVisit) highestVisit = t.score;
        if (t.score == 180) count180++;
        if (t.score >= 140) count140plus++;
        if (t.score >= 100) count100plus++;
      }

      if (t.remainingBefore <= 170) {
        checkoutAttempts++;
        final success = !t.bust && t.remainingBefore - t.score == 0;
        if (t.remainingBefore <= 40)        { coAt40++;  if (success) coOk40++;  }
        else if (t.remainingBefore <= 60)   { coAt60++;  if (success) coOk60++;  }
        else if (t.remainingBefore <= 100)  { coAt100++; if (success) coOk100++; }
        else                                { coAt170++; if (success) coOk170++; }
        if (success) {
          checkoutSuccesses++;
          if (t.score > highestCheckout) highestCheckout = t.score;
        }
      }
    }

    return ThrowStats._(
      totalVisits:       throws.length,
      totalDarts:        totalDarts,
      totalScored:       totalScored,
      busts:             busts,
      highestVisit:      highestVisit,
      highestCheckout:   highestCheckout,
      count180:          count180,
      count140plus:      count140plus,
      count100plus:      count100plus,
      checkoutAttempts:  checkoutAttempts,
      checkoutSuccesses: checkoutSuccesses,
      scoreSumSquares:   scoreSumSquares,
      first9Darts:       first9Darts,
      first9Scored:      first9Scored,
      coAttemptSub40:    coAt40,
      coSuccessSub40:    coOk40,
      coAttemptSub60:    coAt60,
      coSuccessSub60:    coOk60,
      coAttemptSub100:   coAt100,
      coSuccessSub100:   coOk100,
      coAttemptSub170:   coAt170,
      coSuccessSub170:   coOk170,
    );
  }

  /// Three-dart average over all visits; busts count as zero scored.
  double get average => totalDarts == 0 ? 0 : (totalScored / totalDarts) * 3;

  /// Three-dart average over the opening three visits of every leg.
  double get first9Average =>
      first9Darts == 0 ? 0 : (first9Scored / first9Darts) * 3;

  /// Share of visits that busted, in percent.
  double get bustRate => totalVisits == 0 ? 0 : (busts / totalVisits) * 100;

  /// Share of checkout attempts that finished a leg, in percent.
  double get checkoutRate =>
      checkoutAttempts == 0 ? 0 : (checkoutSuccesses / checkoutAttempts) * 100;

  /// Standard deviation of the scored visits, as a measure of consistency.
  /// Busts are excluded so a single overshoot does not read as inconsistency.
  double get scoreStdDev {
    final scoredVisits = totalVisits - busts;
    if (scoredVisits <= 1 || scoreSumSquares == 0) return 0;
    final mean     = totalScored / scoredVisits;
    final variance = (scoreSumSquares / scoredVisits) - mean * mean;
    return variance > 0 ? sqrt(variance) : 0;
  }
}

/// Legs won according to the throws alone: visits that took the slot to exactly
/// zero.
///
/// Not valid in placement mode, where every slot checks out every leg and the
/// leg winner follows from the finishing order instead; use the provider's
/// tally or `placementRanking` there.
int legsWonFromThrows(List<DartThrow> throws) =>
    throws.where((t) => !t.bust && t.remainingBefore - t.score == 0).length;

/// The subset of [throws] played in [leg] of [set], in their original order.
List<DartThrow> throwsInLeg(List<DartThrow> throws, int leg, int set) =>
    throws.where((t) => t.leg == leg && t.set == set).toList();

/// The subset of [throws] thrown by [playerId], in their original order. Used
/// to break a team slot's throws down by member.
List<DartThrow> throwsOfPlayer(List<DartThrow> throws, int playerId) =>
    throws.where((t) => t.playerId == playerId).toList();
