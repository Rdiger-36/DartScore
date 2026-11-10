/// The kind of board a game is played on, which decides how the board is
/// painted and so what its colors are called.
///
/// Both boards share one layout of paint, only the tones differ: the singles
/// alternate between two colors around the board, the double and triple rings
/// between two others, and a sector's rings always wear the other pair than
/// its singles. That is why the rules read a [BoardArea] rather than a color,
/// and only the labels and the dots on screen ask which board it is.
///
/// [steel] is index 0, the column default, and the order is stored: never
/// reorder the enum.
enum BoardType {
  /// A bristle board: black and cream singles, red and green rings, a red
  /// bull and a green outer bull.
  steel,

  /// An electronic board, which carries two colors only: blue and red singles
  /// and the same two on the rings, swapped, so the 20 is a blue single with
  /// red rings. The bull is red, the outer bull blue.
  softTip,
}
