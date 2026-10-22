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
BoardHit treble(int field) => (field: field, multiplier: 3);

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

    test('opens on round one, the capital, with nobody scoring yet', () async {
      await startedGame();
      expect(provider.currentRound, 1);
      expect(provider.contract, CapitalContract.capital);
      expect(provider.playerStates.map((s) => s.total), [0, 0]);
    });

    test('sets the capital to whatever the first visit totalled', () async {
      await startedGame();
      await visit([treble(20), single(20), single(5)]);
      expect(provider.playerStates.first.total, 85);
      // The turn has moved to the second player, still in round one.
      expect(provider.currentPlayerIndex, 1);
      expect(provider.currentRound, 1);
    });

    test('moves into the contracts after the last slot has its capital', () async {
      await startedGame();
      await visit([single(20), single(20), single(20)]);
      await visit([single(20), single(20), single(20)]);
      expect(provider.currentRound, 2);
      expect(provider.contract, CapitalContract.twenty);
      expect(provider.currentPlayerIndex, 0);
    });

    test('adds the visit when the contract is met', () async {
      await startedGame();
      await visit([single(20), single(20), single(20)]); // A capital 60
      await visit([single(1), single(1), single(1)]);    // B capital 3

      await visit([treble(20), single(5), boardMiss]);   // A meets the 20
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

    group('ending a visit early', () {
      test('is refused before any dart is thrown', () async {
        await startedGame();
        expect(provider.canEndVisitEarly, isFalse);
      });

      test('settles the visit and moves the turn on', () async {
        await startedGame();
        await provider.recordDart(single(20));
        expect(provider.canEndVisitEarly, isTrue);
        await provider.endVisitEarly();

        expect(provider.playerStates.first.total, 20);
        expect(provider.currentPlayerIndex, 1);
        expect(provider.dartsInVisit, 0);
      });

      test('marks the dart that closed the visit', () async {
        final game = await startedGame();
        await provider.recordDart(single(20));
        await provider.endVisitEarly();

        final darts =
            await DbHelper.instance.getCapitalThrowsForGame(game.id!);
        expect(darts, hasLength(1));
        expect(darts.single.endsVisit, isTrue);
      });

      test('survives a resume, so the stopped dart is not handed back', () async {
        // The whole reason the closing dart is marked: two darts followed by
        // nothing look identical whether the player stopped or the app died.
        final game = await startedGame();
        await visit([single(20), single(20), single(20)]); // A capital 60
        await visit([single(1), single(1), single(1)]);    // B capital 3
        await provider.recordDart(single(20));             // A meets the 20
        await provider.endVisitEarly();

        final resumed = CapitalProvider();
        await resumed.resumeGame(game, players);

        expect(resumed.currentPlayerIndex, 1);
        expect(resumed.dartsInVisit, 0);
        expect(resumed.playerStates.first.total, 80);
      });

      test('lets the 57 round stop on the dart that made it', () async {
        await startedGame();
        await visit([single(20), single(20), single(20)]); // A capital 60
        await visit([single(1), single(1), single(1)]);    // B capital 3
        // Rounds two through twelve are failed by both, which is what gets the
        // game to the round the 57 contract is actually played in.
        for (var round = 2; round <= 12; round++) {
          await missVisit();
          await missVisit();
        }
        expect(provider.currentRound, 13);
        expect(provider.contract, CapitalContract.fiftySeven);

        final before = provider.playerStates.first.total;
        await provider.recordDart(treble(19));
        expect(provider.contractMet, isTrue);
        expect(provider.shouldStopNow, isTrue);

        await provider.endVisitEarly();
        expect(provider.playerStates.first.total, before + 57);
      });

      test('a visit cut short still fails a contract it did not meet', () async {
        await startedGame();
        await visit([single(20), single(20), single(20)]);
        await visit([single(20), single(20), single(20)]);
        // Round two wants a 20. One dart on the 19 and then stop.
        await provider.recordDart(single(19));
        await provider.endVisitEarly();
        expect(provider.playerStates.first.total, 30);
      });
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
        expect(provider.currentRound, 2);
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
      for (var round = 1; round <= CapitalContract.rounds; round++) {
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
      for (var round = 1; round <= CapitalContract.rounds; round++) {
        await missVisit();
        await missVisit();
      }
      expect(provider.gameOver, isTrue);
      expect(provider.winnerId, isNull);
    });

    test('refuses a dart once the game is over', () async {
      await startedGame();
      for (var round = 1; round <= CapitalContract.rounds; round++) {
        await missVisit();
        await missVisit();
      }
      await provider.recordDart(treble(20));
      expect(provider.playerStates.first.total, 0);
    });
  });
}
