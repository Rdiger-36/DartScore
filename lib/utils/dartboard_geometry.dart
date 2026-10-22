import 'dart:math';

/// The fields of a standard dartboard clockwise from the top.
const dartboardSegmentOrder = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
  3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
];

/// One field of the board with the ring it was hit in: [multiplier] 1, 2 or
/// 3, the bull as field 25 with multiplier 1 for the outer and 2 for the inner
/// ring. A miss is field 0 with multiplier 0.
typedef BoardHit = ({int field, int multiplier});

/// A miss: the dart landed outside the double ring.
const BoardHit boardMiss = (field: 0, multiplier: 0);

/// A point on the board in millimetres from the centre, x to the right and y
/// upwards, the way a player facing the board sees it.
typedef BoardPoint = ({double x, double y});

/// The ring radii of a tournament board in millimetres, measured to the
/// centre of the wire, which is where the rules put the boundary. The bot
/// throws at this board rather than at the painted one, whose rings are
/// spaced for legibility on a phone, not to scale.
abstract final class BoardMm {
  static const double bullInner    = 6.35;
  static const double bullOuter    = 15.9;
  static const double tripleInner  = 99.0;
  static const double tripleOuter  = 107.0;
  static const double doubleInner  = 162.0;
  static const double doubleOuter  = 170.0;

  /// The middle of each ring, where a dart is aimed to land in it.
  static const double tripleMiddle      = (tripleInner + tripleOuter) / 2;
  static const double doubleMiddle      = (doubleInner + doubleOuter) / 2;
  static const double outerBullMiddle   = (bullInner + bullOuter) / 2;
  /// The single between the triple and the double ring, the larger of the two
  /// singles and the one a player aims at for a plain single.
  static const double outerSingleMiddle = (tripleOuter + doubleInner) / 2;
}

/// The angle in radians of the centre line of [field], counter clockwise from
/// the positive x axis, so the 20 sits straight up.
double _fieldAngle(int field) {
  final index = dartboardSegmentOrder.indexOf(field);
  assert(index >= 0, 'not a field on the board: $field');
  return pi / 2 - index * (2 * pi / dartboardSegmentOrder.length);
}

/// The point a dart is aimed at to hit [target]: the middle of the ring on
/// the centre line of the field, the board centre for the bull. A miss is
/// aimed at the centre too, which is a target nobody sensible picks.
BoardPoint aimPointFor(BoardHit target) {
  if (target.field == 25 || target.field == 0) {
    return target.multiplier == 1
        ? (x: 0, y: BoardMm.outerBullMiddle)
        : (x: 0, y: 0);
  }
  final radius = switch (target.multiplier) {
    3 => BoardMm.tripleMiddle,
    2 => BoardMm.doubleMiddle,
    _ => BoardMm.outerSingleMiddle,
  };
  final angle = _fieldAngle(target.field);
  return (x: radius * cos(angle), y: radius * sin(angle));
}

/// The field and ring under [point], or [boardMiss] outside the double ring.
///
/// A point exactly on a wire is given to the ring further out, and one on a
/// sector line to the field that follows clockwise, which only matters for
/// the tests that walk the boundaries.
BoardHit hitAt(BoardPoint point) {
  final r = sqrt(point.x * point.x + point.y * point.y);
  if (r > BoardMm.doubleOuter) return boardMiss;
  if (r < BoardMm.bullInner) return (field: 25, multiplier: 2);
  if (r < BoardMm.bullOuter) return (field: 25, multiplier: 1);

  final sector = 2 * pi / dartboardSegmentOrder.length;
  // Clockwise from the top, with the 20 centred on zero, so that a sector's
  // index is its distance from the top in whole sectors.
  var clockwise = pi / 2 - atan2(point.y, point.x) + sector / 2;
  clockwise %= 2 * pi;
  final field = dartboardSegmentOrder[(clockwise / sector).floor()];

  final multiplier = r >= BoardMm.doubleInner
      ? 2
      : (r >= BoardMm.tripleInner && r < BoardMm.tripleOuter ? 3 : 1);
  return (field: field, multiplier: multiplier);
}

/// The points [hit] scores in X01: field times ring, the bull 25 or 50, a
/// miss nothing.
int scoreOf(BoardHit hit) {
  if (hit.field == 0) return 0;
  if (hit.field == 25) return hit.multiplier == 2 ? 50 : 25;
  return hit.field * hit.multiplier;
}

/// The paint on a standard board.
///
/// The two single rings alternate black and white around the board, and the
/// double and triple rings alternate red and green over the same sectors, so a
/// sector whose singles are black has red multiples. The inner bull is red and
/// the outer bull green. These are the four colors the Capital "Color"
/// contract draws from; a miss has no color at all.
enum BoardColor { black, white, red, green }

/// The color [hit] landed on, or null for a miss.
///
/// The alternation runs with [dartboardSegmentOrder], so a field at an even
/// index is black in the singles and red in the double and triple rings, and
/// one at an odd index is white and green. That places the 20 at index 0 on
/// black and red and the 19 at index 11 on white and green, which is what a
/// real board shows.
BoardColor? colorOf(BoardHit hit) {
  if (hit.field == 0) return null;
  if (hit.field == 25) {
    return hit.multiplier == 2 ? BoardColor.red : BoardColor.green;
  }
  final index = dartboardSegmentOrder.indexOf(hit.field);
  assert(index >= 0, 'not a field on the board: ${hit.field}');
  if (hit.multiplier == 1) {
    return index.isEven ? BoardColor.black : BoardColor.white;
  }
  return index.isEven ? BoardColor.red : BoardColor.green;
}

/// Whether [fields] are sectors that all touch each other on the board.
///
/// True when they are consecutive entries of [dartboardSegmentOrder] read as a
/// ring, so the run may cross the top: 12, 5 and 20 touch. The order the
/// fields are given in does not matter, but a repeat does not make an arc and
/// neither the bull nor a miss is a sector, so either answers false.
///
/// This is board adjacency and has nothing to do with consecutive numbers: the
/// 20, 19 and 18 sit far apart on the board and answer false here.
bool areAdjacentSectors(List<int> fields) {
  if (fields.isEmpty) return false;
  final indices = <int>{};
  for (final field in fields) {
    final index = dartboardSegmentOrder.indexOf(field);
    if (index < 0) return false;
    indices.add(index);
  }
  if (indices.length != fields.length) return false;
  final sectors = dartboardSegmentOrder.length;
  for (final start in indices) {
    final arc = List.generate(indices.length, (step) => (start + step) % sectors);
    if (arc.every(indices.contains)) return true;
  }
  return false;
}
