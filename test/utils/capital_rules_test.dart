import 'package:dartscore_app/utils/capital_rules.dart';
import 'package:dartscore_app/utils/dartboard_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// A single, a double and a triple of [field], and the two bull rings.
BoardHit single(int field) => (field: field, multiplier: 1);
BoardHit double_(int field) => (field: field, multiplier: 2);
BoardHit triple(int field) => (field: field, multiplier: 3);
const BoardHit innerBull = (field: 25, multiplier: 2);
const BoardHit outerBull = (field: 25, multiplier: 1);

void main() {
  group('the fifteen rounds', () {
    test('opens on the capital at round zero and ends on the center', () {
      expect(CapitalContract.rounds, 15);
      expect(CapitalContract.contractCount, 14);
      expect(CapitalContract.lastRound, 14);
      expect(CapitalContract.forRound(0), CapitalContract.capital);
      expect(CapitalContract.forRound(6), CapitalContract.side);
      expect(CapitalContract.forRound(12), CapitalContract.fiftySeven);
      expect(CapitalContract.forRound(14), CapitalContract.center);
    });

    test('numbers each contract with the round it is played in', () {
      for (var round = 0; round <= CapitalContract.lastRound; round++) {
        expect(CapitalContract.forRound(round).round, round);
      }
    });

    test('leaves the capital unnumbered among the contracts', () {
      // The capital is round 0 precisely because it is not a contract, so
      // every contract proper carries a number from one to fourteen.
      expect(CapitalContract.capital.round, 0);
      final contracts = CapitalContract.values
          .where((c) => c != CapitalContract.capital)
          .map((c) => c.round);
      expect(contracts, List.generate(14, (i) => i + 1));
    });

    test('names a sector only for the contracts that ask for one', () {
      expect(CapitalContract.twenty.sector, 20);
      expect(CapitalContract.fourteen.sector, 14);
      expect(CapitalContract.side.sector, isNull);
      expect(CapitalContract.capital.sector, isNull);
    });
  });

  group('the capital round', () {
    test('asks nothing of the darts', () {
      expect(capitalContractMet(CapitalContract.capital, [boardMiss, boardMiss, boardMiss]),
          isTrue);
    });

    test('sets the total to the darts rather than adding to it', () {
      expect(
        applyCapitalVisit(
          total: 999,
          contract: CapitalContract.capital,
          darts: [triple(20), single(20), double_(20)],
        ),
        60 + 20 + 40,
      );
    });
  });

  group('the sector contracts', () {
    test('take a dart in the sector whatever ring it landed in', () {
      for (final hit in [single(20), double_(20), triple(20)]) {
        expect(capitalContractMet(CapitalContract.twenty, [hit]), isTrue,
            reason: '$hit');
      }
    });

    test('reject a dart in another sector, and a miss', () {
      expect(capitalContractMet(CapitalContract.twenty, [single(19)]), isFalse);
      expect(capitalContractMet(CapitalContract.twenty, [boardMiss]), isFalse);
    });

    test('need only one of the three darts to land', () {
      expect(
        capitalContractMet(
            CapitalContract.fourteen, [boardMiss, single(14), boardMiss]),
        isTrue,
      );
    });

    test('covers every numbered contract the game proposes', () {
      const expected = {
        CapitalContract.twenty: 20,
        CapitalContract.nineteen: 19,
        CapitalContract.eighteen: 18,
        CapitalContract.seventeen: 17,
        CapitalContract.sixteen: 16,
        CapitalContract.fifteen: 15,
        CapitalContract.fourteen: 14,
      };
      expected.forEach((contract, sector) {
        expect(contract.sector, sector);
        expect(capitalContractMet(contract, [single(sector)]), isTrue);
      });
    });
  });

  group('the triple contract', () {
    test('takes any triple', () {
      expect(capitalContractMet(CapitalContract.anyTriple, [triple(7)]), isTrue);
    });

    test('rejects singles, doubles and both bull rings', () {
      expect(capitalContractMet(CapitalContract.anyTriple, [single(20)]), isFalse);
      expect(capitalContractMet(CapitalContract.anyTriple, [double_(20)]), isFalse);
      expect(capitalContractMet(CapitalContract.anyTriple, [innerBull]), isFalse);
      expect(capitalContractMet(CapitalContract.anyTriple, [outerBull]), isFalse);
    });
  });

  group('the double contract', () {
    test('takes any double', () {
      expect(capitalContractMet(CapitalContract.anyDouble, [double_(3)]), isTrue);
    });

    test('takes the inner bull, the way a checkout does', () {
      // FinishCalculator finishes a leg on the bull under the double out rule,
      // so the bull counts as a double here too rather than only as a center.
      expect(capitalContractMet(CapitalContract.anyDouble, [innerBull]), isTrue);
    });

    test('rejects the outer bull, singles and triples', () {
      expect(capitalContractMet(CapitalContract.anyDouble, [outerBull]), isFalse);
      expect(capitalContractMet(CapitalContract.anyDouble, [single(20)]), isFalse);
      expect(capitalContractMet(CapitalContract.anyDouble, [triple(20)]), isFalse);
    });
  });

  group('the side contract', () {
    test('takes the example the rules give', () {
      expect(
        capitalContractMet(
            CapitalContract.side, [single(16), single(7), single(19)]),
        isTrue,
      );
    });

    test('ignores which ring each dart landed in', () {
      expect(
        capitalContractMet(
            CapitalContract.side, [triple(16), double_(7), single(19)]),
        isTrue,
      );
    });

    test('lets the arc cross the top of the board', () {
      expect(
        capitalContractMet(
            CapitalContract.side, [single(12), single(5), single(20)]),
        isTrue,
      );
    });

    test('rejects three consecutive numbers that sit apart on the board', () {
      expect(
        capitalContractMet(
            CapitalContract.side, [single(20), single(19), single(18)]),
        isFalse,
      );
    });

    test('rejects the bull, which the rules exclude here', () {
      expect(
        capitalContractMet(
            CapitalContract.side, [single(20), single(1), innerBull]),
        isFalse,
      );
    });

    test('needs all three darts', () {
      expect(capitalContractMet(CapitalContract.side, [single(16), single(7)]),
          isFalse);
    });
  });

  group('the run contract', () {
    test('takes the example the rules give', () {
      expect(
        capitalContractMet(
            CapitalContract.run, [single(20), single(19), single(18)]),
        isTrue,
      );
    });

    test('ignores the order and the rings', () {
      expect(
        capitalContractMet(
            CapitalContract.run, [double_(18), triple(20), single(19)]),
        isTrue,
      );
    });

    test('does not wrap at the ends', () {
      expect(
        capitalContractMet(
            CapitalContract.run, [single(1), single(20), single(19)]),
        isFalse,
      );
      expect(
        capitalContractMet(
            CapitalContract.run, [single(19), single(20), single(1)]),
        isFalse,
      );
    });

    test('rejects a gap and a repeat', () {
      expect(
        capitalContractMet(
            CapitalContract.run, [single(20), single(19), single(17)]),
        isFalse,
      );
      expect(
        capitalContractMet(
            CapitalContract.run, [single(20), single(20), single(19)]),
        isFalse,
      );
    });

    test('rejects the bull and a miss, which are not numbered sectors', () {
      expect(
        capitalContractMet(CapitalContract.run, [single(1), single(2), innerBull]),
        isFalse,
      );
      expect(
        capitalContractMet(CapitalContract.run, [single(1), single(2), boardMiss]),
        isFalse,
      );
    });

    test('takes a run at either end of the numbers', () {
      expect(
        capitalContractMet(
            CapitalContract.run, [single(1), single(2), single(3)]),
        isTrue,
      );
      expect(
        capitalContractMet(
            CapitalContract.run, [single(18), single(19), single(20)]),
        isTrue,
      );
    });

    test('needs all three darts', () {
      expect(capitalContractMet(CapitalContract.run, [single(20), single(19)]),
          isFalse);
    });
  });

  group('the color contract', () {
    test('takes the example the rules give', () {
      // 20, 19, triple 20 reads black, white, red.
      expect(
        capitalContractMet(
            CapitalContract.colors, [single(20), single(19), triple(20)]),
        isTrue,
      );
    });

    test('takes the two bull rings as red and green', () {
      expect(
        capitalContractMet(
            CapitalContract.colors, [innerBull, outerBull, single(20)]),
        isTrue,
      );
    });

    test('rejects a repeated color', () {
      // 20 and 18 are both black singles, so this is black, black, red.
      expect(
        capitalContractMet(
            CapitalContract.colors, [single(20), single(18), triple(20)]),
        isFalse,
      );
    });

    test('rejects a miss, which has no color', () {
      expect(
        capitalContractMet(
            CapitalContract.colors, [single(20), single(19), boardMiss]),
        isFalse,
      );
    });

    test('needs all three darts', () {
      expect(
        capitalContractMet(CapitalContract.colors, [single(20), single(19)]),
        isFalse,
      );
    });
  });

  group('the 57 contract', () {
    test('takes the two dart example the rules give', () {
      // 19 plus double 19 is 19 + 38.
      expect(
        capitalContractMet(CapitalContract.fiftySeven, [single(19), double_(19)]),
        isTrue,
      );
    });

    test('takes a single dart that makes 57 on its own', () {
      expect(capitalContractMet(CapitalContract.fiftySeven, [triple(19)]), isTrue);
    });

    test('takes three darts that total 57', () {
      expect(
        capitalContractMet(
            CapitalContract.fiftySeven, [single(20), single(20), single(17)]),
        isTrue,
      );
    });

    test('rejects a total either side of 57', () {
      expect(
        capitalContractMet(
            CapitalContract.fiftySeven, [single(20), single(20), single(16)]),
        isFalse,
      );
      expect(
        capitalContractMet(
            CapitalContract.fiftySeven, [single(20), single(20), single(18)]),
        isFalse,
      );
    });

    test('fails when a third dart overshoots a visit that already made 57', () {
      expect(
        capitalContractMet(
            CapitalContract.fiftySeven, [single(19), double_(19), single(1)]),
        isFalse,
      );
    });
  });

  group('the center contract', () {
    test('takes either bull ring', () {
      expect(capitalContractMet(CapitalContract.center, [innerBull]), isTrue);
      expect(capitalContractMet(CapitalContract.center, [outerBull]), isTrue);
    });

    test('rejects everything else', () {
      expect(capitalContractMet(CapitalContract.center, [triple(20)]), isFalse);
      expect(capitalContractMet(CapitalContract.center, [boardMiss]), isFalse);
    });
  });

  group('halving a total', () {
    test('rounds up to the next whole number', () {
      expect(halvedRoundingUp(57), 29);
      expect(halvedRoundingUp(1), 1);
      expect(halvedRoundingUp(3), 2);
    });

    test('leaves an even total exactly halved', () {
      expect(halvedRoundingUp(56), 28);
      expect(halvedRoundingUp(0), 0);
    });
  });

  group('the running total', () {
    test('adds the visit when the contract is met', () {
      expect(
        applyCapitalVisit(
          total: 100,
          contract: CapitalContract.twenty,
          darts: [triple(20), single(5), boardMiss],
        ),
        165,
      );
    });

    test('halves the total and adds nothing when the contract fails', () {
      expect(
        applyCapitalVisit(
          total: 101,
          contract: CapitalContract.twenty,
          darts: [single(19), single(5), boardMiss],
        ),
        51,
      );
    });

    test('scores a visit that meets the contract with a miss among the darts', () {
      expect(
        applyCapitalVisit(
          total: 0,
          contract: CapitalContract.center,
          darts: [innerBull, boardMiss, boardMiss],
        ),
        50,
      );
    });

    test('plays a whole game through to a total', () {
      // Capital of 60, then meet the 20 for 60 more, then fail the triple.
      var total = applyCapitalVisit(
        total: 0,
        contract: CapitalContract.capital,
        darts: [single(20), single(20), single(20)],
      );
      expect(total, 60);

      total = applyCapitalVisit(
        total: total,
        contract: CapitalContract.twenty,
        darts: [single(20), single(20), single(20)],
      );
      expect(total, 120);

      total = applyCapitalVisit(
        total: total,
        contract: CapitalContract.anyTriple,
        darts: [single(20), single(20), single(20)],
      );
      expect(total, 60);
    });
  });
}
