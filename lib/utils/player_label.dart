import '../l10n/app_localizations.dart';
import '../models/player.dart';

/// What a scoreboard slot has to offer to be named: the four per-mode player
/// state classes implement this so one [SlotLabel] serves them all.
abstract interface class LabelledSlot {
  /// The team name in a team game, the player's stored name otherwise.
  String get displayName;

  /// The members of the slot, one of them in an individual game.
  List<Player> get players;

  /// Whether the slot is a team rather than a single player.
  bool get isTeamSlot;
}

/// The name a player is shown under.
///
/// A person is shown under the name they were given. A bot is shown under the
/// localized name of its tier, never under the neutral name its row stores,
/// so every place that prints a player goes through here rather than through
/// `name`. The stored name only surfaces where no localization can reach,
/// such as a backup opened by an older version of the app.
extension PlayerLabel on Player {
  /// The localized display name of this player.
  String label(AppLocalizations l) =>
      botLevel == null ? name : l.botName(botLevel!);
}

/// The name a scoreboard slot is shown under: the team name, or the label of
/// the one player in it.
extension SlotLabel on LabelledSlot {
  /// The localized display name of this slot.
  String label(AppLocalizations l) =>
      isTeamSlot ? displayName : players.first.label(l);
}

/// The names of several players in one string.
extension PlayersLabel on Iterable<Player> {
  /// The localized display names joined by [separator].
  String labels(AppLocalizations l, String separator) =>
      map((p) => p.label(l)).join(separator);
}
