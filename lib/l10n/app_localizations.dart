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
    'Eine strengere Variante verlangt, dass du alle drei Segmente jedes Feldes triffst, bevor du weiterdarf: Single, Double und Triple. Erst dann kannst du zur nächsten Zahl im Uhrzeigersinn wechseln.\n\n'
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
