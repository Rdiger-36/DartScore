import 'package:dartscore_app/l10n/app_localizations.dart';
import 'package:dartscore_app/utils/capital_rules.dart';
import 'package:dartscore_app/utils/dartboard_geometry.dart';
import 'package:dartscore_app/utils/game_labels.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

BoardHit single(int field) => (field: field, multiplier: 1);
BoardHit triple(int field) => (field: field, multiplier: 3);
const BoardHit innerBull = (field: 25, multiplier: 2);

void main() {
  final l = AppLocalizations(const Locale('en'));

  String line(CapitalContract contract, List<BoardHit> darts) =>
      capitalProgressLine(l, contract, darts);

  group('contract names', () {
    test('names the numbered contracts by their sector', () {
      expect(capitalContractName(l, CapitalContract.twenty), '20');
      expect(capitalContractName(l, CapitalContract.fourteen), '14');
    });

    test('names the rest in words, and the 57 as a numeral', () {
      expect(capitalContractName(l, CapitalContract.side), 'Side by Side');
      expect(capitalContractName(l, CapitalContract.colors), 'Colors');
      expect(capitalContractName(l, CapitalContract.anyTriple), 'Triple');
      expect(capitalContractName(l, CapitalContract.fiftySeven), '57');
    });

    test('gives every numbered contract the same reminder', () {
      for (final contract in CapitalContract.values) {
        if (contract.sector == null) continue;
        expect(capitalContractReminder(l, contract), 'Any ring counts',
            reason: '$contract');
      }
    });
  });

  group('the band before any dart lands', () {
    test('shows the standing reminder', () {
      expect(line(CapitalContract.side, []), '3 adjacent segments');
      expect(line(CapitalContract.run, []), '3 consecutive numbers');
      expect(line(CapitalContract.anyDouble, []), 'Any double. The bull counts');
    });
  });

  group('run', () {
    test('names both missing numbers when the run is determined', () {
      // Only 18-19-20 contains the 20, because 21 does not exist.
      expect(line(CapitalContract.run, [single(20)]), 'Need 18 and 19');
    });

    test('lists every run when more than one is open', () {
      expect(line(CapitalContract.run, [single(10)]),
          'Make 8-9-10, 9-10-11 or 10-11-12');
    });

    test('names the remaining numbers once two darts are down', () {
      expect(line(CapitalContract.run, [single(10), single(11)]),
          'Need 9 or 12');
      expect(line(CapitalContract.run, [single(20), single(19)]), 'Need 18');
    });

    test('says so when no run is left', () {
      expect(line(CapitalContract.run, [single(20), innerBull]),
          'No run possible');
    });
  });

  group('side by side', () {
    test('lists all three arcs after one dart', () {
      expect(line(CapitalContract.side, [single(20)]),
          'Make 20-1-18, 12-5-20 or 5-20-1');
    });

    test('names both ends when two darts are neighbors', () {
      expect(line(CapitalContract.side, [single(20), single(1)]),
          'Need 18 or 5');
    });

    test('names the one gap when two darts leave one', () {
      expect(line(CapitalContract.side, [single(20), single(18)]), 'Need 1');
    });

    test('says so when no arc is left', () {
      expect(line(CapitalContract.side, [single(20), innerBull]),
          'No arc possible');
    });
  });

  group('colors', () {
    test('counts the colors still owed, not the darts', () {
      // "other" rather than "more": they have to differ from what is down.
      expect(line(CapitalContract.colors, [single(20)]),
          'Black. Need 2 other colors');
    });

    test('names the two that would do once only one is owed', () {
      expect(line(CapitalContract.colors, [single(20), triple(20)]),
          'Black, Red. Need White or Green');
    });
  });

  group('57', () {
    test('counts down the points still needed', () {
      expect(line(CapitalContract.fiftySeven, [single(19)]), 'Need 38 more');
    });

    test('falls back to the reminder once the visit has gone past', () {
      expect(line(CapitalContract.fiftySeven, [triple(20)]), 'Exactly 57');
    });
  });
}
