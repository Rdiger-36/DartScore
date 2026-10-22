import 'dartboard_geometry.dart';

/// The fifteen rounds of a Capital game, in the order they are played.
///
/// Round 1 builds the capital and asks nothing of the darts. Every later round
/// proposes a contract that must be fulfilled inside one visit: fulfilling it
/// adds the visit to the total, failing it halves the total.
enum CapitalContract {
  capital(1),
  twenty(2, sector: 20),
  anyTreble(3),
  nineteen(4, sector: 19),
  anyDouble(5),
  eighteen(6, sector: 18),
  side(7),
  seventeen(8, sector: 17),
  run(9),
  sixteen(10, sector: 16),
  color(11),
  fifteen(12, sector: 15),
  fiftySeven(13),
  fourteen(14, sector: 14),
  center(15);

  const CapitalContract(this.round, {this.sector});

  /// The round this contract is played in, counted from one.
  final int round;

  /// The sector a dart has to land in, for the contracts that name one, and
  /// null for the contracts that ask for a shape, a total or a color instead.
  final int? sector;

  /// The contract played in [round], counted from one.
  static CapitalContract forRound(int round) => values[round - 1];

  /// How many rounds a Capital game lasts.
  static int get rounds => values.length;
}

/// A total halved and rounded up to the next whole number.
///
/// This is the penalty for a failed contract. Half-It in the same rule book
/// halves the same way, so the two modes share this rather than each rounding
/// to taste.
int halvedRoundingUp(int total) => (total + 1) ~/ 2;

/// The points [darts] are worth, which is what every dart scores on the board.
int capitalVisitScore(List<BoardHit> darts) =>
    darts.fold(0, (sum, dart) => sum + scoreOf(dart));

/// Whether [darts] fulfils [contract].
///
/// [darts] is the visit as thrown, so it holds one, two or three entries: a
/// player who has already met the contract may stop early. The contracts that
/// ask for a shape across the visit ([CapitalContract.side],
/// [CapitalContract.run] and [CapitalContract.color]) need all three darts and
/// answer false for a shorter visit, while [CapitalContract.fiftySeven] can be
/// met with fewer.
///
/// The inner bull counts as a double, which is the convention the rest of this
/// app already follows: `FinishCalculator` finishes a leg on it under the
/// double out rule. No treble bull exists, so only the numbered sectors can
/// satisfy [CapitalContract.anyTreble].
bool capitalContractMet(CapitalContract contract, List<BoardHit> darts) {
  if (contract.sector case final sector?) {
    return darts.any((dart) => dart.field == sector);
  }
  return switch (contract) {
    CapitalContract.capital    => true,
    CapitalContract.anyTreble  => darts.any((dart) => dart.multiplier == 3),
    CapitalContract.anyDouble  => darts.any((dart) => dart.multiplier == 2),
    CapitalContract.center     => darts.any((dart) => dart.field == 25),
    CapitalContract.fiftySeven => capitalVisitScore(darts) == 57,
    CapitalContract.side       => _isSide(darts),
    CapitalContract.run        => _isRun(darts),
    CapitalContract.color      => _isColor(darts),
    // Every sector contract was answered above.
    _ => false,
  };
}

/// The total after a visit, which is the one place the scoring rule lives.
///
/// Round 1 sets the capital to whatever the darts totalled. A later round adds
/// the visit when the contract is met and otherwise halves the total, rounding
/// up, without adding anything.
int applyCapitalVisit({
  required int total,
  required CapitalContract contract,
  required List<BoardHit> darts,
}) {
  if (contract == CapitalContract.capital) return capitalVisitScore(darts);
  return capitalContractMet(contract, darts)
      ? total + capitalVisitScore(darts)
      : halvedRoundingUp(total);
}

/// Three darts in three sectors that touch each other on the board.
///
/// The bull is not a sector and the rules exclude it here explicitly, which
/// [areAdjacentSectors] already enforces along with rejecting a repeat.
bool _isSide(List<BoardHit> darts) =>
    darts.length == 3 &&
    areAdjacentSectors(darts.map((dart) => dart.field).toList());

/// Three darts in three consecutive numbers, which does not wrap.
///
/// This is arithmetic over the numbers and has nothing to do with where the
/// sectors sit on the board, so 20, 19 and 18 is a run while 1, 20 and 19 is
/// not. The bull and a miss are not numbered sectors and disqualify the visit.
bool _isRun(List<BoardHit> darts) {
  if (darts.length != 3) return false;
  final fields = darts.map((dart) => dart.field).toList()..sort();
  if (fields.first < 1 || fields.last > 20) return false;
  return fields[1] == fields[0] + 1 && fields[2] == fields[1] + 1;
}

/// Three darts in three different colors of paint.
///
/// A miss has no color and fails the contract outright.
bool _isColor(List<BoardHit> darts) {
  if (darts.length != 3) return false;
  final colors = <BoardColor>{};
  for (final dart in darts) {
    final color = colorOf(dart);
    if (color == null) return false;
    colors.add(color);
  }
  return colors.length == 3;
}
