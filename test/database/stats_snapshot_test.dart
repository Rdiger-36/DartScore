import 'dart:convert';

import 'package:dartscore_app/database/db_helper.dart';
import 'package:dartscore_app/models/game.dart';
import 'package:dartscore_app/models/player.dart';
import 'package:dartscore_app/providers/game_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_db.dart';

void main() {
  group('snapshotGameStats', () {
    useInMemoryDatabase();

    late GameProvider provider;
    late List<Player> players;

    setUp(() async {
      provider = GameProvider();
      players = await insertPlayers(['A', 'B']);
    });

    /// The stats snapshot stored on [player] after the game was archived.
    Future<Map<String, dynamic>> statsFor(Player player) async {
      final stored = await DbHelper.instance.getPlayer(player.id!);
      return jsonDecode(stored!.localStatsJson!) as Map<String, dynamic>;
    }

    test('counts a busted visit as a checkout attempt', () async {
      await provider.startGame(
          Game(startScore: 101, legs: 2, createdAt: DateTime.now()), players);

      // A: 101 left, scores 60, so the visit was a failed attempt at 101.
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);
      // B throws the same, keeping the turn moving.
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);
      // A: 41 left and overshoots with a triple 20.
      await provider.tapField(20, 3);

      expect(provider.playerStates[0].throws.last.bust, isTrue);
      await DbHelper.instance.snapshotGameStats(provider.game!.id!);

      final stats = await statsFor(players.first);
      expect(stats['checkout_attempts'], 2,
          reason: 'both the visit from 101 and the busted one from 41 count');
      expect(stats['checkout_successes'], 0);
      expect(stats['co_at_sub60'], 1,
          reason: 'the busted attempt from 41 lands in the 41 to 60 range');
      expect(stats['co_ok_sub60'], 0);
      expect(stats['busts'], 1);
    });

    test('a checkout counts as attempt and success', () async {
      await provider.startGame(
          Game(startScore: 101, legs: 2, createdAt: DateTime.now()), players);

      // T17 plus Bull double finishes 101 straight from the first visit.
      await provider.tapField(17, 3);
      await provider.tapField(25, 2);

      await DbHelper.instance.snapshotGameStats(provider.game!.id!);

      final stats = await statsFor(players.first);
      expect(stats['checkout_attempts'], 1);
      expect(stats['checkout_successes'], 1);
      expect(stats['highest_checkout'], 101);
      expect(stats['legs_won'], 1);
      expect(stats['perfect_legs'], 1);
    });

    test('leaves a visit above 170 out of the checkout ranges', () async {
      await provider.startGame(
          Game(startScore: 501, legs: 2, createdAt: DateTime.now()), players);

      await provider.tapField(20, 1);
      await provider.tapField(20, 1);
      await provider.tapField(20, 1);

      await DbHelper.instance.snapshotGameStats(provider.game!.id!);

      final stats = await statsFor(players.first);
      expect(stats['checkout_attempts'], 0);
      expect(stats['total_darts'], 3);
      expect(stats['total_scored'], 60);
    });
  });
}
