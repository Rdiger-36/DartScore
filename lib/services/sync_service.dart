import 'dart:convert';
import 'dart:io';
import '../models/dart_throw.dart';

// ── Sync throw ────────────────────────────────────────────────────────────────

class SyncThrow {
  final int score;
  final int dartsUsed;
  final int remainingBefore;
  final int thrownAt; // ms since epoch — used as dedup key
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

  factory SyncThrow.fromDartThrow(DartThrow t) => SyncThrow(
        score: t.score,
        dartsUsed: t.dartsUsed,
        remainingBefore: t.remainingBefore,
        thrownAt: t.thrownAt.millisecondsSinceEpoch,
        bust: t.bust,
        leg: t.leg,
        set: t.set,
      );

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

  Map<String, dynamic> toJson() => {
        'score': score,
        'darts_used': dartsUsed,
        'remaining_before': remainingBefore,
        'thrown_at': thrownAt,
        'bust': bust,
        'leg': leg,
        'set': set,
      };

  factory SyncThrow.fromJson(Map<String, dynamic> j) {
    final score          = j['score'] as int;
    final dartsUsed      = j['darts_used'] as int;
    final remainingBefore = j['remaining_before'] as int;
    final thrownAt       = j['thrown_at'] as int;
    // 'bust' may be serialised as bool OR as int 0/1 depending on platform
    final bust = j['bust'] == true || j['bust'] == 1;
    final leg  = j['leg'] as int;
    final set  = j['set'] as int;

    // Bounds validation — reject obviously corrupt/malicious data
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

  Map<String, dynamic> toJson() => {
        'total_darts': totalDarts,
        'total_visits': totalVisits,
        'average': average,
        'legs_won': legsWon,
        'highest_visit': highestVisit,
        'busts': busts,
        'count_180': count180,
      };

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

class SyncPacket {
  final int version;
  final String senderDevice;
  final String playerUuid;
  final String playerName;
  final String favoriteDoubles;
  final SyncStats stats;
  final List<SyncThrow> throws;
  // Full historical stats snapshot (local_stats_json) — includes data from cleared game history.
  final String? localStatsJson;

  const SyncPacket({
    required this.version,
    required this.senderDevice,
    required this.playerUuid,
    required this.playerName,
    required this.favoriteDoubles,
    required this.stats,
    required this.throws,
    this.localStatsJson,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'sender_device': senderDevice,
        'player_uuid': playerUuid,
        'player_name': playerName,
        'favorite_doubles': favoriteDoubles,
        'stats': stats.toJson(),
        'throws': throws.map((t) => t.toJson()).toList(),
        if (localStatsJson != null) 'local_stats_json': localStatsJson,
      };

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
      );
}

// ── Server ────────────────────────────────────────────────────────────────────

class SyncServer {
  HttpServer? _server;
  String? _payload;

  bool get isRunning => _server != null;

  Future<(String ip, int port)> start(SyncPacket packet) async {
    _payload = jsonEncode(packet.toJson());
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(_handle, onError: (_) {}, cancelOnError: false);
    final ip = await _localIp();
    return (ip, _server!.port);
  }

  void _handle(HttpRequest req) {
    req.response
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..headers.add('Access-Control-Allow-Origin', '*')
      ..write(_payload)
      ..close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _payload = null;
  }

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

class SyncClient {
  Future<SyncPacket> fetch(String ip, int port) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('http://$ip:$port/'));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        throw Exception('Server antwortete mit ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return SyncPacket.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }
}
