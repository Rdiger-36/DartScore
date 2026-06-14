import 'package:flutter/material.dart';

import '../utils/match_format.dart';

/// Convenience access to [AppLocalizations] from any [BuildContext] via
/// `context.l10n` (e.g. `context.l10n.newGame`).
extension AppLocalizationsX on BuildContext {
  /// The active localizations for this context.
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// App-wide localized strings for English and German.
///
/// Each user-visible string is exposed as a getter that returns the English or
/// German variant based on the active [locale]. New strings are added as getters
/// using [_t]; the string values themselves serve as their own documentation.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  /// The nearest [AppLocalizations] for [context], defaulting to English.
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)
        ?? const AppLocalizations(Locale('en'));
  }

  /// Whether the active locale is German.
  bool get _de => locale.languageCode == 'de';

  /// Returns [de] when the locale is German, otherwise [en].
  String _t(String en, String de) => _de ? de : en;

  // ── General ──────────────────────────────────────────────────────────────
  String get appName           => 'DartScore';
  String get ok                => _t('OK', 'OK');
  String get cancel            => _t('Cancel', 'Abbrechen');
  String get save              => _t('Save', 'Speichern');
  String get delete            => _t('Delete', 'Löschen');
  String get edit              => _t('Edit', 'Bearbeiten');
  String get abort             => _t('Cancel', 'Abbrechen');
  String get confirm           => _t('Confirm', 'Bestätigen');
  String get yes               => _t('Yes', 'Ja');
  String get no                => _t('No', 'Nein');
  String get error             => _t('Error', 'Fehler');
  String get back              => _t('Back', 'Zurück');
  String get undo              => _t('Undo', 'Rückgängig');
  String get redo              => _t('Redo', 'Wiederherstellen');

  // ── Onboarding ───────────────────────────────────────────────────────────
  String get welcomeTitle      => _t('Welcome to DartScore!', 'Willkommen bei DartScore!');
  String get welcomeSubtitle   => _t('Create your profile to get started.', 'Erstelle dein Profil um loszulegen.');
  String get yourName          => _t('Your name', 'Dein Name');
  String get letsGo            => _t("Let's go!", 'Loslegen!');
  String get myProfile         => _t('My Profile', 'Mein Profil');

  // ── Home ─────────────────────────────────────────────────────────────────
  String get newGame           => _t('New Game', 'Neues Spiel');
  String get managePlayers     => _t('Manage Players', 'Spieler verwalten');
  String get gameHistory       => _t('Game History', 'Spielverlauf');
  String get settings          => _t('Settings', 'Einstellungen');

  // ── Game Setup ───────────────────────────────────────────────────────────
  String get gameSetup         => _t('Game Setup', 'Spiel einrichten');
  String get startScore        => _t('Start Score', 'Startpunkte');
  String get checkIn           => _t('Check-In', 'Check-In');
  String get checkOut          => _t('Check-Out', 'Check-Out');
  String get straightIn        => _t('Straight In', 'Straight In');
  String get doubleIn          => _t('Double In', 'Double In');
  String get straightOut       => _t('Straight Out', 'Straight Out');
  String get doubleOut         => _t('Double Out', 'Double Out');
  String get masterOut         => _t('Master Out', 'Master Out');
  String get legs              => _t('Legs', 'Legs');
  String get sets              => _t('Sets', 'Sets');
  /// One-line "Sets: x  Legs: y" tally for a summary card header.
  String setsLegsWon(int setsWon, int legsWon) =>
      '$sets: $setsWon  $legs: $legsWon';
  /// Compact, singular-aware "x Legs · y Sets" tally for inline display.
  String legsSetsShort(int legsCount, int setsCount) =>
      '$legsCount ${legsCount == 1 ? 'Leg' : 'Legs'} · '
      '$setsCount ${setsCount == 1 ? 'Set' : 'Sets'}';
  String get players           => _t('Players', 'Spieler');
  String get noPlayersAvail    => _t('No players available.', 'Keine Spieler vorhanden.');
  String get addPlayerLink     => _t('Add player', 'Spieler anlegen');
  String get startGame         => _t('Start Game', 'Spiel starten');
  String get startOpenPlay     => _t('Start Solo Game', 'Solo Spiel starten');
  String get minOnePlayer      => _t('Select at least 1 player', 'Mindestens 1 Spieler auswählen');
  String get openPlayHint      => _t('1 player = Solo Game (no opponent)', '1 Spieler = Solo Spiel (kein Gegner)');
  String get soloLegsHint      => _t('Solo game plays 1 leg · 1 set', 'Solo Spiel: 1 Leg · 1 Set');
  String playerN(int n)        => _t('Player $n', 'Spieler $n');

  // ── Match format presets ─────────────────────────────────────────────────
  String get matchFormat       => _t('Match Format', 'Match-Format');
  String get formatBo3         => _t('Best of 3', 'Best of 3');
  String get formatBo5         => _t('Best of 5', 'Best of 5');
  String get formatBo7         => _t('Best of 7', 'Best of 7');
  String get formatBo9         => _t('Best of 9', 'Best of 9');
  String get formatPdcSets     => _t('PDC Sets', 'PDC Sets');
  String get formatPremier     => _t('Premier League', 'Premier League');
  String get formatCustom      => _t('Custom', 'Eigene');
  // Short rule per preset, shown under the chips.
  String get formatBo3Rule     => _t('First to 2 Legs.', 'First to 2 Legs.');
  String get formatBo5Rule     => _t('First to 3 Legs.', 'First to 3 Legs.');
  String get formatBo7Rule     => _t('First to 4 Legs.', 'First to 4 Legs.');
  String get formatBo9Rule     => _t('First to 5 Legs.', 'First to 5 Legs.');
  String get formatPdcSetsRule => _t(
      'First to 3 Sets, each Set First to 3 Legs.',
      'First to 3 Sets - pro Set First to 3 Legs.');
  String get formatPremierRule => _t(
      'Pure leg race: First to 6 Legs, no Sets.',
      'Reines Leg-Race: First to 6 Legs, keine Sets.');
  String get formatCustomRule  => _t(
      'Choose Legs and Sets yourself.', 'Legs und Sets selbst festlegen.');
  String get firstToHint       => _t(
      'First to means: whoever reaches the chosen number of Legs or Sets first wins.',
      'First to heißt: Wer die gewählte Anzahl an Legs bzw. Sets zuerst erreicht, gewinnt.');

  // ── Game Screen ──────────────────────────────────────────────────────────
  String get openPlay          => _t('Solo Game', 'Solo Spiel');
  String get leg               => _t('Leg', 'Leg');
  String get set_              => _t('Set', 'Set');
  String get quitGame          => _t('Quit Game', 'Spiel beenden');
  String get quitTitle         => _t('Leave Game', 'Spiel verlassen');
  String get quitBody          => _t('Really quit the current game?', 'Spiel wirklich verlassen?');
  String get leave             => _t('Leave', 'Verlassen');
  String get single            => _t('Single', 'Single');
  String get double_           => _t('Double', 'Double');
  String get triple            => _t('Triple', 'Triple');
  String get miss              => _t('Miss', 'Miss');
  String get done              => _t('Done', 'Fertig');
  String get bust              => _t('Bust', 'Bust');
  String get checkoutHint      => _t('Check-Out:', 'Check-Out:');
  String get noCheckoutPossible => _t('No Check-Out possible', 'Kein Check-Out möglich');
  String dart(int n)           => _t('Dart $n', 'Dart $n');
  String bullLabel(bool d)     => d ? _t('Bull (50)', 'Bull (50)') : _t('Bull (25)', 'Bull (25)');
  String get average           => _t('Average', 'Average');
  String get remaining         => _t('remaining', 'übrig');

  // ── Game Summary ─────────────────────────────────────────────────────────
  String get gameOverview      => _t('Game Summary', 'Spielübersicht');
  String wins(String name)     => _t('🎯 $name wins!', '🎯 $name hat gewonnen!');
  String get allThrows         => _t('All Throws', 'Alle Würfe');
  String get backToHome        => _t('Back to Main Menu', 'Zurück zum Hauptmenü');
  String get saveToPhotos      => _t('Save to Photos', 'In Fotos speichern');
  String get share             => _t('Share', 'Teilen');
  String get savedToPhotos     => _t('Image saved to Photos.', 'Bild in Fotos gespeichert.');

  // ── 9-Darter / Perfect Game ───────────────────────────────────────────────
  String get nineDarter        => _t('9-Darter', '9-Darter');
  String get perfectGame       => _t('Perfect Game', 'Perfektes Spiel');
  String get perfectGames      => _t('Perfect Games', 'Perfekte Spiele');
  String perfectGameLabel(int minDarts) =>
      _t('$minDarts-Darter', '$minDarts-Darter');

  // ── Players ──────────────────────────────────────────────────────────────
  String get playersTitle      => _t('Players', 'Spieler');
  String get noPlayers         => _t('No players added yet.', 'Noch keine Spieler angelegt.');
  String get addPlayer         => _t('Add Player', 'Spieler hinzufügen');
  String get noFavDoubles      => _t('No favorite double', 'Keine Lieblings-Double');
  String get favDoublesPrefix  => _t('Double: ', 'Double: ');
  String get addPlayerTitle    => _t('Add Player', 'Spieler hinzufügen');
  String get editPlayerTitle   => _t('Edit Player', 'Spieler bearbeiten');
  String get nameLabel         => _t('Name', 'Name');
  String get favDoublesTitle      => _t('Favorite Double', 'Lieblings-Double');
  String get favDoublesRequired   => _t('Please select a favorite double', 'Bitte ein Lieblings-Double auswählen');
  String get favDoubleHint        => _t(
      'If multiple checkout routes are possible, the suggested finish prefers one ending on this double.',
      'Sind mehrere Finish-Wege möglich, wird bevorzugt ein Weg vorgeschlagen, der mit diesem Double endet');
  String get nameAlreadyExists => _t('This name is already taken', 'Dieser Name ist bereits vergeben');
  String get deletePlayerTitle => _t('Delete Player', 'Spieler löschen');
  String deletePlayerConfirm(String name) =>
      _t('Really delete $name?', '$name wirklich löschen?');
  String get syncProfile       => _t('Sync Profile', 'Profil synchronisieren');
  String get sharePlayerTooltip => _t('Sync Profile', 'Profil synchronisieren');
  String get setAsMainProfile  => _t('Set as Main Profile', 'Als Hauptprofil festlegen');
  String get alreadyMainProfile => _t('Main Profile', 'Hauptprofil');

  // ── Player Stats ─────────────────────────────────────────────────────────
  String get statistics        => _t('Statistics', 'Statistik');
  String get statsX01Only      => _t('Statistics are collected in X01 mode only.', 'Statistiken werden nur im X01 Spielmodus erhoben.');
  String noGamesFor(String name) =>
      _t('No games for $name yet.', 'Noch keine Spiele für $name.');
  String get highlights        => _t('Highlights', 'Highlights');
  String get count180          => _t('180s', '180er');
  String get count140plus      => _t('140+', '140+');
  String get count100plus      => _t('100+', '100+');
  String get highestCheckout   => _t('Highest Check-Out', 'Höchster Check-Out');
  String get highestVisit      => _t('Highest Visit', 'Höchste Aufnahme');
  String get overview          => _t('Overview', 'Übersicht');
  String get gamesPlayed       => _t('Games Played', 'Spiele gespielt');
  String get gamesWon          => _t('Games Won', 'Spiele gewonnen');
  String get legsWon           => _t('Legs Won', 'Legs gewonnen');
  String get totalVisits       => _t('Total Visits', 'Aufnahmen gesamt');
  String get totalDarts        => _t('Total Darts', 'Pfeile gesamt');
  String get accuracy          => _t('Accuracy', 'Treffsicherheit');
  String get threeDartAvg      => _t('3-Dart Average', '3-Dart Average');
  String get bustRate          => _t('Bust Rate', 'Bust-Rate');
  String get checkoutRate      => _t('Check-Out Rate', 'Check-Out-Quote');
  String get scoreDistribution => _t('Score Distribution', 'Score-Verteilung');
  String get recentThrows      => _t('Recent Throws', 'Letzte Würfe');
  String get syncedStatsFrom   => _t('Synced statistics from', 'Synchronisierte Statistiken vom');
  String get syncedStats       => _t('Synced statistics', 'Synchronisierte Statistiken');
  String get visits            => _t('Visits', 'Aufnahmen');
  String get darts_            => _t('Darts', 'Pfeile');
  String get busts             => _t('Busts', 'Busts');

  // ── Extended Player Stats ────────────────────────────────────────────────
  String get dartboardHeatmap   => _t('Dartboard Heatmap', 'Dartscheiben-Heatmap');
  String get stability          => _t('Consistency', 'Konstanz');
  String get stabilityVeryHigh  => _t('Very Consistent', 'Sehr konstant');
  String get stabilityHigh      => _t('Consistent', 'Konstant');
  String get stabilityMedium    => _t('Variable', 'Variabel');
  String get stabilityLow       => _t('Very Variable', 'Sehr variabel');
  String stabilityHint(String s) =>
      _t('Standard deviation of visits: $s pts — lower = more consistent.',
         'Standardabweichung der Aufnahmen: $s Punkte — niedriger = gleichmäßiger.');
  String get checkoutBreakdown  => _t('Check-Out by Range', 'Check-Out nach Restpunkten');
  String get weekComparison     => _t('Week Comparison', 'Wochenvergleich');
  String get thisWeek           => _t('This week', 'Diese Woche');
  String get lastWeek           => _t('Last week', 'Letzte Woche');

  // ── History ───────────────────────────────────────────────────────────────
  String get historyTitle      => _t('Game History', 'Spielverlauf');
  String get open              => _t('Open', 'Offen');
  String get finished          => _t('Finished', 'Abgeschlossen');
  String get clearAll          => _t('Delete All', 'Alles löschen');
  String get clearAllTitle     => _t('Delete all?', 'Alles löschen?');
  String get clearAllBody      =>
      _t('Delete the entire game history permanently?',
         'Gesamten Spielverlauf unwiderruflich löschen?');
  String get resume            => _t('Resume', 'Fortsetzen');
  String get noHistory         => _t('No games played yet.', 'Noch keine Spiele gespielt.');
  String get filterAll         => _t('All', 'Alle');
  String get gameModeX01       => 'X01';
  String get gameModeCricket   => 'Cricket';
  String get gameModeShanghai  => 'Shanghai';
  String get gameModeAroundTheClock => _t('Around the Clock', 'Around the Clock');
  String get openAdj           => _t('open', 'offenen');
  String get finishedAdj       => _t('finished', 'abgeschlossenen');
  String deleteVisibleBody(String adj, String mode) => mode.isEmpty
      ? _t('Permanently delete all $adj games?',
           'Alle $adj Spiele unwiderruflich löschen?')
      : _t('Permanently delete all $adj $mode games?',
           'Alle $adj $mode Spiele unwiderruflich löschen?');
  String get points            => _t('Points', 'Punkte');

  /// The chip label for a match format preset (e.g. "Best of 5", "PDC Sets").
  String matchFormatLabel(MatchFormat f) => switch (f) {
        MatchFormat.bo3 => formatBo3,
        MatchFormat.bo5 => formatBo5,
        MatchFormat.bo7 => formatBo7,
        MatchFormat.bo9 => formatBo9,
        MatchFormat.pdcSets => formatPdcSets,
        MatchFormat.premierLeague => formatPremier,
        MatchFormat.custom => formatCustom,
      };

  /// Match format label for a past game derived from its stored legs/sets:
  /// the named preset (e.g. "Best of 5") when one matches, otherwise the custom
  /// label with the concrete counts (e.g. "Eigene 6 Legs - 7 Sets").
  String matchFormatDesc(int legs, int sets) {
    final f = MatchFormatLookup.fromValues(legs, sets);
    if (f != MatchFormat.custom) return matchFormatLabel(f);
    final legLabel = legs == 1 ? 'Leg' : 'Legs';
    final setLabel = sets == 1 ? 'Set' : 'Sets';
    return _t('Custom $legs $legLabel - $sets $setLabel',
              'Eigene $legs $legLabel - $sets $setLabel');
  }

  String gameSummaryInfo(int score, int l, int s) =>
      _t('$score pts · ${matchFormatDesc(l, s)}',
         '$score Punkte · ${matchFormatDesc(l, s)}');

  // ── Game setup / Team / Handicap ─────────────────────────────────────────
  String get handicap            => _t('Handicap', 'Handicap');
  String get handicapDesc        => _t('Individual Check-In / Check-Out rules per player', 'Individuelle Check-In / Check-Out Regeln pro Spieler');
  String get teamGame            => _t('Team Game', 'Team Spiel');
  String get teamGameDesc        => _t('Split players into teams. Each team shares one score.', 'Spieler auf Teams aufteilen. Jedes Team teilt sich einen Score.');
  String get done_               => _t('Done', 'Fertig');
  String get statsTooltip        => _t('Statistics', 'Statistik');
  String get statsLoadError      => _t('Statistics could not be loaded.', 'Statistiken konnten nicht geladen werden.');
  String get gameMode_           => _t('Mode', 'Modus');
  String get gameLabel           => _t('Game', 'Spiel');
  String get unknownDevice       => _t('Unknown device', 'Unbekanntes Gerät');
  String get teamPlayers         => _t('Players', 'Spieler');

  // ── Settings ─────────────────────────────────────────────────────────────
  String get settingsTitle     => _t('Settings', 'Einstellungen');
  String get language          => _t('Language', 'Sprache');
  String get appearance        => _t('Appearance', 'Erscheinungsbild');
  String get system            => _t('System', 'System');
  String get systemDesc        => _t('Follows System setting', 'Folgt der System-Einstellung');
  String get light             => _t('Light', 'Hell');
  String get lightDesc         => _t('Always light theme', 'Immer helles Design');
  String get dark              => _t('Dark', 'Dunkel');
  String get darkDesc          => _t('Always dark theme', 'Immer dunkles Design');
  String get profileSharing    => _t('Share & Import Profile', 'Profil teilen & importieren');
  String get shareHint         =>
      _t('Share your profile as a QR code with friends.',
         'Teile dein Profil als QR-Code mit Freunden.');
  String get scanImport        => _t('Scan & Import Profile', 'Profil scannen & importieren');
  String get scanImportDesc    => _t('Scan a friend\'s QR code', 'QR-Code eines Freundes scannen');
  String get importFromLibrary => _t('Import from Photo Library', 'Aus Foto-Bibliothek importieren');
  String get importFromLibDesc => _t('Select a saved QR code image', 'Gespeichertes QR-Code Bild auswählen');
  String get noPlayersSettings => _t('No players added yet.', 'Noch keine Spieler angelegt.');

  // ── Donation ─────────────────────────────────────────────────────────────
  String get donationTitle      => _t('Support Developer', 'Entwickler unterstützen');
  String get donationSectionTitle => _t('Support', 'Unterstützen');
  String get donationSectionDesc  => _t('Buy me a coffee', 'Kauf mir einen Kaffee');
  String get donationSubtitle   => _t(
      'DartScore is free and has no ads. If you enjoy it, a small donation helps keep it alive and supports future development.',
      'DartScore ist kostenlos und hat keine Werbung. Wenn dir die App gefällt, hilft eine kleine Spende dabei, sie am Leben zu erhalten und weiterzuentwickeln.');
  String get donationUnavailable => _t(
      'In-app purchases are not available on this device.',
      'In-App-Käufe sind auf diesem Gerät nicht verfügbar.');
  String get donationThankYouTitle => _t('Thank you! 🎯', 'Danke! 🎯');
  String get donationThankYouBody  => _t(
      'Your support means a lot and helps keep DartScore free for everyone.',
      'Deine Unterstützung bedeutet mir viel und hilft dabei, DartScore für alle kostenlos zu halten.');

  // ── About ────────────────────────────────────────────────────────────────
  String get about             => _t('About', 'Info');
  String get aboutTitle        => _t('About DartScore', 'Über DartScore');
  String get version           => _t('Version', 'Version');
  String get developer         => _t('Developer', 'Entwickler');
  String get support           => _t('Support', 'Support');
  String get supportDesc       => _t('Get help or report an issue', 'Hilfe erhalten oder ein Problem melden');
  String get license           => _t('License', 'Lizenz');
  String get licenseDesc       => _t('GNU General Public License v3.0', 'GNU General Public License v3.0');
  String get licenseFullText   => _t('Read full license text', 'Vollständigen Lizenztext lesen');
  String get openSourceLicenses     => _t('Open Source Licenses', 'Open-Source-Lizenzen');
  String get openSourceLicensesDesc => _t('Packages used in this app', 'In dieser App verwendete Pakete');
  String get linkOpenError     => _t('Could not open the link.', 'Der Link konnte nicht geöffnet werden.');

  // ── Sync ──────────────────────────────────────────────────────────────────
  String get syncTitle         => _t('Profile Sync', 'Profil Sync');
  String get syncSend          => _t('Send', 'Senden');
  String get syncReceive       => _t('Receive', 'Empfangen');

  // Quick QR
  String get quickQr           => _t('Quick QR', 'Schnell-QR');
  String get wifiSync          => _t('WiFi Sync', 'WLAN-Sync');
  String get quickQrDesc       =>
      _t('Transfer your profile & new throws directly via QR code. No network needed.',
         'Übertrage dein Profil & neue Würfe direkt über einen QR-Code. Kein Netzwerk nötig.');
  String get qrTooLargeWarning =>
      _t('Too many throws for a QR code.\nUse WiFi Sync to transfer all data.',
         'Zu viele Würfe für einen QR-Code.\nNutze WLAN-Sync um alle Daten zu übertragen.');
  String newThrowsSinceSync(int n) =>
      _t('$n new throw${n != 1 ? 's' : ''} since last sync',
         '$n neue${n != 1 ? '' : 'r'} ${n != 1 ? 'Würfe' : 'Wurf'} seit letztem Sync');
  String get allThrowsFirstSync =>
      _t('All throws included — first sync', 'Alle Würfe enthalten — erster Sync');
  String get noNewThrowsQr    =>
      _t('No new throws — stats snapshot updated.',
         'Keine neuen Würfe — Statistik-Snapshot aktualisiert.');

  String get syncSendDesc      =>
      _t('Select a player and start the server. The receiver scans the QR code — both devices must be on the same Wi-Fi.',
         'Wähle deinen Spieler und starte den Server. Der Empfänger scannt den QR-Code — beide Geräte müssen im selben WLAN sein.');
  String get syncReceiveDesc   =>
      _t('Scan the sender\'s QR code to import their profile.',
         'Scanne den QR-Code des Senders um sein Profil zu importieren.');
  String get selectPlayer      => _t('Select player', 'Spieler auswählen');
  String get startServer       => _t('Start Server', 'Server starten');
  String get stopServer        => _t('Stop Server', 'Server stoppen');
  String get scanQr            => _t('Scan QR Code', 'QR-Code scannen');
  String get profileAndStats   => _t('Profile · Stats · all throws', 'Profil · Statistiken · alle Würfe');
  String get qrScanHint        => _t('Hold sender\'s QR code in frame', 'QR-Code des Senders halten');
  String get connectionFailed  =>
      _t('Connection failed.\nCheck that both devices are on the same Wi-Fi.',
         'Verbindung fehlgeschlagen.\nPrüfe ob beide Geräte im selben WLAN sind.');
  String get importNewPlayer   => _t('Import New Player', 'Neuen Spieler importieren');
  String get updatePlayer      => _t('Update Player', 'Spieler aktualisieren');
  String get nameConflictTitle => _t('Name already exists', 'Name bereits vorhanden');
  String nameConflictBody(String name) =>
      _t('"$name" already exists. What should happen?',
         '"$name" existiert bereits. Was soll passieren?');
  String importAs(String name) => _t('Import as "$name"', 'Als "$name" importieren');
  String get renameAndImport   => _t('Rename & Import', 'Umbenennen & importieren');
  String get alternativeName   => _t('Alternative name', 'Alternativer Name');
  String get lastSyncPrefix    => _t('Last sync: ', 'Letzter Sync: ');
  String fromDevice(String d)  => _t('From: $d', 'Von: $d');
  String get updateProfileToggle =>
      _t('Update name & favorite double', 'Name & Lieblings-Double übernehmen');
  String get import_           => _t('Import', 'Importieren');
  String get update            => _t('Update', 'Aktualisieren');
  String get alreadyOwned      => _t('Already imported', 'Bereits vorhanden');
  String importedMsg(String name) => _t('$name imported.', '$name importiert.');
  String updatedMsg(String name) => _t('$name updated.', '$name aktualisiert.');
  String importedWithThrows(String name, int n) =>
      _t('$name updated · $n new visits imported.',
         '$name aktualisiert · $n neue Aufnahmen importiert.');
  String importedWithCount(String name, int n) =>
      _t('$name imported · $n visits.',
         '$name importiert · $n Aufnahmen.');
  String overwriteProfile(String name) =>
      _t('Profile of "$name" will be overwritten with this data.',
         'Profil von "$name" wird mit diesen Daten überschrieben.');
  String remainingScore(int n) => _t('Remaining: $n', 'Verbleibend: $n');
  String get noQrInImage       => _t('No QR code found in image.', 'Kein QR-Code im Bild gefunden.');
  String get invalidQr         => _t('Invalid QR code.', 'Ungültiger QR-Code.');
  String get nameMissing       => _t('Name missing in QR code.', 'Name fehlt im QR-Code.');
  String get qrReadError       => _t('Error reading QR code.', 'Fehler beim Lesen des QR-Codes.');
  String get saveQrHint        =>
      _t('Have a friend scan this — or save as image.',
         'Von einem Freund scannen lassen oder als Bild speichern.');
  String get profileDataHint   =>
      _t('Profile data: Name · Favorite double · Statistics',
         'Profil-Daten: Name · Lieblings-Double · Statistiken');
  String get throws            => _t('Throws', 'Würfe');

  // ── Game Mode Selection ──────────────────────────────────────────────────
  String get selectGameMode       => _t('Select Game Mode', 'Spielmodus wählen');
  String get comingSoon           => _t('Coming Soon', 'Demnächst');
  String get modeInfoTitle        => _t('Game Mode Info', 'Spielmodus Info');

  // X01
  String get modeX01Name          => 'X01';
  String get modeX01Tagline       => _t('Classic countdown', 'Klassischer Countdown');
  String get modeX01Description   => _t(
    'Count down from a starting score (301, 501, 701 ...) to exactly zero.\n\n'
    'Each player throws 3 darts per visit. The total score of those darts is subtracted from the remaining score.\n\n'
    'You win a leg by reaching exactly 0. Depending on the Check-In/Check-Out rules, the first and/or last dart must land on a double (or master).\n\n'
    'A bust occurs when you score more than your remaining points, leave exactly 1, or fail the required Check-Out. In that case your score resets to where it was before the visit.',
    'Zähle von einem Startpunktestand (301, 501, 701 ...) genau auf null herunter.\n\n'
    'Jeder Spieler wirft pro Aufnahme 3 Pfeile. Die Gesamtpunkte dieser Pfeile werden vom verbleibenden Restpunkt abgezogen.\n\n'
    'Ein Leg gewinnst du, indem du genau 0 erreichst. Je nach Check-In/Check-Out-Regel muss der erste und/oder letzte Pfeil auf einem Double (oder Master) landen.\n\n'
    'Ein Bust passiert, wenn du mehr Punkte wirfst als du noch hast, genau 1 Punkt übrig lässt oder das geforderte Check-Out verfehlst. Dein Stand wird dann auf den Wert vor der Aufnahme zurückgesetzt.',
  );

  // Cricket
  String get modeCricketName        => 'Cricket';
  String get modeCricketTagline     => _t('Close numbers, score points', 'Felder schließen, Punkte sammeln');
  String get modeCricketDescription => _t(
    'Cricket is played on the numbers 15, 16, 17, 18, 19, 20 and the Bull. All other fields do not count.\n\n'
    'GOAL\n'
    'Close all 7 fields and have at least as many points as your opponent.\n\n'
    'CLOSING A FIELD\n'
    'Each field must be hit 3 times to "open" it for you:\n'
    '  Single = 1 hit\n'
    '  Double = 2 hits\n'
    '  Triple = 3 hits (closed instantly)\n\n'
    'Example: a Triple 20 closes the 20 with a single dart.\n\n'
    'SCORING POINTS\n'
    'Once you have opened a field (3 hits), every additional hit on it scores points equal to the field value, as long as your opponent has not closed it yet.\n\n'
    'Example:\n'
    '  You hit 20, 20, 20 -> field 20 is open\n'
    '  You hit 20 again -> +20 points for you\n'
    '  Opponent hits 20, 20, 20 -> field 20 is now closed for both, no more scoring on 20\n\n'
    'WINNING\n'
    'You win when all 7 fields are closed by you AND you have equal or more points than your opponent. If you close all fields but are behind on points, you must keep scoring until you catch up.\n\n'
    'CUT THROAT VARIANT\n'
    'Rules are reversed: points do not go to your own account. Instead, every hit on an open field adds points to each opponent who has not yet closed that field. The player with the fewest points wins. Strategy shifts: open fields quickly to avoid giving opponents points, and target fields your opponents have not closed yet.\n\n'
    'Example:\n'
    '  You open the 20 (3 hits) and hit it again -> opponent gets +20 points\n'
    '  Opponent closes the 20 -> further hits on 20 no longer score\n'
    '  You have 0 points, opponent has 20 points -> you are winning',
    'Cricket wird auf den Feldern 15, 16, 17, 18, 19, 20 und dem Bull gespielt. Alle anderen Felder zählen nicht.\n\n'
    'ZIEL\n'
    'Schließe alle 7 Felder und habe mindestens genauso viele Punkte wie dein Gegner.\n\n'
    'EIN FELD SCHLIESSEN\n'
    'Jedes Feld muss 3x getroffen werden, um es zu "öffnen":\n'
    '  Einfach = 1 Treffer\n'
    '  Doppel = 2 Treffer\n'
    '  Triple = 3 Treffer (direkt geschlossen)\n\n'
    'Beispiel: Ein Triple auf die 20 schließt das Feld sofort mit einem Pfeil.\n\n'
    'PUNKTE MACHEN\n'
    'Sobald du ein Feld geöffnet hast (3 Treffer), bringt jeder weitere Treffer darauf Punkte in Höhe des Feldwerts, solange dein Gegner das Feld noch nicht ebenfalls geschlossen hat.\n\n'
    'Beispiel:\n'
    '  Du triffst 20, 20, 20 -> Feld 20 ist offen\n'
    '  Du triffst nochmal 20 -> +20 Punkte für dich\n'
    '  Gegner trifft 20, 20, 20 -> Feld 20 ist nun für beide geschlossen, niemand kann mehr auf 20 punkten\n\n'
    'GEWINNBEDINGUNG\n'
    'Du gewinnst, wenn alle 7 Felder von dir geschlossen sind UND du gleich viele oder mehr Punkte hast als dein Gegner. Hast du alle Felder geschlossen aber weniger Punkte, musst du weiter punkten bis du gleichauf bist.\n\n'
    'CUT THROAT VARIANTE\n'
    'Die Regeln sind umgekehrt: Punkte gehen nicht auf dein eigenes Konto. Stattdessen bekommt jeder Gegner, der das Feld noch nicht geschlossen hat, die Punkte gutgeschrieben. Gewinner ist der Spieler mit den wenigsten Punkten. Die Strategie dreht sich um: öffne Felder schnell, um Gegner nicht zu belasten, und triff gezielt Felder, die deine Gegner noch nicht geschlossen haben.\n\n'
    'Beispiel:\n'
    '  Du öffnest die 20 (3 Treffer) und triffst sie nochmals -> Gegner bekommt +20 Punkte\n'
    '  Gegner schließt die 20 -> weitere Treffer auf die 20 bringen keine Punkte mehr\n'
    '  Du hast 0 Punkte, Gegner hat 20 Punkte -> du liegst vorne',
  );

  // Shanghai
  String get modeShanghaiName        => 'Shanghai';
  String get modeShanghaiTagline     => _t('Hit the right number each round', 'Jede Runde die richtige Zahl treffen');
  String get modeShanghaiDescription => _t(
    'Shanghai is played on the numbers 1 to 9. Only hits on the currently active field count. The maximum score per visit is 9 times the field value (3 darts, all Triple).\n\n'
    'SHANGHAI: INSTANT WIN\n'
    'If a player hits all three segments of the active field (Single, Double, and Triple) in one visit, this is called a Shanghai and wins the game immediately. Exception: if the following player also throws a Shanghai in their turn, the game continues. Otherwise the player with the most points wins.\n\n'
    'VARIANT 1: Classic (fields 1-9)\n'
    'Players take turns throwing 3 darts at the active number. Only hits on that number score. Numbers advance from 1 to 9.\n\n'
    'Example (active field: 6):\n'
    '  Single 6, Double 6, Triple 6 -> 6 + 12 + 18 = 36 points\n'
    '  Single 6, Double 6, miss -> 18 points, no Shanghai\n\n'
    'VARIANT 2: Clockwise (7 throws per player)\n'
    'Each player throws 7 darts. The target number advances with every dart in clockwise order: dart 1 targets 1, dart 2 targets 2, and so on up to 20, then the Bull. A Shanghai in this variant means hitting 3 consecutive clockwise numbers in one visit.\n\n'
    'Example:\n'
    '  Single 1, Double 2, Triple 3 -> Shanghai!\n\n'
    'VARIANT 3: Sequential\n'
    'A player throws at 1 until they hit it, then moves on to 2, and so on. The game can end in as few as 20 darts. A Shanghai here also consists of three different consecutive fields.',
    'Shanghai wird auf den Zahlen 1 bis 9 gespielt. Nur Treffer auf dem jeweils aktiven Feld zählen. Der maximale Punktestand pro Aufnahme beträgt das 9-Fache des Feldwerts (3 Pfeile, alle Triple).\n\n'
    'SHANGHAI: SOFORTSIEG\n'
    'Trifft ein Spieler alle drei Segmente des aktiven Feldes (Single, Double und Triple) in einer Aufnahme, nennt man das Shanghai und gewinnt das Spiel sofort. Ausnahme: Erzielt der Nachwerfer in seinem Zug ebenfalls einen Shanghai, wird das Spiel fortgesetzt. Ansonsten gewinnt der Spieler mit den meisten Punkten.\n\n'
    'VARIANTE 1: Klassisch (Felder 1-9)\n'
    'Die Spieler werfen abwechselnd 3 Pfeile auf die aktive Zahl. Nur Treffer auf dieser Zahl zählen. Die Zahlen gehen von 1 bis 9.\n\n'
    'Beispiel (aktives Feld: 6):\n'
    '  Single 6, Doppel 6, Triple 6 -> 6 + 12 + 18 = 36 Punkte\n'
    '  Single 6, Doppel 6, Fehler -> 18 Punkte, kein Shanghai\n\n'
    'VARIANTE 2: Im Uhrzeigersinn (7 Würfe pro Spieler)\n'
    'Jeder Spieler wirft 7 Pfeile. Die Zielzahl wechselt mit jedem Pfeil im Uhrzeigersinn: Pfeil 1 zielt auf die 1, Pfeil 2 auf die 2, usw. bis zur 20, dann das Bull. Ein Shanghai bedeutet hier drei aufeinanderfolgende Felder im Uhrzeigersinn in einer Aufnahme zu treffen.\n\n'
    'Beispiel:\n'
    '  Single 1, Doppel 2, Triple 3 -> Shanghai!\n\n'
    'VARIANTE 3: Sequenziell\n'
    'Ein Spieler wirft so lange auf die 1, bis er sie getroffen hat, dann auf die 2 usw. Das Spiel kann in bereits 20 Pfeilen enden. Ein Shanghai besteht auch hier aus drei verschiedenen aufeinanderfolgenden Zahlenfeldern.',
  );

  // Around the Clock
  String get modeAroundClockName        => 'Around the Clock';
  String get modeAroundClockTagline     => _t('Hit every number in order', 'Alle Zahlen der Reihe nach treffen');
  String get modeAroundClockDescription => _t(
    'Around the Clock is played clockwise starting from 1 up to the Bull\'s Eye. You must hit each number at least once before moving to the next. The first player to reach and hit the Bull\'s Eye wins.\n\n'
    'CLOCKWISE ORDER\n'
    '1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5, 20, Bull\n\n'
    'FULL SEGMENT VARIANT\n'
    'A stricter variant requires hitting all three segments of each number before advancing: Single, Double, and Triple. Only then can you move to the next clockwise number.\n\n'
    'Example:\n'
    '  Single 1, Double 1, Triple 1 -> advance to 18\n'
    '  Single 18, Double 18, Triple 18 -> advance to 4\n\n'
    'POPULAR VARIANT: Skip Rules\n'
    'In the most popular variant, Double and Triple fields have a special bonus, similar to Shanghai:\n'
    '  Double: skip one field ahead\n'
    '  Triple: skip two fields ahead\n'
    '  Bull\'s Eye (inner Bull): joker, skip the current field and advance to the next\n\n'
    'Example:\n'
    '  You hit Double 18 -> skip 4, continue at 13\n'
    '  You hit Triple 4 -> skip 13 and 6, continue at 10\n'
    '  You hit Bull\'s Eye -> skip current field, advance by one',
    'Around the Clock wird im Uhrzeigersinn gespielt, beginnend bei der 1 bis zum Bull\'s Eye. Du musst jedes Feld mindestens einmal treffen, bevor du zum nächsten darfst. Der erste Spieler, der das Bull\'s Eye trifft, gewinnt.\n\n'
    'REIHENFOLGE IM UHRZEIGERSINN\n'
    '1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5, 20, Bull\n\n'
    'ALLE-SEGMENTE-VARIANTE\n'
    'Eine strengere Variante verlangt, dass du alle drei Segmente jedes Feldes triffst, bevor du weiter darfst: Single, Double und Triple. Erst dann kannst du zur nächsten Zahl im Uhrzeigersinn wechseln.\n\n'
    'Beispiel:\n'
    '  Single 1, Doppel 1, Triple 1 -> weiter zur 18\n'
    '  Single 18, Doppel 18, Triple 18 -> weiter zur 4\n\n'
    'BELIEBTE VARIANTE: Überspringen\n'
    'In der beliebtesten Variante haben Doppel- und Triple-Felder sowie das Bull eine besondere Funktion, ähnlich wie bei Shanghai:\n'
    '  Doppel: ein Feld überspringen\n'
    '  Triple: zwei Felder überspringen\n'
    '  Bull\'s Eye (inneres Bull): Joker, aktuelle Zahl überspringen und beim nächsten Feld weiterspielen\n\n'
    'Beispiel:\n'
    '  Du triffst Doppel 18 -> überspringe 4, weiter bei 13\n'
    '  Du triffst Triple 4 -> überspringe 13 und 6, weiter bei 10\n'
    '  Du triffst Bull\'s Eye -> überspringe aktuelle Zahl, rücke um eins vor',
  );

  // ── Misc numbers/units ───────────────────────────────────────────────────
  String dartsN(int n) => _t('$n dart${n != 1 ? 's' : ''}', '$n Pfeil${n != 1 ? 'e' : ''}');
  String dartsShort(int n) => _t('${n}D', '${n}P');
  String legLabel(int l) => 'Leg $l';
  String setLabel(int s) => 'Set $s';

  // ── Compact / abbreviation labels ────────────────────────────────────────
  String get straight       => _t('Straight', 'Straight');
  String get master         => _t('Master', 'Master');
  String get setsAbbr       => _t('S', 'S');
  String get legsAbbr       => _t('L', 'L');
  String get highAbbr       => _t('High', 'High');
  String get shareSubject   => _t('DartScore Result', 'DartScore Ergebnis');
  String get noThrowData    => _t('No throw data available.', 'Keine Wurfdaten vorhanden.');
  String get guest          => _t('Guest', 'Gast');
  String get addTeam        => _t('Add team', 'Team hinzufügen');
  String get removeTeam     => _t('Remove team', 'Team entfernen');
  String teamN(int n)       => _t('Team $n', 'Team $n');
  String get doublesLabel   => _t('Doubles', 'Doubles');

  // ── Cricket History ──────────────────────────────────────────────────────────
  String cricketGameInfo(String variant) =>
      _t('Cricket · $variant', 'Cricket · $variant');
  String get cricketVariantNormal    => _t('Normal', 'Normal');
  String get cricketVariantCutThroat => 'Cut Throat';

  // ── Cricket Setup ────────────────────────────────────────────────────────────
  String get cricketSetup         => _t('Cricket Setup', 'Cricket einrichten');
  String get cricketVariant       => _t('Variant', 'Variante');
  String get cricketNormal        => _t('Normal', 'Normal');
  String get cricketCutThroat     => 'Cut Throat';
  String get cricketCutThroatDesc =>
      _t('Points go to opponents who haven\'t closed the field. Fewest points wins.',
         'Punkte gehen an Gegner, die das Feld noch nicht geschlossen haben. Wenigste Punkte gewinnt.');
  String get cricketScoringMode   => _t('Scoring Mode', 'Wertungsmodus');
  String get cricketStandard      => _t('Standard (S/D/T)', 'Standard (E/D/T)');
  String get cricketSimple        => _t('Simple (singles only)', 'Einfach (nur Singles)');
  String get cricketSimpleDesc    =>
      _t('Every dart counts as 1 mark regardless of segment hit.',
         'Jeder Pfeil zählt als 1 Treffer unabhängig vom getroffenen Segment.');
  String get cricketMinPlayers    =>
      _t('Cricket requires at least 2 players.', 'Cricket benötigt mindestens 2 Spieler.');

  // ── Cricket Game ─────────────────────────────────────────────────────────────
  String get bull                 => 'Bull';
  String get cricketMiss          => _t('Miss', 'Miss');
  String get cricketConfirmVisit  => _t('Done', 'Fertig');
  String get cricketDart          => _t('Dart', 'Pfeil');
  String get cricketScore         => _t('Score', 'Punkte');
  String get cricketMarks         => _t('Marks', 'Treffer');
  String get cricketQuit          => _t('Quit', 'Beenden');

  // ── Cricket Summary ──────────────────────────────────────────────────────────
  String get cricketSummaryTitle  => _t('Game Summary', 'Spielübersicht');
  String get cricketFieldsClosed  => _t('Fields closed', 'Felder geschlossen');
  String get cricketTotalScore    => _t('Total Score', 'Gesamtpunkte');
  String get cricketWins          =>  _t('wins!', 'hat gewonnen!');
  String cricketWinner(String name) => '🎯 $name $cricketWins';

  // ── Shanghai History ─────────────────────────────────────────────────────────
  String shanghaiGameInfo(String variant) =>
      _t('Shanghai · $variant', 'Shanghai · $variant');

  // ── Shanghai Setup ───────────────────────────────────────────────────────────
  String get shanghaiSetup        => _t('Shanghai Setup', 'Shanghai einrichten');
  String get shanghaiVariant      => _t('Variant', 'Variante');
  String get shanghaiClassic      => _t('Classic (1-9)', 'Klassisch (1-9)');
  String get shanghaiClockwise    => _t('Clockwise', 'Im Uhrzeigersinn');
  String get shanghaiSequential   => _t('Sequential', 'Sequenziell');
  String get shanghaiClassicDesc  =>
      _t('9 rounds, target advances from 1 to 9. Each player throws 3 darts at the active number per round.',
         '9 Runden, die Zielzahl steigt von 1 bis 9. Jeder Spieler wirft pro Runde 3 Pfeile auf die aktive Zahl.');
  String get shanghaiClockwiseDesc =>
      _t('One visit of 7 darts per player. The target advances by one with every dart, from 1 to 7.',
         'Eine Aufnahme mit 7 Pfeilen pro Spieler. Die Zielzahl steigt mit jedem Pfeil von 1 bis 7.');
  String get shanghaiSequentialDesc =>
      _t('Throw at 1 until you hit it, then move on to 2, and so on up to 20. First to finish wins.',
         'Wirf auf die 1, bis du sie triffst, dann auf die 2 usw. bis 20. Wer zuerst fertig ist, gewinnt.');
  String get shanghaiMinPlayers   =>
      _t('Shanghai requires at least 2 players.', 'Shanghai benötigt mindestens 2 Spieler.');

  // ── Shanghai Game ────────────────────────────────────────────────────────────
  String get shanghaiTarget       => _t('Target', 'Ziel');
  String get shanghaiMiss         => _t('Miss', 'Miss');
  String get shanghaiScore        => _t('Score', 'Punkte');
  String get shanghaiQuit         => _t('Quit', 'Beenden');
  String get shanghaiInstantWin   => _t('Shanghai! Instant win', 'Shanghai! Sofortsieg');
  String get shanghaiPending      => _t('Shanghai pending', 'Shanghai ausstehend');
  String get shanghaiHintTitle    => _t('Shanghai chance', 'Shanghai-Chance');
  String shanghaiHintStreak(int n) => n == 1
      ? _t('1 more hit in a row', 'noch 1 Treffer in Folge')
      : _t('$n more hits in a row', 'noch $n Treffer in Folge');

  // ── Shanghai Summary ─────────────────────────────────────────────────────────
  String get shanghaiSummaryTitle => _t('Game Summary', 'Spielübersicht');
  String get shanghaiTotalScore   => _t('Total Score', 'Gesamtpunkte');
  String shanghaiDartsUsed(int n) => dartsN(n);
  String get shanghaiWins         => _t('wins!', 'hat gewonnen!');
  String shanghaiWinner(String name) => '🎯 $name $shanghaiWins';

  // ── Around the Clock History ─────────────────────────────────────────────────
  String aroundClockGameInfo(String variant) =>
      _t('Around the Clock · $variant', 'Around the Clock · $variant');

  // ── Around the Clock Setup ───────────────────────────────────────────────────
  String get aroundClockSetup       => _t('Around the Clock Setup', 'Around the Clock einrichten');
  String get aroundClockVariant     => _t('Variant', 'Variante');
  String get aroundClockBasic       => _t('Basic', 'Standard');
  String get aroundClockFullSegments => _t('Full Segments', 'Alle Segmente');
  String get aroundClockSkipRules   => _t('Skip Rules', 'Überspringen');
  String get aroundClockBasicDesc   =>
      _t('Hit each number at least once, in clockwise order, then the Bull. First to the Bull wins.',
         'Triff jede Zahl mindestens einmal in der Reihenfolge im Uhrzeigersinn, dann das Bull. Wer zuerst das Bull trifft, gewinnt.');
  String get aroundClockFullSegmentsDesc =>
      _t('Hit Single, Double and Triple of each number before advancing to the next.',
         'Triff Single, Double und Triple jeder Zahl, bevor du zur nächsten weiterziehst.');
  String get aroundClockSkipRulesDesc =>
      _t('Double skips one field ahead, Triple skips two, and the Bull\'s Eye is a joker that skips the current field.',
         'Doppel überspringt ein Feld, Triple überspringt zwei, und das Bull\'s Eye ist ein Joker, der das aktuelle Feld überspringt.');
  String get aroundClockMinPlayers  =>
      _t('Select at least 1 player.', 'Wähle mindestens 1 Spieler aus.');

  // ── Around the Clock Game ────────────────────────────────────────────────────
  String get aroundClockTarget      => _t('Target', 'Ziel');
  String get aroundClockMiss        => _t('Miss', 'Miss');
  String get aroundClockQuit        => _t('Quit', 'Beenden');
  String get aroundClockProgress    => _t('Progress', 'Fortschritt');
  String aroundClockProgressN(int hit, int total) =>
      _t('$hit/$total hit', '$hit/$total getroffen');
  String get aroundClockHintTitle   => _t('Open', 'Offen');
  String get aroundClockJoker       => _t('Joker', 'Joker');

  // ── Around the Clock Summary ─────────────────────────────────────────────────
  String get aroundClockSummaryTitle => _t('Game Summary', 'Spielübersicht');
  String aroundClockDartsUsed(int n) => dartsN(n);
  String get aroundClockWins         => _t('wins!', 'hat gewonnen!');
  String aroundClockWinner(String name) => '🎯 $name $aroundClockWins';
}

// ── Delegate ──────────────────────────────────────────────────────────────────

/// Localizations delegate that supplies [AppLocalizations] for the supported
/// English and German locales.
class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'de'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
