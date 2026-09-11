import '../models/around_the_clock_game.dart';
import 'dartboard_geometry.dart';

/// Where a bot aims its next dart in Around the Clock: at [target], the
/// number the player must hit next.
///
/// Any ring of the number advances in the basic variant, so the ring is the
/// bot's choice: the fat single for a bot that does not [aimTriples], the
/// triple otherwise, which is no worse a hit and the habit the bot has from
/// the other modes. Under skip rules the triple is worth three steps and the
/// double two, so a bot that goes for triples does; the rest keep to the
/// single, where a step is at least likely. Full segments name the rings
/// still missing in [neededSegments], and the bot works through them from
/// the single up. The bull is aimed at its centre, or at the outer ring when
/// that is the segment still missing.
BoardHit aroundTheClockTarget({
  required int target,
  required AroundTheClockVariant variant,
  required bool aimTriples,
  List<int>? neededSegments,
}) {
  if (variant == AroundTheClockVariant.fullSegments &&
      neededSegments != null &&
      neededSegments.isNotEmpty) {
    final lowest = neededSegments.reduce((a, b) => a < b ? a : b);
    return (field: target, multiplier: lowest);
  }
  if (target == 25) return (field: 25, multiplier: 2);
  return (field: target, multiplier: aimTriples ? 3 : 1);
}
