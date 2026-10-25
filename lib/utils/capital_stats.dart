import '../models/capital_game.dart';
import 'capital_rules.dart';
import 'dartboard_geometry.dart';

/// The visits in [throws], one per round, oldest first.
///
/// A Capital player throws once per round, so a change of round is a change of
/// visit. The throws are expected to be one slot's own, in the order they were
/// thrown, which is what [DbHelper.getCapitalThrowsForGame] guarantees.
List<List<CapitalThrow>> capitalVisits(List<CapitalThrow> throws) {
  final visits = <List<CapitalThrow>>[];
  for (final dart in throws) {
    if (visits.isEmpty || visits.last.first.round != dart.round) {
      visits.add([dart]);
    } else {
      visits.last.add(dart);
    }
  }
  return visits;
}

/// The points [visit] is worth.
int capitalPointsOfVisit(List<CapitalThrow> visit) =>
    capitalVisitScore(visit.map((dart) => dart.hit).toList());

/// The numbers one Capital slot is read by, over its own darts.
///
/// Derived here and nowhere else, so the live info screen and anything later
/// that wants them agree. The contract outcomes come from
/// [capitalContractMet], the same function the provider scores by.
class CapitalStats {
  /// Darts thrown, misses included.
  final int darts;

  /// Visits completed, which is rounds played.
  final int visits;

  /// Contracts fulfilled, out of the fourteen the game proposes.
  final int contractsMet;

  /// Rounds whose contract was failed, each of which halved the capital.
  final int timesHalved;

  /// The most points a single visit was worth.
  final int bestVisitPoints;

  /// Mean points per visit, counting the opening round.
  final double pointsPerVisit;

  const CapitalStats({
    required this.darts,
    required this.visits,
    required this.contractsMet,
    required this.timesHalved,
    required this.bestVisitPoints,
    required this.pointsPerVisit,
  });

  /// Reads [throws], which are one slot's darts in the order they were thrown.
  factory CapitalStats.of(List<CapitalThrow> throws) {
    final visits = capitalVisits(throws);
    var met = 0;
    var halved = 0;
    var best = 0;
    var points = 0;

    for (final visit in visits) {
      final contract = CapitalContract.forRound(visit.first.round);
      final hits = visit.map((dart) => dart.hit).toList();
      final worth = capitalVisitScore(hits);
      points += worth;
      if (worth > best) best = worth;
      if (contract == CapitalContract.capital) continue;
      if (capitalContractMet(contract, hits)) {
        met++;
      } else {
        halved++;
      }
    }

    return CapitalStats(
      darts: throws.length,
      visits: visits.length,
      contractsMet: met,
      timesHalved: halved,
      bestVisitPoints: best,
      pointsPerVisit: visits.isEmpty ? 0 : points / visits.length,
    );
  }
}

/// One dart as the Capital screens label it, which is how every other target
/// mode labels one.
BoardHit capitalHitOf(CapitalThrow dart) => dart.hit;
