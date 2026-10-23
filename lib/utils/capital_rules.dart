import 'dartboard_geometry.dart';

/// The fifteen rounds of a Capital game, in the order they are played.
///
/// Round 0 builds the capital and asks nothing of the darts, which is why it
/// carries no number of its own: the fourteen contracts proper are rounds 1 to
/// 14. Each must be fulfilled inside one visit, and fulfilling it adds the
/// visit to the total while failing it halves the total.
enum CapitalContract {
  capital(0),
  twenty(1, sector: 20),
  anyTriple(2),
  nineteen(3, sector: 19),
  anyDouble(4),
  eighteen(5, sector: 18),
  side(6),
  seventeen(7, sector: 17),
  run(8),
  sixteen(9, sector: 16),
  colors(10),
  fifteen(11, sector: 15),
  fiftySeven(12),
  fourteen(13, sector: 14),
  center(14);

  const CapitalContract(this.round, {this.sector});

  /// The round this contract is played in. The capital opens the game as
  /// round 0, so a contract's own number is 1 to 14.
  final int round;

  /// The sector a dart has to land in, for the contracts that name one, and
  /// null for the contracts that ask for a shape, a total or a color instead.
  final int? sector;

  /// The contract played in [round], the capital being round 0.
  static CapitalContract forRound(int round) => values[round];

  /// How many rounds a Capital game lasts, the opening capital included.
  static int get rounds => values.length;

  /// The number of the last round, which [center] is played in.
  static int get lastRound => values.length - 1;

  /// How many contracts are proposed after the capital.
  static int get contractCount => values.length - 1;
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
/// [CapitalContract.run] and [CapitalContract.colors]) need all three darts and
/// answer false for a shorter visit, while [CapitalContract.fiftySeven] can be
/// met with fewer.
///
/// The inner bull counts as a double, which is the convention the rest of this
/// app already follows: `FinishCalculator` finishes a leg on it under the
/// double out rule. No triple bull exists, so only the numbered sectors can
/// satisfy [CapitalContract.anyTriple].
bool capitalContractMet(CapitalContract contract, List<BoardHit> darts) {
  if (contract.sector case final sector?) {
    return darts.any((dart) => dart.field == sector);
  }
  return switch (contract) {
    CapitalContract.capital    => true,
    CapitalContract.anyTriple  => darts.any((dart) => dart.multiplier == 3),
    CapitalContract.anyDouble  => darts.any((dart) => dart.multiplier == 2),
    CapitalContract.center     => darts.any((dart) => dart.field == 25),
    CapitalContract.fiftySeven => capitalVisitScore(darts) == 57,
    CapitalContract.side       => _isSide(darts),
    CapitalContract.run        => _isRun(darts),
    CapitalContract.colors     => _isColors(darts),
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

/// Whether another dart in this visit could only make things worse.
///
/// True for [CapitalContract.fiftySeven] once the total is exactly 57, where
/// any further score breaks it. Every other contract either gains points from
/// another dart or still needs one, so stopping early never helps. The play
/// screen uses this to offer ending the visit, and the bot to stop on its own.
bool furtherDartsCanOnlyHurt(CapitalContract contract, List<BoardHit> darts) =>
    contract == CapitalContract.fiftySeven &&
    capitalContractMet(contract, darts);

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
bool _isColors(List<BoardHit> darts) {
  if (darts.length != 3) return false;
  final colors = <BoardColor>{};
  for (final dart in darts) {
    final color = colorOf(dart);
    if (color == null) return false;
    colors.add(color);
  }
  return colors.length == 3;
}
