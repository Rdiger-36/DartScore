import 'capital_rules.dart';
import 'dartboard_geometry.dart';

/// The treble twenty, which is where a bot aims when nothing else is asked of
/// the dart and points are all that is left to gain.
const BoardHit _maxPoints = (field: 20, multiplier: 3);

/// Where a bot aims its next dart in a Capital visit.
///
/// Unlike the other three modes, this cannot be decided from the slot state
/// alone: on [CapitalContract.run], [CapitalContract.side] and
/// [CapitalContract.color] the right target depends on where the earlier darts
/// of the same visit landed, so [dartsSoFar] is part of the question.
///
/// The aim is a sound target rather than an optimal one. A bot's skill is the
/// scatter its tier carries in `BotThrower`, not the cleverness of this
/// choice, so the strategy stays readable.
BoardHit capitalTarget({
  required CapitalContract contract,
  required List<BoardHit> dartsSoFar,
}) {
  // The 57 contract is the one where a met contract still constrains the aim,
  // so it is answered before the general "already met, go for points" case.
  if (contract == CapitalContract.fiftySeven) return _aimFor57(dartsSoFar);

  if (capitalContractMet(contract, dartsSoFar)) return _maxPoints;

  if (contract.sector case final sector?) {
    return (field: sector, multiplier: 3);
  }

  return switch (contract) {
    CapitalContract.capital   => _maxPoints,
    CapitalContract.anyTreble => _maxPoints,
    CapitalContract.anyDouble => (field: 20, multiplier: 2),
    CapitalContract.center    => (field: 25, multiplier: 2),
    CapitalContract.side      => _aimForSide(dartsSoFar),
    CapitalContract.run       => _aimForRun(dartsSoFar),
    CapitalContract.color     => _aimForColor(dartsSoFar),
    _                         => _maxPoints,
  };
}

/// Continues an arc of sectors that touch each other.
///
/// The first dart opens the arc on the twenty. Later darts extend it from
/// whichever end still can, and a visit whose darts already cannot form an arc
/// plays for points instead.
BoardHit _aimForSide(List<BoardHit> dartsSoFar) {
  final order = dartboardSegmentOrder;
  final indices = <int>[];
  for (final dart in dartsSoFar) {
    final index = order.indexOf(dart.field);
    if (index < 0) return _maxPoints;
    indices.add(index);
  }
  if (indices.isEmpty) return _maxPoints;

  // Both ends of the arc built so far, as positions on the ring.
  for (final step in [1, -1]) {
    final candidates = indices
        .map((index) => (index + step) % order.length)
        .where((index) => !indices.contains(index));
    for (final candidate in candidates) {
      final extended = [...indices, candidate].map((i) => order[i]).toList();
      if (areAdjacentSectors(extended)) {
        return (field: order[candidate], multiplier: 3);
      }
    }
  }
  return _maxPoints;
}

/// Continues a run of consecutive numbers, which does not wrap.
BoardHit _aimForRun(List<BoardHit> dartsSoFar) {
  final fields = dartsSoFar.map((dart) => dart.field).toList()..sort();
  if (fields.isEmpty) return _maxPoints;
  if (fields.any((field) => field < 1 || field > 20)) return _maxPoints;

  for (final candidate in [fields.first - 1, fields.last + 1, fields.first + 1]) {
    if (candidate < 1 || candidate > 20 || fields.contains(candidate)) continue;
    final extended = [...fields, candidate]..sort();
    if (_isConsecutive(extended)) return (field: candidate, multiplier: 3);
  }
  return _maxPoints;
}

/// Whether [sorted] runs up one at a time with no repeat.
bool _isConsecutive(List<int> sorted) {
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] != sorted[i - 1] + 1) return false;
  }
  return true;
}

/// Aims at a color the visit has not used yet, taking the highest scoring
/// target of that color.
///
/// The twenty carries black singles and red multiples, the nineteen white and
/// green, so those two sectors between them offer all four colors.
BoardHit _aimForColor(List<BoardHit> dartsSoFar) {
  final used = dartsSoFar.map(colorOf).whereType<BoardColor>().toSet();
  const byValue = <BoardHit>[
    (field: 20, multiplier: 3), // red, 60
    (field: 19, multiplier: 3), // green, 57
    (field: 20, multiplier: 1), // black, 20
    (field: 19, multiplier: 1), // white, 19
  ];
  for (final candidate in byValue) {
    if (!used.contains(colorOf(candidate))) return candidate;
  }
  return _maxPoints;
}

/// Works toward a visit totalling exactly 57.
///
/// A dart that lands the total exactly is taken first. Otherwise the bot looks
/// for one that leaves a remainder it could finish with the next dart, and
/// failing both it plays the treble twenty to cut the remainder down.
BoardHit _aimFor57(List<BoardHit> dartsSoFar) {
  final remaining = 57 - capitalVisitScore(dartsSoFar);
  if (remaining <= 0) return _maxPoints;

  if (_exactHitFor(remaining) case final hit?) return hit;

  if (dartsSoFar.length < 2) {
    for (final candidate in _allHits) {
      final left = remaining - scoreOf(candidate);
      if (left > 0 && _exactHitFor(left) != null) return candidate;
    }
  }
  return _maxPoints;
}

/// A single dart worth exactly [points], or null when no ring scores it.
///
/// Trebles are tried first so the bot aims at the smaller, higher scoring ring
/// only when it has to.
BoardHit? _exactHitFor(int points) {
  for (final hit in _allHits) {
    if (scoreOf(hit) == points) return hit;
  }
  return null;
}

/// Every target a dart can be aimed at, highest scoring first.
final List<BoardHit> _allHits = () {
  final hits = <BoardHit>[
    for (final field in dartboardSegmentOrder) ...[
      (field: field, multiplier: 3),
      (field: field, multiplier: 2),
      (field: field, multiplier: 1),
    ],
    (field: 25, multiplier: 2),
    (field: 25, multiplier: 1),
  ];
  hits.sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
  return List<BoardHit>.unmodifiable(hits);
}();
