# Services

Two subsystems that move a player's data off this device and back: **sync**, which merges two devices, and **backup**, which replaces one wholesale. Plus the device identity both rest on and the hand-written document picker. Owns the wire format, the transports and the import rules. Owns no layout: the screens are `../screens/sync_screen.dart` and `../screens/backup_screen.dart`.

## Entry Points

- `sync_codec.dart`, the wire format: binary packet, base45, fountain coded frames, `buildQrCode`
- `sync_service.dart`, the payload types, the Wi-Fi server and its client
- `device_identity.dart`, this device's sync id, the attribution key for all origin tracking
- `backup_service.dart`, writing the database out as one file and reading one back in
- `document_picker.dart`, the Dart side of the hand-written system file picker

Native halves: `ios/Runner/DocumentPickerHandler.swift` and `android/app/src/main/kotlin/.../MainActivity.kt`.

## The one rule under all of it

Sync merges, backup replaces. They must not be built on each other. A sync folds what it cannot carry into snapshots; a restore takes over this device, identity included.

## Backup

- A backup is the SQLite file itself, not a dump of it. That keeps a restore exact and costs no second serialiser to keep in step with the schema. The price is that a file from a newer schema version cannot be read, which is why `inspectBackup` reports the version and the service refuses anything above `DbHelper.schemaVersion`
- `prepareBackup` checkpoints the write-ahead log before the file is copied. Without it a copy of `dartscore.db` alone misses whatever still sits in the `-wal` companion, and nothing about the resulting backup looks wrong until someone needs it. For the same reason a restore deletes `-wal` and `-shm`: they belong to the replaced database
- A backup carries the device id from `DeviceIdentity` in its `app_meta` table, and the restoring device keeps its own. Adopting it was tried and is wrong: two live devices on one id can never sync again, because each takes the other's data for its own and drops it
- A game played on a device carries **no** device id: `origin_device` is null and null means "mine". So a database restored onto a different phone arrives claiming a history that phone never played. `attributeRestoredHistory` stamps the source's id onto it, which is what keeps the two devices able to sync afterwards. Only when the ids differ: restoring one's own backup on the same phone must leave it alone, or the history loses what only a device's own games carry through a sync (perfect legs, best game average, games played)
- Backup is not sync and must not be built on `sync_codec.dart`
- Where the file goes is the platform's business. `share_plus` on the way out, the document picker on the way back in, so iCloud Drive, Google Drive, Files and mail are all covered without the app hosting anything or knowing which one was used
- A backup can also go straight to another device over Wi-Fi, on the same `SyncServer` the profile sync uses, but always with `twoWay: false`: a database replaces the device that takes it, so there is nothing it could hand back. Its connection code carries `kBackupWifiPrefix` rather than `kSyncWifiPrefix`, and each screen refuses the other's code. The two do opposite things, one merges and one replaces, and a code read in the wrong screen has to fail rather than half work
- Both halves of the backup screen offer the same two routes, a file or the other device. Creating a backup asks which in a dialog and is done; restoring walks through its own screens first, what it costs, the offer to save the current data, then the source, and only then the dialog naming what was found in the file. The asymmetry is the point: one of the two is not undoable
- What a database holds is described in the same five lines wherever it appears, on the way out beside the code and on the way in beside the question: when, from which device, players, games, size. `app_meta.device_label` carries the "iPhone"/"Android" name for the user to read, and `describeLocal` reports the live database the way `inspectBackup` reports a file, so the two ends of a transfer never describe it differently
- The document picker is written by hand in `DocumentPickerHandler.swift` and `MainActivity.kt` because every file picking package still requires CocoaPods on iOS, which this project deliberately does not use. Adding one back would undo that. A new Swift file also has to be added to the `DartScore` target in `project.pbxproj`; it is not picked up on its own
- The picked file is always a copy in a cache directory, on both platforms. It is meant to be used at once and thrown away, not kept

## Sync

### What travels

- A sync carries a player's whole history whatever range the user picks. Only the individual throws are cut off; everything left out is folded into the stats snapshot that travels along, and what the throws that do travel cannot carry is folded in too. Break either fold and the receiving device's lifetime numbers read low, which is invisible in the app
- A synced throw arrives without its game: every throw of an import lands in one hidden sync-game that has no start score and counts for no game played. So everything a game knows about itself has to travel folded into the snapshot, through `addTravellingGameFacts`: the perfect legs, the best game average, the games played, finished and won, and the dartboard segments. None of it can be recomputed on the other side, and none of it can double count there, because the sync-game contributes nothing to any of it
- The range cuts this device's own history along whole games, not at the throw. Half a game has no perfect leg and no average worth the name, and a game cut down the middle would be claimed twice, once folded and once travelling. Throws that came from elsewhere are cut at the throw instead: their games are already aggregates, so there is nothing left to keep whole

### Origin tracking

- Every device has an id from `DeviceIdentity`, and every piece of a player's history is filed under the device it was played on: `games.origin_device` for throws, `player_origin_stats` for aggregates, with `players.local_stats_json` holding this device's own and nothing else. That split is what makes syncing in both directions safe, and every rule below rests on it
- A throw is only ever folded into the snapshot of the device it was played on, and a device passing on what it received keeps the original attribution. Fold foreign throws into the sending device's own total and they come home to whoever played them as somebody else's numbers, on top of the throws still sitting there, which is a silent overcount
- The receiver drops anything a packet attributes to its own id, throws and snapshot alike. Nothing else prevents a full round trip from counting the same leg twice
- An incoming packet is authoritative for what the sending device holds, and for that device only: its throws (`games.origin_device`) and its snapshot are deleted before importing, otherwise a snapshot covering throws an earlier sync already delivered counts them again. What a third device sent is left alone, and a snapshot only passed on by the sender is kept when the local copy covers more darts
- The legacy bucket (`origin_device = ''`) is data from before devices were told apart. It travels as throws whatever the range asks for, because there is no snapshot it could safely be folded into, and an import replaces it wholesale. One sync per device pair clears it for good
- `thrownAt` in milliseconds is the deduplication key on import. Do not round it
- A visit's `checkoutDarts` travels in two bits of the flag byte because the receiver cannot decide it: the individual darts stay behind, and the hidden sync-game's check-out rule is not the one the visit was played under. A sender that predates the bits leaves them clear, which reads as "no attempt" rather than as a broken packet
- The origin fields ride in a trailer after the throws rather than in a new format version, so an app that predates them reads the packet up to the last throw and imports it instead of refusing a version number it does not know. `local_stats_json` in a packet is every origin added together, kept for exactly those readers

### Transports

- All three transports build on the same bytes from `sync_codec.dart`. What differs is only the framing: base45 for one code, fountain coded frames for an animated one, HTTP for the Wi-Fi transfer
- `SyncServer` carries bytes, not text, because the backup transfer rides on it and a database is binary. `SyncClient.fetch` is only `fetchBytes` with a utf8 decode on top
- The payload goes out in slices with a flush between them, and both sides report how far it has got: `SyncServer.progress` for the sender, `fetchBytes(onProgress:)` for the receiver. A database takes long enough that one write and a still screen read as a transfer that died. `fetchBytes(onPin:)` is not optional either, a receiver that does not show the pairing number leaves the user nothing to compare
- The pairing UI both transfers share (the scanner, the number dialog, the QR card) lives in `../widgets/wifi_pairing.dart`, and `buildQrCode` sits in `sync_codec.dart` beside the framing it belongs to
- QR payloads are base45 so a code can use its alphanumeric mode, which holds about a third more than the byte mode. Every character a code carries, headers included, has to stay inside that set, and the codes are built through `buildQrCode` in `sync_screen.dart` because `QrCode.fromData` always picks the byte mode
- Animated frames are LT coded: the receiver needs any set of frames slightly larger than the block count, not particular ones. Seeds are scrambled before use and each transfer starts at a random point in the seed space; both are load bearing, without them the overhead goes from about 1.25 to 4 times the block count

### The Wi-Fi handshake

- The Wi-Fi server hands its payload to one peer, once, after the user confirms a pairing number. A request without the session token is refused without disturbing the user. The state may only reach `served` after the response has finished writing, or the screen shuts the socket down mid-body, and the same holds for `returned` and the answer to the peer
- The Wi-Fi transfer goes both ways in one pairing: after the payload is out the server stays up for the peer to POST its own side back, which is why `served` is a waiting state and not the end. A POST is only accepted once the payload has gone out, or anyone holding the token could push data in without ever being approved. The receiver always answers, with an empty body when it does not know the player, so the sender's wait ends on an answer rather than on the timeout
- The receiver posts its side back **before** it shows any import dialog. The sender is holding a socket open, and a user reading a confirmation is slower than any timeout worth having. The two directions do not depend on each other
- The return leg is built before the incoming packet is imported, so what goes back is this device's own history and not the sender's handed straight back. It is also allowed to fail silently: what was received is already stored, and the only thing lost is a direction the user can run again
- Both tabs import through the `_PacketImport` mixin, because the sender imports too now. A second copy of that flow is how the two directions would start disagreeing about what a name conflict means
- Only the Wi-Fi transport is two-way. A QR code is a picture on a screen and has no way back

## Anti-patterns

- Never build backup on `sync_codec.dart`, and never give a backup transfer `twoWay: true`
- Never let a device adopt an incoming device id, on restore or on import
- Never round `thrownAt`
- Never add a file picking package. The picker is hand-written to keep CocoaPods out of the iOS build
- Never bump the packet format version for a field that can ride in the trailer

## Related Context

- The two screens that drive these: `../screens/AGENTS.md`
- The shared pairing UI: `../widgets/AGENTS.md`
