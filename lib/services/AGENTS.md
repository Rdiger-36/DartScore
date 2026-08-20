# Services

Two subsystems that move a player's data off this device and back: **sync**, which merges two devices, and **backup**, which replaces one wholesale. Plus the device identity both rest on and the hand-written document picker. Owns the wire format, the transports and the import rules. Owns no layout: the screens are `../screens/sync_screen.dart` and `../screens/backup_screen.dart`.

## Entry Points

- `sync_codec.dart`, the wire format: binary packet, base45, fountain coded frames, `buildQrCode`
- `sync_service.dart`, the payload types, the Wi-Fi server and its client
- `transfer_invite.dart`, what a connection QR carries: the addresses, the port, the session token, an optional hotspot to join, and when the code stops being accepted
- `local_addresses.dart`, which of this device's addresses a peer could reach it on
- `local_hotspot.dart`, the network a transfer can raise for itself and the join onto one
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
- Timeouts come in two sizes, and mixing them up costs a transfer. While no address has answered, each candidate gets `_kProbeTimeout`, because the round is paid once per candidate. Once one has answered there is nothing left to try, so it gets `_kRequestTimeout`: cutting a slow answer short there only starts the search again against a server that has already seen the request, which is how a receiver gave up while the sender was showing its pairing dialog. The window before a peer is called unreachable is longer again when the peer raised the network, because the interface came up seconds ago and the route is still settling
- Nothing a peer sends is taken without a ceiling on it, and each ceiling sits where the bytes pile up rather than in one place at the front: `kMaxSyncTransferBytes` on a packet in either direction, `kMaxBackupTransferBytes` on a database, `kMaxInflatedSyncBytes` on what a packet may expand to when it is inflated. `SyncClient.fetchBytes` checks the announced length and then weighs what actually arrives, because a peer may name one length and send another, and `decodeSyncBytes` inflates through the chunked converter rather than `gzip.decode`, which would expand the whole bomb before anything could look at its size. All of it is reachable only after the pairing number was approved, so it is not what keeps a stranger out, it is what keeps an approved peer from spending this device's memory
- Bodies are collected in a `BytesBuilder`, never a `List<int>`. A growable int list holds a machine word per byte, so a database sized transfer would cost eight times its own length before any ceiling came into it
- The return leg is abandoned mid-body when it oversteps, rather than drained and then refused. The peer usually sees a broken connection instead of the 413, which is deliberate: the direction back is already allowed to fail silently, and draining an oversized body to be polite about the status is how a peer holds the socket for as long as it likes
- The pairing UI both transfers share (the scanner, the number dialog, the QR card) lives in `../widgets/wifi_pairing.dart`, and `buildQrCode` sits in `sync_codec.dart` beside the framing it belongs to
- QR payloads are base45 so a code can use its alphanumeric mode, which holds about a third more than the byte mode. Every character a code carries, headers included, has to stay inside that set, and the codes are built through `buildQrCode` because `QrCode.fromData` always picks the byte mode
- A connection code is a base45 encoded record, not delimited text. The format before it was three colon-separated fields, which held one address, could not gain one without breaking every parser, and would have shattered on the first SSID with a colon in it. A new field goes into the record; it never needs a new format
- The address in a connection code is picked by `local_addresses.dart`, never by taking the first interface the system lists. The lookup it replaced preferred names starting with `en`, which is Apple's Wi-Fi and no Android's, so on a phone it fell through to whatever came first: mobile data, a VPN, a bridge. The code parsed, scanned and could not connect. Interfaces are matched by name and addresses by private range, and both have to agree, because a VPN hands out addresses from exactly the same ranges as a router
- A code names several addresses, because the sending device cannot know which of its own the peer shares a network with. The client tries them in turn and keeps the first that answers. It keeps the **address**, never the whole URL: the token comes off the invitation on every call, and a remembered URL would let a later call reach the server under a token it was never given
- Probing costs the peer nothing because it only happens while the server is still in `waiting` or `pending`. Once a payload is approved it goes to one address, and the client does not go looking again
- Nothing answering at all is its own failure, `TransferUnreachableException`, and not a timeout. A timeout means the other device heard this one and the user has not confirmed yet; unreachable means nothing was ever heard, which is what a guest network with client isolation looks like from here. Telling the user to wait when there is nothing to wait for is how the old single message misled
- `SyncServer.start` looks for an address before it binds anything and throws `TransferStartException` rather than whatever the socket layer produced. Both reasons need different words on screen, and a screen that does not catch this is a button that spins for the rest of the session: that is exactly what the sync tab used to do
- Animated frames are LT coded: the receiver needs any set of frames slightly larger than the block count, not particular ones. Seeds are scrambled before use and each transfer starts at a random point in the seed space; both are load bearing, without them the overhead goes from about 1.25 to 4 times the block count

### The network a transfer raises for itself

- Two devices on no shared Wi-Fi and two devices on a guest network that keeps them apart are the same problem seen twice, and neither can be answered over a network somebody else owns. A network with nothing on it but the two phones has neither problem, which is what `local_hotspot.dart` is for
- **An iPhone can never host.** Apple gives no app a way to create an access point; `NEHotspotConfiguration` joins networks that already exist. So an Android phone always raises the network and an iPhone always joins, and iOS to iOS is not covered by this route at all: those two use a shared Wi-Fi, or the backup goes out through the share sheet and AirDrop carries it
- **Which device hosts says nothing about which way the data travels.** An Android phone can raise the network and be the one receiving. The route and the direction are set separately in the screens and must stay that way
- Gated at Android 13 so `NEARBY_WIFI_DEVICES` with `neverForLocation` covers the permission side. The same APIs below that want `ACCESS_FINE_LOCATION` and the location switch turned on, which is a declaration to file with the store and a question no darts app should be asking. Older devices simply do not see the option
- The network comes up **before** the server binds. The address a peer reaches this device on does not exist until the network does, and the server reads its addresses as it binds
- The Android join binds the process to the joined network, and that is not a detail. A transfer network carries no internet, so without `bindProcessToNetwork` Android keeps routing over mobile data and the sockets never reach the phone in the same room
- Everything raised has to be given back on every way out, the failures included: a hotspot left up costs battery and sits in everyone's Wi-Fi list, and a process still bound to a network that is gone has no route to anything at all. Both screens drop it from the start failure, the transfer failure, the back arrow and `dispose`, and the Activity does it again in `onDestroy`
- A transfer in flight is dropped when the screen is left, not asked about. The way most transfers are abandoned is the app going to the background, where a dialog is no help
- The failures are told apart because each is a different thing for the user to do: a running tethering hotspot is theirs to switch off, a refused permission is a dialog to open again, and no Wi-Fi at all is neither. `transferStartMessage` in `../widgets/wifi_pairing.dart` is the one place that mapping lives
- When the join cannot be made from inside the app, the SSID and the passphrase go on screen and the user picks the network in the system settings. A route that only works with a system API is a route that strands people the moment the API says no

### The Wi-Fi handshake

- The Wi-Fi server hands its payload to one peer, once, after the user confirms a pairing number. A request without the session token is refused without disturbing the user. The state may only reach `served` after the response has finished writing, or the screen shuts the socket down mid-body, and the same holds for `returned` and the answer to the peer
- **Writing the last byte is not delivering it.** `HttpResponse.close` hands the payload to the kernel; a peer can still have most of a database sitting in the buffers. So a one-way transfer is not over until the peer says it holds the whole thing: the payload response carries `SyncServer.confirmHeader` and the client posts an empty body back the moment the last byte is in. Taking the hand-over as the end is what let a sending screen stop the server and, worse, take the network it had raised down with it, leaving a receiver stuck at 39 percent with no error to show, because a network that disappears breaks no connection, it just goes quiet. A two-way exchange needs none of this, its return leg already is the confirmation, which is why the profile sync survived that and the database transfer did not
- The wait for that confirmation ends after `confirmationTimeout` and finishes anyway. A peer that vanished mid-body should not leave the screen unable to start anything else, and the payload is out either way
- For the same reason the receiver gives up on a body that has gone quiet for `_kBodyStallTimeout`, and calls it unreachable rather than a timeout. A screen counting percent forever is worse than a screen saying it failed
- `stop()` closes gracefully and only forces after `drainGrace`. Forcing destroys the socket rather than closing it, which throws away whatever the kernel had not sent yet
- The Wi-Fi transfer goes both ways in one pairing: after the payload is out the server stays up for the peer to POST its own side back, which is why `served` is a waiting state and not the end. A POST is only accepted once the payload has gone out, or anyone holding the token could push data in without ever being approved. The receiver always answers, with an empty body when it does not know the player, so the sender's wait ends on an answer rather than on the timeout
- The receiver posts its side back **before** it shows any import dialog. The sender is holding a socket open, and a user reading a confirmation is slower than any timeout worth having. The two directions do not depend on each other
- The return leg is built before the incoming packet is imported, so what goes back is this device's own history and not the sender's handed straight back. It is also allowed to fail silently: what was received is already stored, and the only thing lost is a direction the user can run again
- Both tabs import through the `_PacketImport` mixin, because the sender imports too now. A second copy of that flow is how the two directions would start disagreeing about what a name conflict means
- Only the Wi-Fi transport is two-way. A QR code is a picture on a screen and has no way back

## Anti-patterns

- Never build backup on `sync_codec.dart`, and never give a backup transfer `twoWay: true`
- Never let a device adopt an incoming device id, on restore or on import
- Never round `thrownAt`
- Never accumulate a peer's bytes without a ceiling, and never reach for `gzip.decode` on anything that came off a wire
- Never add a file picking package, and no Wi-Fi package either. The picker and the hotspot are hand-written to keep CocoaPods out of the iOS build, and `wifi_iot` in particular is unmaintained, iOS-stubbed and ships Kotlin sources this project's Gradle setup already had to cap two plugins over
- Never leave a raised network or a process binding behind on a path out. Both outlive the screen, and one of them takes the user's internet with it
- Never bump the packet format version for a field that can ride in the trailer

## Related Context

- The two screens that drive these: `../screens/AGENTS.md`
- The shared pairing UI: `../widgets/AGENTS.md`
