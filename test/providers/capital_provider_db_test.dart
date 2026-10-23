import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/capital_game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/capital_provider.dart';
import 'package:dartscore_app/utils/capital_rules.dart';
import 'package:dartscore_app/utils/dartboard_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_db.dart';

BoardHit single(int field) => (field: field, multiplier: 1);
BoardHit double_(int field) => (field: field, multiplier: 2);
BoardHit triple(int field) => (field: field, multiplier: 3);

void main() {
  group('CapitalProvider against a real database', () {
    useInMemoryDatabase();

    late CapitalProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = CapitalProvider();
      players = await insertPlayers(['A', 'B']);
    });

    Future<CapitalGame> startedGame() async {
      final game = CapitalGame(
        legs: 1,
        sets: 1,
        createdAt: DateTime.now(),
        playerIds: players.map((p) => p.id!).toList(),
      );
      final id = await DbHelper.instance.insertCapitalGame(game);
      final stored = CapitalGame(
        id: id,
        legs: 1,
        sets: 1,
        createdAt: game.createdAt,
        playerIds: game.playerIds,
      );
      await provider.startGame(stored, players);
      return stored;
    }

    /// Throws a full visit of three darts for whoever is on turn.
    Future<void> visit(List<BoardHit> darts) async {
      for (final dart in darts) {
        await provider.recordDart(dart);
      }
    }

    /// Throws three misses, which fails every contract but the capital.
    Future<void> missVisit() => visit([boardMiss, boardMiss, boardMiss]);

    test('opens on round zero, the capital, with nobody scoring yet', () async {
      await startedGame();
      expect(provider.currentRound, 0);
      expect(provider.contract, CapitalContract.capital);
      expect(provider.playerStates.map((s) => s.total), [0, 0]);
    });

    test('sets the capital to whatever the first visit totalled', () async {
      await startedGame();
      await visit([triple(20), single(20), single(5)]);
      expect(provider.playerStates.first.total, 85);
      // The turn has moved to the second player, still on the capital.
      expect(provider.currentPlayerIndex, 1);
      expect(provider.currentRound, 0);
    });

    test('moves into the contracts after the last slot has its capital', () async {
      await startedGame();
      await visit([single(20), single(20), single(20)]);
      await visit([single(20), single(20), single(20)]);
      expect(provider.currentRound, 1);
      expect(provider.contract, CapitalContract.twenty);
      expect(provider.currentPlayerIndex, 0);
    });

    test('adds the visit when the contract is met', () async {
      await startedGame();
      await visit([single(20), single(20), single(20)]); // A capital 60
      await visit([single(1), single(1), single(1)]);    // B capital 3

      await visit([triple(20), single(5), boardMiss]);   // A meets the 20
      expect(provider.playerStates.first.total, 60 + 65);
    });

    test('halves the total rounding up when the contract fails', () async {
      await startedGame();
      await visit([single(20), single(20), single(17)]); // A capital 57
      await visit([single(1), single(1), single(1)]);    // B capital 3

      await missVisit();                                  // A fails the 20
      expect(provider.playerStates.first.total, 29);
      expect(provider.playerStates.first.lastRoundMet, isFalse);
    });

    group('the 57 round, which closes itself', () {
      /// Fails rounds one through eleven for both players, which is what gets
      /// the game to round twelve, where the 57 contract is played.
      Future<void> reachRound12() async {
        await visit([single(20), single(20), single(20)]); // A capital 60
        await visit([single(1), single(1), single(1)]);    // B capital 3
        for (var round = 1; round <= 11; round++) {
          await missVisit();
          await missVisit();
        }
      }

      test('ends the visit the moment the total is exactly 57', () async {
        await startedGame();
        await reachRound12();
        expect(provider.contract, CapitalContract.fiftySeven);

        final before = provider.playerStates.first.total;
        await provider.recordDart(triple(19));

        // One dart, and the visit is already over: the turn has moved on and
        // no third dart can break the total.
        expect(provider.dartsInVisit, 0);
        expect(provider.currentPlayerIndex, 1);
        expect(provider.playerStates.first.total, before + 57);
      });

      test('closes on two darts as readily as on one', () async {
        await startedGame();
        await reachRound12();
        final before = provider.playerStates.first.total;

        await provider.recordDart(single(19));
        expect(provider.dartsInVisit, 1);
        await provider.recordDart(double_(19));
        expect(provider.dartsInVisit, 0);
        expect(provider.playerStates.first.total, before + 57);
      });

      test('keeps the visit open while the total is short of 57', () async {
        await startedGame();
        await reachRound12();
        await provider.recordDart(single(20));
        expect(provider.dartsInVisit, 1);
        expect(provider.contractMet, isFalse);
      });

      test('replays to the same place it closed at', () async {
        final game = await startedGame();
        await reachRound12();
        final before = provider.playerStates.first.total;
        await provider.recordDart(triple(19));

        final resumed = CapitalProvider();
        await resumed.resumeGame(game, players);

        expect(resumed.currentPlayerIndex, 1);
        expect(resumed.dartsInVisit, 0);
        expect(resumed.playerStates.first.total, before + 57);
      });
    });

    test('never closes a visit early on any other round', () async {
      await startedGame();
      await visit([single(20), single(20), single(20)]);
      await visit([single(20), single(20), single(20)]);
      // Round two wants a 20. Meeting it does not end the visit, because two
      // more darts can only add points.
      await provider.recordDart(single(20));
      expect(provider.contractMet, isTrue);
      expect(provider.dartsInVisit, 1);
      expect(provider.currentPlayerIndex, 0);
    });

    test('replays an unfinished visit back onto the board', () async {
      final game = await startedGame();
      await provider.recordDart(single(20));
      await provider.recordDart(single(5));

      final resumed = CapitalProvider();
      await resumed.resumeGame(game, players);

      expect(resumed.currentPlayerIndex, 0);
      expect(resumed.dartsInVisit, 2);
      expect(resumed.contract, CapitalContract.capital);
    });

    group('undo', () {
      test('takes back a dart inside the current visit', () async {
        await startedGame();
        await provider.recordDart(single(20));
        await provider.recordDart(single(5));
        await provider.undoLastDart();

        expect(provider.dartsInVisit, 1);
        expect(provider.currentPlayerIndex, 0);
      });

      test('reaches back across a round boundary and undoes the halving',
          () async {
        await startedGame();
        await visit([single(20), single(20), single(17)]); // A capital 57
        await visit([single(1), single(1), single(1)]);    // B capital 3
        await missVisit();                                  // A halved to 29
        expect(provider.playerStates.first.total, 29);

        await provider.undoLastDart();

        // The visit is open again with two darts, and A has their 57 back.
        expect(provider.currentPlayerIndex, 0);
        expect(provider.currentRound, 1);
        expect(provider.dartsInVisit, 2);
        expect(provider.playerStates.first.total, 57);
      });

      test('is refused when nothing has been thrown', () async {
        await startedGame();
        expect(provider.canUndo, isFalse);
      });
    });

    test('runs fifteen rounds and then closes on the higher capital', () async {
      await startedGame();
      // A scores a 20 every visit, B misses everything, so A can only climb
      // and B can only halve toward nothing.
      for (var round = 0; round <= CapitalContract.lastRound; round++) {
        await visit([single(20), single(20), single(20)]);
        await missVisit();
      }

      expect(provider.gameOver, isTrue);
      expect(provider.winnerId, players.first.id);
      expect(provider.playerStates.first.total, greaterThan(0));
      expect(provider.playerStates.last.total, 0);

      final stored = await DbHelper.instance.getCapitalGames();
      expect(stored.single.finishedAt, isNotNull);
    });

    test('leaves no winner when the top capital is shared', () async {
      await startedGame();
      for (var round = 0; round <= CapitalContract.lastRound; round++) {
        await missVisit();
        await missVisit();
      }
      expect(provider.gameOver, isTrue);
      expect(provider.winnerId, isNull);
    });

    test('refuses a dart once the game is over', () async {
      await startedGame();
      for (var round = 0; round <= CapitalContract.lastRound; round++) {
        await missVisit();
        await missVisit();
      }
      await provider.recordDart(triple(20));
      expect(provider.playerStates.first.total, 0);
    });
  });
}
