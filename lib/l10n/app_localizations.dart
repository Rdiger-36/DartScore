import 'package:flutter/material.dart';

// Usage: context.l10n.newGame
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)
        ?? const AppLocalizations(Locale('en'));
  }

  bool get _de => locale.languageCode == 'de';

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
  String get legsSets          => _t('Legs & Sets', 'Legs & Sets');
  String get legs              => _t('Legs', 'Legs');
  String get sets              => _t('Sets', 'Sets');
  String get players           => _t('Players', 'Spieler');
  String get noPlayersAvail    => _t('No players available.', 'Keine Spieler vorhanden.');
  String get addPlayerLink     => _t('Add player', 'Spieler anlegen');
  String get startGame         => _t('Start Game', 'Spiel starten');
  String get startOpenPlay     => _t('Start Solo Game', 'Solo Spiel starten');
  String get minOnePLayer      => _t('Select at least 1 player', 'Mindestens 1 Spieler auswählen');
  String get openPlayHint      => _t('1 player = Solo Game (no opponent)', '1 Spieler = Solo Spiel (kein Gegner)');
  String get soloLegsHint      => _t('Solo game plays 1 leg · 1 set', 'Solo Spiel: 1 Leg · 1 Set');
  String playerN(int n)        => _t('Player $n', 'Spieler $n');

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
  String get noCheckoutPossible => _t('No Check-out possible', 'Kein Check-out möglich');
  String dart(int n)           => _t('Dart $n', 'Dart $n');
  String get undoVisit         => _t('Undo last visit', 'Letzte Aufnahme rückgängig');
  String get redoVisit         => _t('Redo', 'Wiederherstellen');
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
  String get visits            => _t('Visits', 'Aufnahme');
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
  String get points            => _t('Points', 'Punkte');
  String gameSummaryInfo(int score, int l, int s) =>
      _t('$score pts · $l Legs · $s Sets', '$score Punkte · $l Legs · $s Sets');

  // ── Game setup / Team / Handicap ─────────────────────────────────────────
  String get handicap            => _t('Handicap', 'Handicap');
  String get handicapDesc        => _t('Individual Check-In / Check-Out rules per player', 'Individuelle Check-In / Check-Out Regeln pro Spieler');
  String get teamGame            => _t('Team Game', 'Team Spiel');
  String get teamGameDesc        => _t('Split players into teams. Each team shares one score.', 'Spieler auf Teams aufteilen. Jedes Team teilt sich einen Score.');
  String get done_               => _t('Done', 'Fertig');
  String get statsTooltip        => _t('Statistics', 'Statistik');
  String get statsLoadError      => _t('Statistics could not be loaded.', 'Statistiken konnten nicht geladen werden.');
  String get gameMode_           => _t('Mode', 'Modus');
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
         '$n neue Würfe seit letztem Sync');
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
  String get lastSyncPrefix    => _t('Last sync: ', 'Zuletzt sync: ');
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
  String restBleibt(int n) => _t('Remaining: $n', 'Rest bleibt $n');
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
}

// ── Delegate ──────────────────────────────────────────────────────────────────

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
