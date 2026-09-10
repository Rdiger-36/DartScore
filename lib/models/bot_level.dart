/// The skill tiers a computer opponent can play at, weakest first.
///
/// The index is what the `players.bot_level` column stores, so the order is
/// part of the schema: never reorder or remove a value, only append. A null
/// column is a human player.
///
/// Each tier is one player row that every game against that tier shares, so
/// its name and uuid are fixed here rather than generated. The uuid is shaped
/// like the random ones but sits in a range no generator produces, and it is
/// the same on every device: a bot row never travels over sync, but a backup
/// restored on another device must not leave two rows for one tier behind.
enum BotLevel {
  rookie,
  amateur,
  semiPro,
  pro,
  legend;

  /// The name stored in the player row and shown wherever a player's name is
  /// printed. Deliberately not localized: the row outlives the language
  /// setting, and history and summaries print the stored name.
  String get storedName => switch (this) {
        BotLevel.rookie  => 'Bot Rookie',
        BotLevel.amateur => 'Bot Amateur',
        BotLevel.semiPro => 'Bot Semi-Pro',
        BotLevel.pro     => 'Bot Pro',
        BotLevel.legend  => 'Bot Legend',
      };

  /// The fixed uuid of this tier's player row, identical on every device.
  String get uuid =>
      '00000000-0000-4000-8000-000000000b${index.toString().padLeft(2, '0')}';
}
