import 'dart:convert';
import 'dart:io';
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

// ── Sync packet ───────────────────────────────────────────────────────────────

/// The full payload transferred for one player during a sync: identity,
/// favorite doubles, aggregate [stats], the list of [throws], and an optional
/// full historical stats snapshot. [version] guards the wire format.
class SyncPacket {
  final int version;
  final String senderDevice;
  final String playerUuid;
  final String playerName;
  final String favoriteDoubles;
  final SyncStats stats;
  final List<SyncThrow> throws;
  // Full historical stats snapshot (local_stats_json): includes data from cleared game history.
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
    this.localStatsJson,
    this.rangeDays,
  });

  /// Serializes this packet to its JSON wire representation.
  Map<String, dynamic> toJson() => {
        'version': version,
        'sender_device': senderDevice,
        'player_uuid': playerUuid,
        'player_name': playerName,
        'favorite_doubles': favoriteDoubles,
        'stats': stats.toJson(),
        'throws': throws.map((t) => t.toJson()).toList(),
        if (localStatsJson != null) 'local_stats_json': localStatsJson,
        if (rangeDays != null) 'range_days': rangeDays,
      };

  /// Parses a packet from JSON, applying defaults for optional fields.
  factory SyncPacket.fromJson(Map<String, dynamic> j) => SyncPacket(
        version: j['version'] as int,
        senderDevice: j['sender_device'] as String? ?? 'Unknown',
        playerUuid: j['player_uuid'] as String,
        playerName: j['player_name'] as String,
        favoriteDoubles: j['favorite_doubles'] as String? ?? '',
        stats: SyncStats.fromJson(
            j['stats'] as Map<String, dynamic>? ?? {}),
        throws: (j['throws'] as List? ?? [])
            .map((t) => SyncThrow.fromJson(t as Map<String, dynamic>))
            .toList(),
        localStatsJson: j['local_stats_json'] as String?,
        rangeDays: j['range_days'] as int?,
      );

  /// A copy of this packet under a different [playerName], used when the
  /// receiver resolves a name clash by importing under an alternative name.
  SyncPacket withName(String name) => SyncPacket(
        version: version,
        senderDevice: senderDevice,
        playerUuid: playerUuid,
        playerName: name,
        favoriteDoubles: favoriteDoubles,
        stats: stats,
        throws: throws,
        localStatsJson: localStatsJson,
        rangeDays: rangeDays,
      );
}

// ── Server ────────────────────────────────────────────────────────────────────

/// Hosts a one-shot local HTTP server that serves a [SyncPacket] as JSON to the
/// peer device over the local network. The sender shows its IP/port (e.g. via
/// QR) and the [SyncClient] on the other device fetches the payload.
class SyncServer {
  HttpServer? _server;
  String? _payload;

  /// Whether the server is currently bound and listening.
  bool get isRunning => _server != null;

  /// Binds the server on a free port, serving [packet] as JSON, and returns the
  /// local IP and chosen port for the peer to connect to.
  Future<(String ip, int port)> start(SyncPacket packet) async {
    _payload = jsonEncode(packet.toJson());
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_handle, onError: (_) {}, cancelOnError: false);
    final ip = await _localIp();
    return (ip, _server!.port);
  }

  /// Responds to every request with the stored JSON payload and permissive CORS.
  void _handle(HttpRequest req) {
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..headers.add('Access-Control-Allow-Origin', '*')
      ..write(_payload)
      ..close();
  }

  /// Stops the server and clears the cached payload.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _payload = null;
  }

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

/// Fetches a [SyncPacket] from a peer device's [SyncServer] over the local network.
class SyncClient {
  /// Performs an HTTP GET against the peer at [ip]:[port] and decodes the
  /// returned [SyncPacket]. Times out after 10 seconds and always closes the
  /// underlying client.
  Future<SyncPacket> fetch(String ip, int port) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('http://$ip:$port/'));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw Exception('Server responded with ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return SyncPacket.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }
}
