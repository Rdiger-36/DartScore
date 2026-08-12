import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import '../models/dart_throw.dart';

// ── Sync range ────────────────────────────────────────────────────────────────

/// How far back a sync reaches when collecting a player's throws.
///
/// Only the individual throws are cut off by this. Everything older is folded
/// into the stats snapshot that travels with the packet, so the receiver's
/// lifetime numbers come out the same whichever range was picked.
enum SyncRange {
  day(1),
  week(7),
  month(30),
  all(null);

  const SyncRange(this.days);

  /// Days of history covered, or null for the player's whole history.
  final int? days;
}

// ── Sync throw ────────────────────────────────────────────────────────────────

/// A single throw in the wire format exchanged during device-to-device sync.
///
/// This is a transport-only mirror of [DartThrow] without DB ids; [thrownAt]
/// (ms since epoch) doubles as the deduplication key when merging on the
/// receiving device.
class SyncThrow {
  final int score;
  final int dartsUsed;
  final int remainingBefore;
  final int thrownAt; // ms since epoch: used as dedup key
  final bool bust;
  final int leg;
  final int set;

  const SyncThrow({
    required this.score,
    required this.dartsUsed,
    required this.remainingBefore,
    required this.thrownAt,
    required this.bust,
    required this.leg,
    required this.set,
  });

  /// Builds a transport throw from a stored [DartThrow].
  factory SyncThrow.fromDartThrow(DartThrow t) => SyncThrow(
        score: t.score,
        dartsUsed: t.dartsUsed,
        remainingBefore: t.remainingBefore,
        thrownAt: t.thrownAt.millisecondsSinceEpoch,
        bust: t.bust,
        leg: t.leg,
        set: t.set,
      );

  /// Converts back to a storable [DartThrow] under the given game and player.
  DartThrow toDartThrow({required int gameId, required int playerId}) =>
      DartThrow(
        gameId: gameId,
        playerId: playerId,
        score: score,
        dartsUsed: dartsUsed,
        remainingBefore: remainingBefore,
        thrownAt: DateTime.fromMillisecondsSinceEpoch(thrownAt),
        bust: bust,
        leg: leg,
        set: set,
      );

  /// Serializes this throw to its JSON wire representation.
  Map<String, dynamic> toJson() => {
        'score': score,
        'darts_used': dartsUsed,
        'remaining_before': remainingBefore,
        'thrown_at': thrownAt,
        'bust': bust,
        'leg': leg,
        'set': set,
      };

  /// Parses a throw from JSON, tolerating bool-or-int `bust` encodings and
  /// rejecting out-of-range values to guard against corrupt or malicious data.
  factory SyncThrow.fromJson(Map<String, dynamic> j) {
    final score          = j['score'] as int;
    final dartsUsed      = j['darts_used'] as int;
    final remainingBefore = j['remaining_before'] as int;
    final thrownAt       = j['thrown_at'] as int;
    // 'bust' may be serialised as bool OR as int 0/1 depending on platform
    final bust = j['bust'] == true || j['bust'] == 1;
    final leg  = j['leg'] as int;
    final set  = j['set'] as int;

    // Bounds validation: reject obviously corrupt/malicious data
    if (score < 0 || score > 180) {
      throw FormatException('Invalid score: $score');
    }
    if (dartsUsed < 1 || dartsUsed > 3) {
      throw FormatException('Invalid dartsUsed: $dartsUsed');
    }
    if (remainingBefore < 0 || remainingBefore > 1001) {
      throw FormatException('Invalid remainingBefore: $remainingBefore');
    }
    if (leg < 1 || leg > 100) {
      throw FormatException('Invalid leg: $leg');
    }
    if (set < 1 || set > 100) {
      throw FormatException('Invalid set: $set');
    }

    return SyncThrow(
      score: score,
      dartsUsed: dartsUsed,
      remainingBefore: remainingBefore,
      thrownAt: thrownAt,
      bust: bust,
      leg: leg,
      set: set,
    );
  }
}

// ── Sync stats snapshot ───────────────────────────────────────────────────────

/// Aggregate per-player statistics carried alongside the throws in a sync,
/// so the receiver can display totals without recomputing from raw history.
class SyncStats {
  final int totalDarts;
  final int totalVisits;
  final double average;
  final int legsWon;
  final int highestVisit;
  final int busts;
  final int count180;

  const SyncStats({
    required this.totalDarts,
    required this.totalVisits,
    required this.average,
    required this.legsWon,
    required this.highestVisit,
    required this.busts,
    required this.count180,
  });

  /// Serializes these stats to their JSON wire representation.
  Map<String, dynamic> toJson() => {
        'total_darts': totalDarts,
        'total_visits': totalVisits,
        'average': average,
        'legs_won': legsWon,
        'highest_visit': highestVisit,
        'busts': busts,
        'count_180': count180,
      };

  /// Parses stats from JSON, defaulting any missing field to zero.
  factory SyncStats.fromJson(Map<String, dynamic> j) => SyncStats(
        totalDarts: j['total_darts'] as int? ?? 0,
        totalVisits: j['total_visits'] as int? ?? 0,
        average: (j['average'] as num?)?.toDouble() ?? 0,
        legsWon: j['legs_won'] as int? ?? 0,
        highestVisit: j['highest_visit'] as int? ?? 0,
        busts: j['busts'] as int? ?? 0,
        count180: j['count_180'] as int? ?? 0,
      );
}

// ── Sync origin ───────────────────────────────────────────────────────────────

/// The device id standing for data that arrived before devices were told
/// apart, whether it is stored locally or travelling in a packet.
///
/// It can never collide with a real [DeviceIdentity], which is always 16
/// characters long.
const String kLegacyOrigin = '';

/// One device's aggregated history as it travels in a packet.
///
/// A packet carries one of these per device it knows about, the sender
/// included. Keeping them apart is what lets a receiver drop its own
/// contribution back out: without it, data a device sent earlier comes home
/// folded into someone else's total and is counted twice.
class SyncOrigin {
  /// Which device the numbers were produced on, or [kLegacyOrigin].
  final String device;

  /// That device's stats snapshot, in the same shape as `local_stats_json`.
  final String snapshotJson;

  const SyncOrigin({required this.device, required this.snapshotJson});

  /// Serializes this origin to its JSON wire representation.
  Map<String, dynamic> toJson() => {
        'device':   device,
        'snapshot': snapshotJson,
      };

  /// Parses an origin from JSON.
  factory SyncOrigin.fromJson(Map<String, dynamic> j) => SyncOrigin(
        device:       j['device'] as String? ?? kLegacyOrigin,
        snapshotJson: j['snapshot'] as String? ?? '',
      );
}

// ── Sync packet ───────────────────────────────────────────────────────────────

/// The full payload transferred for one player during a sync: identity,
/// favorite doubles, aggregate [stats], the list of [throws], and an optional
/// full historical stats snapshot. [version] guards the wire format.
class SyncPacket {
  final int version;
  final String senderDevice;

  /// The sending device's [DeviceIdentity], or empty when the packet came from
  /// an app version that had none.
  final String senderDeviceId;

  final String playerUuid;
  final String playerName;
  final String favoriteDoubles;
  final SyncStats stats;
  final List<SyncThrow> throws;

  /// Every device's snapshot separately, the sender's included.
  ///
  /// Empty in packets from before devices were told apart; [localStatsJson] is
  /// then the only snapshot there is.
  final List<SyncOrigin> origins;

  /// Which device produced each entry of [throws], in the same order.
  ///
  /// Empty when the packet does not say, which means the sender is the only
  /// device the throws can be attributed to. A device passing on what it
  /// received keeps the original attribution here, so the data can find its
  /// way home without arriving as the passing device's own.
  final List<String> throwOrigins;

  // Full historical stats snapshot (local_stats_json): includes data from cleared game history.
  //
  // Everything in [origins] added together. Kept because an app version that
  // does not know about origins reads this field and nothing else; a receiver
  // that does know ignores it in favour of the breakdown.
  final String? localStatsJson;
  /// How far back [throws] reaches, in days, or null when it holds every throw.
  ///
  /// Only the individual throws are cut off by this; the throws left out were
  /// folded into [localStatsJson] before sending, so no aggregate number is
  /// lost by picking a shorter range.
  final int? rangeDays;

  const SyncPacket({
    required this.version,
    required this.senderDevice,
    required this.playerUuid,
    required this.playerName,
    required this.favoriteDoubles,
    required this.stats,
    required this.throws,
    this.senderDeviceId = '',
    this.origins = const [],
    this.throwOrigins = const [],
    this.localStatsJson,
    this.rangeDays,
  });

  /// Which device the throw at [index] was played on, falling back to the
  /// sender for a packet that does not attribute its throws.
  String originOfThrow(int index) => index < throwOrigins.length
      ? throwOrigins[index]
      : senderDeviceId;

  /// Serializes this packet to its JSON wire representation.
  Map<String, dynamic> toJson() => {
        'version': version,
        'sender_device': senderDevice,
        if (senderDeviceId.isNotEmpty) 'sender_device_id': senderDeviceId,
        'player_uuid': playerUuid,
        'player_name': playerName,
        'favorite_doubles': favoriteDoubles,
        'stats': stats.toJson(),
        'throws': throws.map((t) => t.toJson()).toList(),
        if (origins.isNotEmpty)
          'origins': origins.map((o) => o.toJson()).toList(),
        if (throwOrigins.isNotEmpty) 'throw_origins': throwOrigins,
        if (localStatsJson != null) 'local_stats_json': localStatsJson,
        if (rangeDays != null) 'range_days': rangeDays,
      };

  /// Parses a packet from JSON, applying defaults for optional fields.
  factory SyncPacket.fromJson(Map<String, dynamic> j) => SyncPacket(
        version: j['version'] as int,
        senderDevice: j['sender_device'] as String? ?? 'Unknown',
        senderDeviceId: j['sender_device_id'] as String? ?? '',
        playerUuid: j['player_uuid'] as String,
        playerName: j['player_name'] as String,
        favoriteDoubles: j['favorite_doubles'] as String? ?? '',
        stats: SyncStats.fromJson(
            j['stats'] as Map<String, dynamic>? ?? {}),
        throws: (j['throws'] as List? ?? [])
            .map((t) => SyncThrow.fromJson(t as Map<String, dynamic>))
            .toList(),
        origins: (j['origins'] as List? ?? [])
            .map((o) => SyncOrigin.fromJson(o as Map<String, dynamic>))
            .toList(),
        throwOrigins: (j['throw_origins'] as List? ?? [])
            .map((o) => o as String)
            .toList(),
        localStatsJson: j['local_stats_json'] as String?,
        rangeDays: j['range_days'] as int?,
      );

  /// A copy of this packet under a different [playerName], used when the
  /// receiver resolves a name clash by importing under an alternative name.
  SyncPacket withName(String name) => SyncPacket(
        version: version,
        senderDevice: senderDevice,
        senderDeviceId: senderDeviceId,
        playerUuid: playerUuid,
        playerName: name,
        favoriteDoubles: favoriteDoubles,
        stats: stats,
        throws: throws,
        origins: origins,
        throwOrigins: throwOrigins,
        localStatsJson: localStatsJson,
        rangeDays: rangeDays,
      );
}

// ── Server ────────────────────────────────────────────────────────────────────

/// Marks the QR code that carries a Wi-Fi transfer's connection details.
const String kSyncWifiPrefix = 'DSW:';

/// How far a Wi-Fi transfer has got, from the sender's side.
enum SyncServerState {
  /// Bound and listening, nobody has asked yet.
  waiting,

  /// A peer with the right token is asking to be let in.
  pending,

  /// The user approved, the payload goes out on the next request.
  approved,

  /// The payload has been handed over, and the peer's own is now awaited.
  served,

  /// The peer has answered with its side of the exchange. Whether that answer
  /// carried anything is [SyncServer.returnedPayload].
  returned,

  /// The user turned the peer away.
  rejected,
}

/// Where and how a peer reaches a running [SyncServer].
class SyncConnection {
  final String ip;
  final int port;

  /// Random per session, and the only way past the server's front door.
  final String token;

  const SyncConnection(this.ip, this.port, this.token);

  /// The connection QR's contents. Uppercase and punctuation only, so the code
  /// can use the dense alphanumeric mode.
  String get qrPayload => '$kSyncWifiPrefix$ip:$port:$token';

  /// Parses what [qrPayload] produced, or null if [raw] is something else.
  static SyncConnection? parse(String raw) {
    if (!raw.startsWith(kSyncWifiPrefix)) return null;
    final parts = raw.substring(kSyncWifiPrefix.length).split(':');
    if (parts.length != 3) return null;
    final port = int.tryParse(parts[1]);
    if (port == null) return null;
    return SyncConnection(parts[0], port, parts[2]);
  }
}

/// Hosts a one-shot local HTTP server that exchanges a payload with one peer
/// over the local network, once the user has confirmed the peer is the right
/// one.
///
/// A peer needs the token from the connection QR to get any answer at all,
/// which is what keeps the payload from anyone else who happens to be on the
/// same Wi-Fi. Past that door it still waits: the first request only starts a
/// pairing, both devices show the same four digits, and the payload is released
/// when the user approves it here.
///
/// The exchange goes both ways in one pairing. After the payload has gone out
/// the server stays up briefly for the peer to post its own side back, which is
/// what makes two devices reconcile in one confirmation instead of two runs
/// with the roles swapped. The peer always answers, with an empty body when it
/// has nothing to give, so the wait ends on an answer rather than on the
/// timeout. Then the server stops rather than staying open for the rest of the
/// session.
class SyncServer {
  /// How long to wait for the peer's side after the payload has gone out. Only
  /// reached when the peer disappears mid-exchange; an ordinary run answers at
  /// once.
  static const Duration returnTimeout = Duration(seconds: 90);

  HttpServer? _server;
  String? _payload;
  String? _returned;
  Timer? _returnTimer;
  String _token = '';
  String _pin = '';

  /// What the peer sent back, or null when it had nothing for this device.
  /// Only meaningful once the state is [SyncServerState.returned].
  String? get returnedPayload =>
      _returned == null || _returned!.isEmpty ? null : _returned;

  final ValueNotifier<SyncServerState> _state =
      ValueNotifier(SyncServerState.waiting);

  /// Follows the transfer for the sender's screen.
  ValueListenable<SyncServerState> get state => _state;

  /// The four digits both devices show while the transfer is being confirmed.
  String get pin => _pin;

  /// Whether the server is currently bound and listening.
  bool get isRunning => _server != null;

  /// Binds the server on a free port, ready to serve [payload], and returns
  /// where the peer should connect.
  Future<SyncConnection> start(String payload) async {
    final random = Random.secure();

    _payload = payload;
    _returned = null;
    _token = List.generate(
        16, (_) => _kTokenAlphabet[random.nextInt(_kTokenAlphabet.length)]).join();
    _pin = random.nextInt(10000).toString().padLeft(4, '0');
    _state.value = SyncServerState.waiting;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen((req) => _handle(req).catchError((_) {}),
        onError: (_) {}, cancelOnError: false);

    return SyncConnection(await _localIp(), _server!.port, _token);
  }

  /// Releases the payload to the waiting peer.
  void approve() {
    if (_state.value == SyncServerState.pending) {
      _state.value = SyncServerState.approved;
    }
  }

  /// Turns the waiting peer away.
  void reject() {
    if (_state.value == SyncServerState.pending) {
      _state.value = SyncServerState.rejected;
    }
  }

  /// Answers one request according to how far the pairing has got.
  ///
  /// The peer polls rather than holding the connection open, which keeps a
  /// request from timing out while the user is still looking at their screen.
  Future<void> _handle(HttpRequest req) async {
    final response = req.response
      ..headers.contentType = ContentType.json;

    // Anything without the token gets nothing, and does not disturb the user.
    if (req.uri.path != '/$_token') {
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }

    if (req.method == 'POST') {
      await _handleReturn(req, response);
      return;
    }

    if (_state.value == SyncServerState.waiting) {
      _state.value = SyncServerState.pending;
    }

    switch (_state.value) {
      case SyncServerState.rejected:
        response.statusCode = HttpStatus.forbidden;
        await response.close();
      case SyncServerState.approved:
      case SyncServerState.served:
        response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          ..headers.set(HttpHeaders.connectionHeader, 'close')
          ..write(_payload);

        // The state has to wait for the last byte. Announcing the hand-over
        // any earlier lets the screen shut the server down mid-response, and
        // a payload of a few tens of kilobytes is still in flight at that
        // point, so the receiver sees the connection break instead.
        await response.close();
        if (_state.value != SyncServerState.served) {
          _state.value = SyncServerState.served;
          _startReturnTimer();
        }
      case SyncServerState.returned:
        // The exchange is over. Nothing is served twice.
        response.statusCode = HttpStatus.gone;
        await response.close();
      case SyncServerState.waiting:
      case SyncServerState.pending:
        response
          ..statusCode = HttpStatus.accepted
          ..write(jsonEncode({'pin': _pin}));
        await response.close();
    }
  }

  /// Takes the peer's side of the exchange.
  ///
  /// Only once this device's own payload is out: before that there is no
  /// approved peer, and taking a packet from an unconfirmed one would let
  /// anyone holding the token push data in. An empty body is a valid answer and
  /// means the peer had nothing to send.
  Future<void> _handleReturn(HttpRequest req, HttpResponse response) async {
    if (_state.value != SyncServerState.served) {
      response.statusCode = HttpStatus.conflict;
      await response.close();
      return;
    }

    final body = await utf8.decoder.bind(req).join();
    _returned = body;

    response.statusCode = HttpStatus.ok;

    // Same reason as the payload above, the other way round: the screen reacts
    // to `returned` by shutting the server down, so the answer has to be fully
    // written before the state says so, or the peer never sees it.
    await response.close();
    _returnTimer?.cancel();
    _state.value = SyncServerState.returned;
  }

  /// Gives up waiting for the peer's side after [returnTimeout], so a peer that
  /// vanished mid-exchange does not leave the sender's screen waiting forever.
  void _startReturnTimer() {
    _returnTimer?.cancel();
    _returnTimer = Timer(returnTimeout, () {
      if (_state.value == SyncServerState.served) {
        _returned = null;
        _state.value = SyncServerState.returned;
      }
    });
  }

  /// Stops the server and clears the payload and the session secrets.
  ///
  /// The state is deliberately left where it was. A screen shutting down calls
  /// this and then [dispose] without waiting, so a write here would land on a
  /// notifier that is already gone; [start] resets the state anyway.
  Future<void> stop() async {
    _returnTimer?.cancel();
    _returnTimer = null;
    await _server?.close(force: true);
    _server = null;
    _payload = null;
    _token = '';
    _pin = '';
  }

  /// Releases the state notifier. Call when the owning screen goes away.
  void dispose() {
    _returnTimer?.cancel();
    _state.dispose();
  }

  /// Characters a session token is built from: unambiguous, and all inside the
  /// QR alphanumeric set so the connection code stays dense.
  static const _kTokenAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Best-effort lookup of the device's LAN IPv4 address, preferring `en*`
  /// interfaces and falling back to loopback when none is found.
  static Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLinkLocal: false);
      for (final iface in interfaces) {
        if (iface.name.startsWith('en')) {
          for (final addr in iface.addresses) {
            if (!addr.isLoopback) return addr.address;
          }
        }
      }
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }
}

// ── Client ────────────────────────────────────────────────────────────────────

/// Raised when the sending device turned the transfer down.
class SyncRejectedException implements Exception {
  const SyncRejectedException();

  @override
  String toString() => 'The other device declined the transfer';
}

/// Fetches a payload from a peer's [SyncServer] over the local network.
class SyncClient {
  /// How long to keep asking before giving up on the user confirming.
  static const _kTimeout = Duration(minutes: 2);

  /// How long to wait between asking again.
  static const _kPollInterval = Duration(milliseconds: 600);

  /// Connects to [connection] and returns the payload once the sending device
  /// has approved the transfer.
  ///
  /// [onPin] is called with the four digits as soon as the server names them,
  /// so the receiver can show the user what to compare against.
  Future<String> fetch(SyncConnection connection,
      {void Function(String pin)? onPin}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);

    final deadline = DateTime.now().add(_kTimeout);
    var announced = false;

    try {
      while (true) {
        final url =
            Uri.parse('http://${connection.ip}:${connection.port}/${connection.token}');
        final res = await (await client.getUrl(url))
            .close()
            .timeout(const Duration(seconds: 10));
        final body = await res.transform(utf8.decoder).join();

        switch (res.statusCode) {
          case HttpStatus.ok:
            return body;
          case HttpStatus.forbidden:
            throw const SyncRejectedException();
          case HttpStatus.accepted:
            if (!announced) {
              final pin = (jsonDecode(body) as Map<String, dynamic>)['pin'];
              if (pin is String) {
                announced = true;
                onPin?.call(pin);
              }
            }
          default:
            throw Exception('Server responded with ${res.statusCode}');
        }

        if (DateTime.now().isAfter(deadline)) {
          throw TimeoutException('The transfer was not confirmed in time');
        }
        await Future<void>.delayed(_kPollInterval);
      }
    } finally {
      client.close(force: true);
    }
  }

  /// Sends this device's own side of the exchange back to [connection].
  ///
  /// Always called after a successful [fetch], with an empty [payload] when
  /// there is nothing to return: the sender is waiting on an answer either way,
  /// and an empty one ends its wait immediately instead of after the timeout.
  ///
  /// A failure here is deliberately not fatal to the caller. The data this
  /// device received is already stored, and the only thing lost is the other
  /// direction, which the user can run again.
  Future<void> post(SyncConnection connection, String payload) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);

    try {
      final url = Uri.parse(
          'http://${connection.ip}:${connection.port}/${connection.token}');
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.text;
      request.write(payload);

      final res = await request.close().timeout(const Duration(seconds: 30));
      await res.drain<void>();
      if (res.statusCode != HttpStatus.ok) {
        throw Exception('Server responded with ${res.statusCode}');
      }
    } finally {
      client.close(force: true);
    }
  }
}
