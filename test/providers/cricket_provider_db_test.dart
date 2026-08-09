import 'package:dartscore_app/models/cricket_game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/cricket_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_db.dart';

void main() {
  group('CricketProvider against a real database', () {
    useInMemoryDatabase();

    late CricketProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = CricketProvider();
      players = await insertPlayers(['A', 'B']);
    });

    CricketGame game({
      CricketVariant variant = CricketVariant.normal,
      CricketScoringMode scoringMode = CricketScoringMode.standard,
      StartingOrder startingOrder = StartingOrder.random,
      List<TeamConfig>? teams,
    }) =>
        CricketGame(
          variant: variant,
          scoringMode: scoringMode,
          legs: 1,
          sets: 1,
          createdAt: DateTime.now(),
          playerIds: players.map((p) => p.id!).toList(),
          teams: teams,
          startingOrder: startingOrder,
        );

    /// Throws [count] darts at [field] for whoever is on turn, three per visit.
    Future<void> hit(int field, {int multiplier = 1, int count = 1}) async {
      for (var i = 0; i < count; i++) {
        await provider.recordDart(field, multiplier);
      }
    }

    /// Closes [field] for the slot on turn using one full visit of singles.
    Future<void> closeField(int field) => hit(field, count: 3);

    /// Wastes a whole visit on misses.
    Future<void> passVisit() => hit(0, multiplier: 0, count: 3);

    test('three singles close a field', () async {
      await provider.startGame(game(), players);

      await closeField(20);

      expect(provider.playerStates[0].hasClosedField(20), isTrue);
      expect(provider.playerStates[0].score, 0);
      expect(provider.currentPlayerIndex, 1);
    });

    test('a triple closes a field in one dart', () async {
      await provider.startGame(game(), players);

      await hit(20, multiplier: 3);

      expect(provider.playerStates[0].hasClosedField(20), isTrue);
      expect(provider.dartsInVisit, 1);
    });

    test('marks past the close score while an opponent is open', () async {
      await provider.startGame(game(), players);

      await hit(20, multiplier: 3);  // closes 20
      await hit(20, multiplier: 1);  // scores 20
      await hit(20, multiplier: 1);  // scores 20

      expect(provider.playerStates[0].score, 40);
      expect(provider.playerStates[1].score, 0);
    });

    test('cut throat gives the points to the open opponents', () async {
      await provider.startGame(game(variant: CricketVariant.cutThroat), players);

      await hit(20, multiplier: 3);
      await hit(20, multiplier: 1);
      await hit(20, multiplier: 1);

      expect(provider.playerStates[0].score, 0);
      expect(provider.playerStates[1].score, 40);
    });

    test('simple mode counts one mark per dart', () async {
      await provider.startGame(
          game(scoringMode: CricketScoringMode.simple), players);

      await hit(20, multiplier: 3);

      expect(provider.playerStates[0].hasClosedField(20), isFalse,
          reason: 'a triple is worth a single mark in simple mode');
    });

    group('undo', () {
      test('takes back the last dart and replays the board', () async {
        await provider.startGame(game(), players);

        await hit(20, multiplier: 3);
        await hit(19, multiplier: 3);
        expect(provider.playerStates[0].hasClosedField(19), isTrue);

        await provider.undoLastDart();

        expect(provider.playerStates[0].hasClosedField(19), isFalse);
        expect(provider.playerStates[0].hasClosedField(20), isTrue);
        expect(provider.dartsInVisit, 1);
      });

      test('undoing the winning dart reopens the game', () async {
        await provider.startGame(game(), players);

        // A closes every field; B never scores, so A wins on the last close.
        for (final field in const [20, 19, 18, 17, 16, 15]) {
          await closeField(field);
          await passVisit();
        }
        await closeField(25);
        expect(provider.gameOver, isTrue);

        await provider.undoLastDart();

        expect(provider.gameOver, isFalse);
        expect(provider.winnerId, isNull);
        expect(provider.playerStates[0].hasClosedField(25), isFalse);
      });

      test('undoing the winning dart keeps a fixed starting order', () async {
        await provider.startGame(
            game(startingOrder: StartingOrder.fixed), players);

        for (final field in const [20, 19, 18, 17, 16, 15]) {
          await closeField(field);
          await passVisit();
        }
        await closeField(25);
        expect(provider.gameOver, isTrue);

        await provider.undoLastDart();

        expect(provider.game!.startingOrder, StartingOrder.fixed,
            reason: 'reopening the game must not reset how the order was set');
      });
    });

    test('a fixed order is kept by the rematch, random is drawn again',
        () async {
      await provider.startGame(
          game(startingOrder: StartingOrder.fixed), players);
      final template = provider.game!;

      await provider.startRematch(template, players);

      expect(provider.playerStates.map((s) => s.displayName), ['A', 'B']);
      expect(provider.game!.startingOrder, StartingOrder.fixed);
      expect(provider.game!.id, isNot(template.id),
          reason: 'a rematch is a new game row');
    });

    test('a team shares marks and rotates its members', () async {
      final more = await insertPlayers(['C', 'D']);
      final all = [...players, ...more];
      final teams = [
        TeamConfig(name: 'Team 1', playerIds: [all[0].id!, all[2].id!]),
        TeamConfig(name: 'Team 2', playerIds: [all[1].id!, all[3].id!]),
      ];
      await provider.startGame(
          CricketGame(
            variant: CricketVariant.normal,
            scoringMode: CricketScoringMode.standard,
            legs: 1,
            sets: 1,
            createdAt: DateTime.now(),
            playerIds: all.map((p) => p.id!).toList(),
            teams: teams,
          ),
          all);

      expect(provider.currentPlayerState.player.name, 'A');
      await hit(20, multiplier: 2);   // A: two marks on 20
      await hit(19, multiplier: 1);
      await hit(19, multiplier: 1);   // visit over
      await passVisit();              // Team 2

      expect(provider.currentPlayerState.player.name, 'C',
          reason: 'the next visit of team 1 is taken by its second member');
      await hit(20, multiplier: 1);   // C completes the field A started

      expect(provider.playerStates[0].hasClosedField(20), isTrue,
          reason: 'marks belong to the team, not to the member');
    });
  });
}
