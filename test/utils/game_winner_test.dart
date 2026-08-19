import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/dart_throw.dart';
import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:dartscore_app/utils/game_winner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_db.dart';

/// One recorded visit, as much of it as naming a winner needs.
DartThrow _visit({
  required int playerId,
  required int score,
  required int remainingBefore,
  int leg = 1,
  bool bust = false,
  required int minute,
}) =>
    DartThrow(
      id:              minute,
      gameId:          1,
      playerId:        playerId,
      score:           score,
      dartsUsed:       3,
      leg:             leg,
      set:             1,
      remainingBefore: remainingBefore,
      thrownAt:        DateTime(2026, 1, 1, 20, minute),
      bust:            bust,
    );

Game _game({
  bool placementMode = false,
  List<TeamConfig>? teams,
}) =>
    Game(
      id:            1,
      startScore:    501,
      legs:          3,
      createdAt:     DateTime(2026, 1, 1),
      placementMode: placementMode,
      teams:         teams,
    );

void main() {
  group('winningPlayerIds', () {
    test('the last checkout takes the game', () {
      final throws = [
        _visit(playerId: 1, score: 100, remainingBefore: 100, minute: 1),
        _visit(playerId: 2, score: 100, remainingBefore: 100, minute: 2),
        _visit(playerId: 1, score:  60, remainingBefore:  60, leg: 2, minute: 3),
      ];

      expect(winningPlayerIds(_game(), throws, participantIds: const [1, 2]), {1});
    });

    test('a bust that reaches zero wins nothing', () {
      final throws = [
        _visit(playerId: 1, score: 40, remainingBefore: 40, bust: true, minute: 1),
        _visit(playerId: 2, score: 40, remainingBefore: 40, minute: 2),
      ];

      expect(winningPlayerIds(_game(), throws, participantIds: const [1, 2]), {2});
    });

    test('a team game is won by everybody on the winning team', () {
      final teams = [
        const TeamConfig(name: 'Reds',  playerIds: [1, 3]),
        const TeamConfig(name: 'Blues', playerIds: [2, 4]),
      ];
      final throws = [
        _visit(playerId: 2, score: 100, remainingBefore: 100, minute: 1),
        _visit(playerId: 3, score:  40, remainingBefore:  40, minute: 2),
      ];

      expect(winningPlayerIds(_game(teams: teams), throws,
          participantIds: const [1, 2, 3, 4]), {1, 3});
    });

    test('a placement game goes to the best ranked, not to the last checkout',
        () {
      // Both check out in both legs, the first player ahead each time, so the
      // last checkout of the game is the loser's.
      final throws = [
        _visit(playerId: 1, score: 40, remainingBefore: 40, minute: 1),
        _visit(playerId: 2, score: 40, remainingBefore: 40, minute: 2),
        _visit(playerId: 1, score: 40, remainingBefore: 40, leg: 2, minute: 3),
        _visit(playerId: 2, score: 40, remainingBefore: 40, leg: 2, minute: 4),
      ];

      expect(winningPlayerIds(_game(placementMode: true), throws,
          participantIds: const [1, 2]), {1});
    });

    test('a placement game counts the players who never threw as participants',
        () {
      // Three played, the third never got a dart away. Leg 1 goes to player 1
      // ahead of player 2, leg 2 goes to player 2 alone, and player 2 is ahead
      // on points at the end of it.
      //
      // Counting the participants off the throws makes it two, which both
      // scores every placement one point too low and hands player 1 a second
      // place in leg 2 that was never thrown, because the leg then looks like
      // one where everybody but the last has checked out. That is enough to
      // level the points and hand the game to player 1 instead.
      final throws = [
        _visit(playerId: 1, score: 40, remainingBefore: 40, minute: 1),
        _visit(playerId: 2, score: 40, remainingBefore: 40, minute: 2),
        _visit(playerId: 2, score: 40, remainingBefore: 40, leg: 2, minute: 3),
      ];

      expect(
          winningPlayerIds(_game(placementMode: true), throws,
              participantIds: const [1, 2, 3]),
          {2});
    });

    test('a game nobody finished has no winner', () {
      final throws = [
        _visit(playerId: 1, score: 60, remainingBefore: 501, minute: 1),
        _visit(playerId: 2, score: 60, remainingBefore: 501, minute: 2),
      ];

      expect(winningPlayerIds(_game(), throws, participantIds: const [1, 2]),
          isEmpty);
    });
  });

  group('getWonGameIds against a real database', () {
    useInMemoryDatabase();

    late GameProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = GameProvider();
      players = await insertPlayers(['A', 'B']);
    });

    /// Plays one leg of 101 out, with [winner] taking it on a double.
    Future<int> playLeg(Player winner) async {
      await provider.startGame(
        Game(
          startScore:    101,
          legs:          1,
          createdAt:     DateTime.now(),
          startingOrder: StartingOrder.fixed,
        ),
        winner.id == players.first.id ? players : players.reversed.toList(),
      );
      final gameId = provider.game!.id!;
      // 41 leaves the winner on 60, the other player throws three misses in
      // between, and 20 plus double 20 takes it out.
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);
      await provider.tapField(1, 1);
      for (var dart = 0; dart < 3; dart++) {
        await provider.tapField(0, 1);
      }
      await provider.tapField(20, 1);
      await provider.tapField(20, 2);
      return gameId;
    }

    test('counts the games the player took, not the games they played',
        () async {
      final wonByA = await playLeg(players.first);
      final wonByB = await playLeg(players.last);

      expect(await DbHelper.instance.getWonGameIds(players.first.id!),
          {wonByA});
      expect(await DbHelper.instance.getWonGameIds(players.last.id!),
          {wonByB});
    });

    test('an unfinished game is nobody\'s', () async {
      await provider.startGame(
        Game(startScore: 501, legs: 1, createdAt: DateTime.now()),
        players,
      );
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);

      expect(await DbHelper.instance.getWonGameIds(players.first.id!), isEmpty);
    });
  });
}
