import 'dart:math';

class Player {
  final int? id;
  final String name;
  final String favoriteDoubles;
  final bool isDeleted;
  final bool isPrimary;
  final String uuid;
  final int? lastSyncedAt;
  final String? syncedStats;    // JSON snapshot from last sync (other device)
  final String? localStatsJson; // Persistent local stats accumulated over cleared games

  Player({
    this.id,
    required this.name,
    this.favoriteDoubles = '',
    this.isDeleted = false,
    this.isPrimary = false,
    String? uuid,
    this.lastSyncedAt,
    this.syncedStats,
    this.localStatsJson,
  }) : uuid = uuid?.isNotEmpty == true ? uuid! : _newUuid();

  /// Single selected favorite double (first entry, ignores any legacy extras).
  String? get favoriteDouble =>
      favoriteDoubles.isEmpty ? null : favoriteDoubles.split(',').first;

  List<String> get favoriteDoublesList =>
      favoriteDouble != null ? [favoriteDouble!] : [];

  Player copyWith({
    int? id,
    String? name,
    String? favoriteDoubles,
    bool? isPrimary,
    int? lastSyncedAt,
    String? syncedStats,
    String? localStatsJson,
  }) =>
      Player(
        id: id ?? this.id,
        name: name ?? this.name,
        favoriteDoubles: favoriteDoubles ?? this.favoriteDoubles,
        isDeleted: isDeleted,
        isPrimary: isPrimary ?? this.isPrimary,
        uuid: uuid,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        syncedStats: syncedStats ?? this.syncedStats,
        localStatsJson: localStatsJson ?? this.localStatsJson,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'favorite_doubles': favoriteDoubles,
        'is_deleted': isDeleted ? 1 : 0,
        'is_primary': isPrimary ? 1 : 0,
        'uuid': uuid,
        'last_synced_at': lastSyncedAt,
        'synced_stats': syncedStats,
        'local_stats_json': localStatsJson,
      };

  factory Player.fromMap(Map<String, dynamic> map) => Player(
        id: map['id'] as int?,
        name: map['name'] as String,
        favoriteDoubles: map['favorite_doubles'] as String? ?? '',
        isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
        isPrimary: (map['is_primary'] as int? ?? 0) == 1,
        uuid: map['uuid'] as String? ?? '',
        lastSyncedAt: map['last_synced_at'] as int?,
        syncedStats:    map['synced_stats'] as String?,
        localStatsJson: map['local_stats_json'] as String?,
      );

  static String _newUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(List<int> b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(bytes.sublist(0, 4))}-${hex(bytes.sublist(4, 6))}'
        '-${hex(bytes.sublist(6, 8))}-${hex(bytes.sublist(8, 10))}'
        '-${hex(bytes.sublist(10, 16))}';
  }
}
