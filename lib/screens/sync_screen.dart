import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../database/db_helper.dart';
import '../models/player.dart';
import '../services/sync_service.dart';
import '../utils/layout.dart';

enum _NameResolution { useExisting }

/// Builds a [SyncPacket] for [player] using all live throws plus the
/// persisted [local_stats_json] snapshot (covers cleared game history).
Future<SyncPacket> _buildSyncPacket(Player player, String senderDevice) async {
  final db        = DbHelper.instance;
  final allThrows = await db.getThrowsForPlayer(player.id!);

  // Live stats
  int liveDarts = 0, liveScored = 0, liveLegs = 0, liveHigh = 0;
  int liveBusts = 0, live180 = 0;
  for (final t in allThrows) {
    liveDarts += t.dartsUsed;
    if (!t.bust) {
      liveScored += t.score;
      if (t.score > liveHigh) liveHigh = t.score;
      if (t.score == 180) live180++;
      if (t.remainingBefore - t.score == 0) liveLegs++;
    } else {
      liveBusts++;
    }
  }

  // Persistent stats from cleared-game snapshot
  int persD = 0, persV = 0, persLegs = 0, persHigh = 0, persBusts = 0, pers180 = 0, persScored = 0;
  if (player.localStatsJson != null && player.localStatsJson!.isNotEmpty) {
    try {
      final p = jsonDecode(player.localStatsJson!) as Map<String, dynamic>;
      persD      = p['total_darts']   as int? ?? 0;
      persV      = p['total_visits']  as int? ?? 0;
      persLegs   = p['legs_won']      as int? ?? 0;
      persHigh   = p['highest_visit'] as int? ?? 0;
      persBusts  = p['busts']         as int? ?? 0;
      pers180    = p['count_180']     as int? ?? 0;
      persScored = p['total_scored']  as int? ?? 0;
    } catch (_) {}
  }

  final totalDarts   = liveDarts  + persD;
  final totalVisits  = allThrows.length + persV;
  final totalScored  = liveScored + persScored;
  final totalLegs    = liveLegs   + persLegs;
  final highestVisit = liveHigh > persHigh ? liveHigh : persHigh;
  final totalBusts   = liveBusts  + persBusts;
  final total180     = live180    + pers180;
  final avg = totalDarts == 0 ? 0.0 : (totalScored / totalDarts) * 3;

  return SyncPacket(
    version:         1,
    senderDevice:    senderDevice,
    playerUuid:      player.uuid,
    playerName:      player.name,
    favoriteDoubles: player.favoriteDoubles,
    localStatsJson:  player.localStatsJson,
    stats: SyncStats(
      totalDarts:   totalDarts,
      totalVisits:  totalVisits,
      average:      double.parse(avg.toStringAsFixed(2)),
      legsWon:      totalLegs,
      highestVisit: highestVisit,
      busts:        totalBusts,
      count180:     total180,
    ),
    throws: allThrows.map(SyncThrow.fromDartThrow).toList(),
  );
}

// Prefix that marks a QR code as containing embedded data (not IP:port).
const _kQrPrefix = 'QR1:';

class SyncScreen extends StatefulWidget {
  final Player? initialPlayer;
  const SyncScreen({super.key, this.initialPlayer});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    // Start on Senden (index 1) when a player was passed, otherwise Empfangen (index 0).
    _tab = TabController(
      length: 2,
      initialIndex: widget.initialPlayer != null ? 1 : 0,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.syncTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kTextTabBarHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
              child: TabBar(
                controller: _tab,
                tabs: [
                  Tab(icon: const Icon(Icons.download_rounded), text: context.l10n.syncReceive),
                  Tab(icon: const Icon(Icons.upload_rounded), text: context.l10n.syncSend),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const _ReceiverTab(),
          _SenderTab(initialPlayer: widget.initialPlayer),
        ],
      ),
        ),
      ),
    );
  }
}

// ── Sender ────────────────────────────────────────────────────────────────────

enum _SenderMode { quickQr, wifi }

class _SenderTab extends StatefulWidget {
  final Player? initialPlayer;
  const _SenderTab({this.initialPlayer});

  @override
  State<_SenderTab> createState() => _SenderTabState();
}

class _SenderTabState extends State<_SenderTab> {
  // shared
  Player? _selectedPlayer;
  _SenderMode _mode = _SenderMode.quickQr;

  // Quick-QR state
  String? _quickQrData;
  bool _qrTooLarge = false;
  bool _generatingQr = false;
  int _newThrowsCount = 0;

  // WiFi state
  final _server = SyncServer();
  String? _ip;
  int? _port;
  bool _wifiStarting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlayer != null) {
      _selectedPlayer = widget.initialPlayer;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generateQuickQr();
      });
    }
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  // ── Quick QR ──────────────────────────────────────────────────────────────

  Future<void> _generateQuickQr() async {
    if (_selectedPlayer == null) return;
    setState(() {
      _generatingQr = true;
      _quickQrData = null;
      _qrTooLarge = false;
    });

    final packet = await _buildSyncPacket(
      _selectedPlayer!,
      Platform.isIOS ? 'iPhone' : 'Android',
    );
    _newThrowsCount = packet.stats.totalVisits;

    // gzip → base64url
    final jsonBytes  = utf8.encode(jsonEncode(packet.toJson()));
    final compressed = gzip.encode(jsonBytes);
    final encoded    = '$_kQrPrefix${base64Url.encode(compressed)}';

    if (!mounted) return;
    if (encoded.length > 4000) {
      setState(() { _qrTooLarge = true; _generatingQr = false; });
    } else {
      setState(() { _quickQrData = encoded; _qrTooLarge = false; _generatingQr = false; });
    }
  }

  // ── WiFi Sync ─────────────────────────────────────────────────────────────

  Future<void> _startWifi() async {
    if (_selectedPlayer == null) return;
    setState(() => _wifiStarting = true);

    final packet = await _buildSyncPacket(
      _selectedPlayer!,
      Platform.isIOS ? 'iPhone' : 'Android',
    );

    if (_server.isRunning) await _server.stop();
    final (ip, port) = await _server.start(packet);

    if (!mounted) return;
    setState(() { _ip = ip; _port = port; _wifiStarting = false; });
  }

  Future<void> _stopWifi() async {
    await _server.stop();
    setState(() { _ip = null; _port = null; });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _onPlayerChanged(Player? p) async {
    if (_server.isRunning) await _server.stop();
    setState(() {
      _selectedPlayer = p;
      _mode = _SenderMode.quickQr;
      _quickQrData = null;
      _qrTooLarge = false;
      _ip = null;
      _port = null;
    });
    if (p != null) _generateQuickQr();
  }

  void _onModeChanged(_SenderMode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _quickQrData = null;
      _qrTooLarge = false;
    });
    if (mode == _SenderMode.quickQr && _selectedPlayer != null) _generateQuickQr();
    if (mode == _SenderMode.wifi && _server.isRunning) _stopWifi();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final l     = context.l10n;
    final players = context.watch<PlayersProvider>().players;

    // Resolve to provider's object so DropdownButton equality works.
    Player? dropdownValue;
    if (_selectedPlayer != null) {
      try {
        dropdownValue = players.firstWhere((p) => p.id == _selectedPlayer!.id);
      } catch (_) {
        dropdownValue = null;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Description ───────────────────────────────────────────────────
        Text(
          _mode == _SenderMode.quickQr ? l.quickQrDesc : l.syncSendDesc,
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        // ── Player dropdown ───────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Player>(
                value: dropdownValue,
                hint: Text(l.selectPlayer),
                isExpanded: true,
                items: players.map((p) => DropdownMenuItem(
                  value: p,
                  child: Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : "?",
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(p.name),
                  ]),
                )).toList(),
                onChanged: _server.isRunning ? null : _onPlayerChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Mode content ──────────────────────────────────────────────────
        if (_mode == _SenderMode.quickQr)
          _buildQuickQrContent(l, cs, theme)
        else
          _buildWifiContent(l, cs, theme),
      ],
    );
  }

  Widget _buildQuickQrContent(AppLocalizations l, ColorScheme cs, ThemeData theme) {
    if (_selectedPlayer == null) return const SizedBox.shrink();

    if (_generatingQr) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_qrTooLarge) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: cs.onErrorContainer, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.qrTooLargeWarning,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _onModeChanged(_SenderMode.wifi),
            icon: const Icon(Icons.wifi_tethering),
            label: Text(l.wifiSync),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      );
    }

    if (_quickQrData == null) return const SizedBox.shrink();

    // Info chip: how many throws
    final infoText = _newThrowsCount == 0
        ? l.noNewThrowsQr
        : l.allThrowsFirstSync;

    return Column(
      children: [
        // Info badge
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 16, color: cs.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  infoText,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // QR code
        Center(
          child: Column(
            children: [
              Text(
                _selectedPlayer!.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: _quickQrData!,
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFFB71C1C),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.profileAndStats,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWifiContent(AppLocalizations l, ColorScheme cs, ThemeData theme) {
    if (!_server.isRunning) {
      return FilledButton.icon(
        onPressed: _wifiStarting || _selectedPlayer == null ? null : _startWifi,
        icon: _wifiStarting
            ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.wifi_tethering),
        label: Text(l.startServer),
        style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16)),
      );
    }

    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _stopWifi,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(l.stopServer),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Text(
                _selectedPlayer!.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '$_ip:$_port',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: jsonEncode({'ip': _ip, 'port': _port}),
                  version: QrVersions.auto,
                  size: 220,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFFB71C1C),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.profileAndStats,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Receiver ──────────────────────────────────────────────────────────────────

class _ReceiverTab extends StatefulWidget {
  const _ReceiverTab();

  @override
  State<_ReceiverTab> createState() => _ReceiverTabState();
}

class _ReceiverTabState extends State<_ReceiverTab> {
  bool _scanning = false;
  bool _fetching = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.syncReceiveDesc,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_fetching)
            const Center(child: CircularProgressIndicator())
          else if (_scanning)
            Expanded(child: _QrScanner(onScanned: _onScanned))
          else
            FilledButton.icon(
              onPressed: () => setState(() {
                _scanning = true;
                _error = null;
              }),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(context.l10n.scanQr),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
        ],
      ),
    );
  }

  void _onScanned(String raw) async {
    setState(() { _scanning = false; _fetching = true; _error = null; });

    try {
      // ── Quick QR (embedded data) ────────────────────────────────────────
      if (raw.startsWith(_kQrPrefix)) {
        final encoded    = raw.substring(_kQrPrefix.length);
        final compressed = base64Url.decode(encoded);
        final jsonStr    = utf8.decode(gzip.decode(compressed));
        final packet     = SyncPacket.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);

        await _handlePacket(packet);
        return;
      }

      // ── WiFi Sync (IP:port) ─────────────────────────────────────────────
      final map  = jsonDecode(raw) as Map<String, dynamic>;
      final ip   = map['ip'] as String;
      final port = map['port'] as int;

      final packet = await SyncClient().fetch(ip, port);
      if (!mounted) return;

      await _handlePacket(packet);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetching = false;
          _error =
              '${context.l10n.connectionFailed}\n\n${context.l10n.error}: $e';
        });
      }
    }
  }

  /// Common flow: name conflict check → confirm dialog → import.
  Future<void> _handlePacket(SyncPacket packet) async {
    Player? existing =
        await DbHelper.instance.getPlayerByUuid(packet.playerUuid);
    if (!mounted) return;

    if (existing == null) {
      final provider = context.read<PlayersProvider>();
      final sameNamePlayer = provider.players
          .where((p) =>
              p.name.toLowerCase() == packet.playerName.toLowerCase())
          .firstOrNull;
      if (sameNamePlayer != null) {
        final resolution =
            await _showNameConflictDialog(packet, sameNamePlayer);
        if (!mounted) return;
        if (resolution == null) {
          setState(() => _fetching = false);
          return;
        } else if (resolution == _NameResolution.useExisting) {
          existing = sameNamePlayer;
        } else if (resolution is String) {
          await _doImport(_renamePacket(packet, resolution), null);
          if (mounted) setState(() => _fetching = false);
          return;
        }
      }
    }

    final confirmed = await _showConfirmDialog(packet, existing);
    if (!mounted) return;
    if (confirmed) await _doImport(packet, existing);
    if (mounted) setState(() => _fetching = false);
  }

  SyncPacket _renamePacket(SyncPacket p, String newName) => SyncPacket(
        version: p.version,
        senderDevice: p.senderDevice,
        playerUuid: p.playerUuid,
        playerName: newName,
        favoriteDoubles: p.favoriteDoubles,
        stats: p.stats,
        throws: p.throws,
      );

  Future<Object?> _showNameConflictDialog(
      SyncPacket packet, Player sameNamePlayer) async {
    final nameCtrl =
        TextEditingController(text: '${packet.playerName} (${context.l10n.guest})');
    return showDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          final l = ctx.l10n;
          return AlertDialog(
            title: Text(l.nameConflictTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.nameConflictBody(packet.playerName),
                    style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.alternativeName,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(l.cancel),
              ),
              OutlinedButton(
                onPressed: () =>
                    Navigator.pop(ctx, _NameResolution.useExisting),
                child: Text(l.importAs(sameNamePlayer.name)),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) Navigator.pop(ctx, name);
                },
                child: Text(l.renameAndImport),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<bool> _showConfirmDialog(
      SyncPacket packet, Player? existing) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(packet: packet, existing: existing),
    );
    return result == true;
  }

  Future<void> _doImport(SyncPacket packet, Player? existing) async {
    final provider  = context.read<PlayersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l         = context.l10n;
    final db        = DbHelper.instance;
    final statsJson = jsonEncode(packet.stats.toJson());
    final now       = DateTime.now().millisecondsSinceEpoch;

    try {
      int playerId;

      if (existing != null) {
        await provider.updatePlayer(existing.copyWith(
          name: packet.playerName,
          favoriteDoubles: packet.favoriteDoubles,
          syncedStats: statsJson,
          localStatsJson: packet.localStatsJson,
        ));
        await db.updatePlayerSyncTime(existing.id!, now,
            syncedStatsJson: statsJson);
        playerId = existing.id!;
      } else {
        final newPlayer = await provider.addPlayer(packet.playerName);
        final updated = Player(
          id: newPlayer.id,
          name: packet.playerName,
          favoriteDoubles: packet.favoriteDoubles,
          uuid: packet.playerUuid,
          lastSyncedAt: now,
          syncedStats: statsJson,
          localStatsJson: packet.localStatsJson,
        );
        await db.updatePlayer(updated);
        await provider.load();
        playerId = newPlayer.id!;
      }

      if (packet.throws.isNotEmpty) {
        final existingTs = await db.getThrowTimestampsForPlayer(playerId);
        final newThrows  = packet.throws
            .where((t) => !existingTs.contains(t.thrownAt))
            .toList();

        if (newThrows.isNotEmpty) {
          final gameId = await db.createSyncGame(
              newThrows.first.remainingBefore + newThrows.first.score);
          for (final t in newThrows) {
            await db.insertSyncedThrow(
              playerId, gameId,
              t.toDartThrow(gameId: gameId, playerId: playerId),
            );
          }
        }

        final duplicates = existingTs
            .intersection(packet.throws.map((t) => t.thrownAt).toSet())
            .length;
        final newLiveVisits = packet.throws.length - duplicates;
        // For display: new player shows total visits (live + historical snapshot),
        // update shows only the newly added live visits.
        final displayCount = existing != null
            ? newLiveVisits
            : packet.stats.totalVisits;

        messenger.showSnackBar(SnackBar(
          content: Text(existing != null
              ? l.importedWithThrows(packet.playerName, displayCount)
              : l.importedWithCount(packet.playerName, displayCount)),
        ));
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(existing != null
              ? l.updatedMsg(packet.playerName)
              : l.importedMsg(packet.playerName)),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('${l.error}: $e')));
    }
  }
}

// ── Confirmation dialog ───────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final SyncPacket packet;
  final Player? existing;

  const _ConfirmDialog({required this.packet, this.existing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;
    final isNew = existing == null;
    final s     = packet.stats;
    final l     = context.l10n;

    return AlertDialog(
      title: Text(isNew ? l.importNewPlayer : l.updatePlayer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNew ? cs.secondaryContainer : cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isNew ? cs.secondary : cs.primary,
                  child: Text(
                    packet.playerName.isNotEmpty ? packet.playerName[0].toUpperCase() : "?",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(packet.playerName,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      if (packet.favoriteDoubles.isNotEmpty)
                        Text('${l.doublesLabel}: ${packet.favoriteDoubles}',
                            style: theme.textTheme.bodySmall),
                      Text(
                        '${l.fromDevice(packet.senderDevice)}  ·  ${packet.stats.totalVisits} ${l.visits}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(l.statistics,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _StatLine(l.threeDartAvg, s.average.toStringAsFixed(2)),
          _StatLine(l.legsWon,      '${s.legsWon}'),
          _StatLine(l.totalDarts,   '${s.totalDarts}'),
          _StatLine(l.highestVisit, '${s.highestVisit}'),
          _StatLine(l.count180,     '${s.count180}'),
          if (!isNew) ...[
            const SizedBox(height: 8),
            Text(l.overwriteProfile(existing!.name),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(isNew ? l.import_ : l.update),
        ),
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── QR Scanner ────────────────────────────────────────────────────────────────

class _QrScanner extends StatefulWidget {
  final void Function(String) onScanned;
  const _QrScanner({required this.onScanned});

  @override
  State<_QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<_QrScanner> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_done) return;
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw == null) return;
              _done = true;
              widget.onScanned(raw);
            },
          ),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: cs.primary, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Text(
              context.l10n.qrScanHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                shadows: [
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
