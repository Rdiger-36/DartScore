/// How the throwing order of a game's slots was determined: [random] draws it
/// when the game starts, [fixed] keeps the order the players set by hand,
/// traditionally after throwing for the bull. In a team game the order applies
/// to the teams; the order of the members inside a team does not matter.
///
/// [random] is index 0 so that games stored before this setting existed, which
/// were always shuffled, decode to the mode they were actually played with.
enum StartingOrder { random, fixed }
