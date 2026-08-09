import '../models/dart_throw.dart';

/// Returns the 1-based finishing position of each id that checked out in
/// [leg]/[set], keyed by id and ordered by the checkout throw's timestamp.
/// Ids without a checkout throw in this leg/set are omitted.
Map<int, int> legPlacements(
  Map<int, List<DartThrow>> throwsById,
  int leg,
  int set,
) {
  final checkouts = <int, DateTime>{};
  for (final entry in throwsById.entries) {
    final checkout = entry.value.where((t) =>
        t.leg == leg && t.set == set && !t.bust && t.remainingAfter == 0);
    if (checkout.isNotEmpty) {
      checkouts[entry.key] = checkout.first.thrownAt;
    }
  }
  final ordered = checkouts.keys.toList()
    ..sort((a, b) => checkouts[a]!.compareTo(checkouts[b]!));
  return {
    for (var i = 0; i < ordered.length; i++) ordered[i]: i + 1,
  };
}

/// [legPlacements] completed by the rule that ends a leg as soon as the
/// second-to-last participant checks out: the one participant left then takes
/// last place without a checkout throw of its own, so it has no entry to read
/// back from the throws.
///
/// While more than one participant is still playing, the leg is unfinished and
/// the raw placements are returned unchanged.
Map<int, int> completedLegPlacements(
  Map<int, List<DartThrow>> throwsById,
  int leg,
  int set,
) {
  final placements = legPlacements(throwsById, leg, set);
  final ids = throwsById.keys.toList();
  if (ids.isNotEmpty && placements.length == ids.length - 1) {
    final missing = ids.firstWhere((id) => !placements.containsKey(id));
    return {...placements, missing: ids.length};
  }
  return placements;
}

/// Per-id legs won (1st place finishes) and the cumulative sum of per-leg
/// finishing positions across legs `1..upToLeg` of [set], used to rank
/// players/teams at the end of a placement-mode game.
({Map<int, int> legsWon, Map<int, int> placementSum}) placementRanking(
  Map<int, List<DartThrow>> throwsById,
  int upToLeg,
  int set,
) {
  final legsWon = <int, int>{for (final id in throwsById.keys) id: 0};
  final placementSum = <int, int>{for (final id in throwsById.keys) id: 0};

  for (var leg = 1; leg <= upToLeg; leg++) {
    final placements = completedLegPlacements(throwsById, leg, set);
    for (final entry in placements.entries) {
      placementSum[entry.key] = (placementSum[entry.key] ?? 0) + entry.value;
      if (entry.value == 1) {
        legsWon[entry.key] = (legsWon[entry.key] ?? 0) + 1;
      }
    }
  }

  return (legsWon: legsWon, placementSum: placementSum);
}

/// Points awarded for finishing in [placement] among [participantCount]
/// participants in a single leg: last place earns 1 point, each better
/// placement earns one more (1st place earns [participantCount]), and the
/// leg winner (placement == 1) earns an additional +1 bonus point.
int placementPoints(int placement, int participantCount) {
  final base = participantCount - placement + 1;
  return placement == 1 ? base + 1 : base;
}

/// Per-leg finishing positions for every leg `1..upToLeg`, as
/// `result[leg][id] = placement`, used to render a per-leg placement table.
Map<int, Map<int, int>> legPlacementsTable(
  Map<int, List<DartThrow>> throwsById,
  int upToLeg,
  int set,
) {
  return {
    for (var leg = 1; leg <= upToLeg; leg++)
      leg: completedLegPlacements(throwsById, leg, set),
  };
}

/// Cumulative [placementPoints] across legs `1..upToLeg`, keyed by id.
Map<int, int> placementPointsTotal(
  Map<int, List<DartThrow>> throwsById,
  int upToLeg,
  int set,
) {
  final totals = <int, int>{for (final id in throwsById.keys) id: 0};
  final participantCount = throwsById.length;
  for (var leg = 1; leg <= upToLeg; leg++) {
    final placements = completedLegPlacements(throwsById, leg, set);
    for (final entry in placements.entries) {
      totals[entry.key] =
          (totals[entry.key] ?? 0) + placementPoints(entry.value, participantCount);
    }
  }
  return totals;
}
