import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../database/db_helper.dart';
import '../models/dart_throw.dart';
import '../models/player.dart';
import '../services/sync_codec.dart';
import '../services/sync_service.dart';
import '../utils/layout.dart';

/// How to resolve a name clash when importing a synced player: reuse the
/// existing local player.
enum _NameResolution { useExisting }

/// Builds a QR code for [data] at the smallest version that holds it.
///
/// Sync payloads are base45, which lets the code use its alphanumeric mode and
/// carry about a third more than the byte mode would. `QrCode.fromData` always
/// picks the byte mode, so the code is assembled here instead. Anything outside
/// the alphanumeric character set, such as the connection details of a Wi-Fi
/// transfer, falls back to the byte mode.
///
/// Throws an [InputTooLongException] if [data] does not fit any version, which
/// the transport choice is meant to prevent from ever happening.
QrCode buildQrCode(String data) {
  final alphanumeric = isAlphanumericSafe(data);

  for (var version = 1; version <= 40; version++) {
    final qr = QrCode(version, QrErrorCorrectLevel.M);
    if (alphanumeric) {
      qr.addAlphaNumeric(data);
    } else {
      qr.addData(data);
    }
    try {
      // The size check only runs once the modules are laid out.
      QrImage(qr);
      return qr;
    } on InputTooLongException {
      continue;
    }
  }

  throw InputTooLongException(data.length, 0);
}

/// The localized label for a range given in days, with null meaning the
/// player's whole history. Shared by the sender's picker and the receiver's
/// confirmation dialog, which only ever sees the day count.
String _rangeLabelForDays(AppLocalizations l, int? days) => switch (days) {
      1  => l.syncRangeDay,
      7  => l.syncRangeWeek,
      30 => l.syncRangeMonth,
      _  => l.syncRangeAll,
    };

/// Builds a [SyncPacket] for [player] covering [range], using the live throws
/// plus the persisted [local_stats_json] snapshot (covers cleared game history).
///
/// The aggregate stats always describe the player's whole history, whatever
/// [range] is: the throws it leaves out are folded into the snapshot that
/// travels along, so a short range costs individual throws and nothing else.
Future<SyncPacket> buildSyncPacket(
    Player player, String senderDevice, SyncRange range) async {
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

  // Split the history at the range's cutoff. What falls outside still has to
  // reach the other device, just as aggregated numbers instead of throws.
  final cutoff = range.days == null
      ? null
      : DateTime.now()
          .subtract(Duration(days: range.days!))
          .millisecondsSinceEpoch;

  final included = <DartThrow>[];
  final excluded = <DartThrow>[];
  for (final t in allThrows) {
    if (cutoff == null || t.thrownAt.millisecondsSinceEpoch >= cutoff) {
      included.add(t);
    } else {
      excluded.add(t);
    }
  }

  final snapshot =
      await db.foldThrowsIntoSnapshot(player.localStatsJson, excluded);

  return SyncPacket(
    version:         2,
    senderDevice:    senderDevice,
    playerUuid:      player.uuid,
    playerName:      player.name,
    favoriteDoubles: player.favoriteDoubles,
    localStatsJson:  snapshot == null ? null : jsonEncode(snapshot),
    rangeDays:       range.days,
    stats: SyncStats(
      totalDarts:   totalDarts,
      totalVisits:  totalVisits,
      average:      double.parse(avg.toStringAsFixed(2)),
      legsWon:      totalLegs,
      highestVisit: highestVisit,
      busts:        totalBusts,
      count180:     total180,
    ),
    throws: included.map(SyncThrow.fromDartThrow).toList(),
  );
}

/// QR/Wi-Fi device-to-device sync screen with Send and Receive tabs for
/// transferring a player's stats between devices.
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
    // Start on Send (index 1) when a player was passed, otherwise Receive (index 0).
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

/// Send tab: pick a player and a range, then hand their stats over by whichever
/// transport the resulting payload calls for.
class _SenderTab extends StatefulWidget {
  final Player? initialPlayer;
  const _SenderTab({this.initialPlayer});

  @override
  State<_SenderTab> createState() => _SenderTabState();
}

class _SenderTabState extends State<_SenderTab> {
  Player? _selectedPlayer;
  SyncRange _range = SyncRange.all;

  // Prepared payload
  SyncPacket? _packet;
  String? _payload;
  List<String> _frames = const [];
  SyncTransport _transport = SyncTransport.staticQr;
  bool _preparing = false;

  // Animated QR
  Timer? _frameTimer;
  int _frameIndex = 0;

  // Server transport, only started when the user asks for it
  final _server = SyncServer();
  String? _ip;
  int? _port;
  bool _serverStarting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlayer != null) {
      _selectedPlayer = widget.initialPlayer;
      // A player who has synced before rarely needs their whole history again.
      _range = widget.initialPlayer!.lastSyncedAt == null
          ? SyncRange.all
          : SyncRange.week;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepare();
      });
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _server.stop();
    super.dispose();
  }

  // ── Preparing the payload ─────────────────────────────────────────────────

  /// Builds and encodes the packet for the current player and range, then picks
  /// the transport from how large it turned out.
  Future<void> _prepare() async {
    final player = _selectedPlayer;
    if (player == null) return;

    _frameTimer?.cancel();
    if (_server.isRunning) await _server.stop();

    setState(() {
      _preparing = true;
      _payload = null;
      _packet = null;
      _frames = const [];
      _ip = null;
      _port = null;
    });

    final packet = await buildSyncPacket(
        player, Platform.isIOS ? 'iPhone' : 'Android', _range);
    final payload   = encodeSyncPayload(packet);
    final transport = transportFor(payload);

    if (!mounted) return;
    setState(() {
      _packet    = packet;
      _payload   = payload;
      _transport = transport;
      _frames    = transport == SyncTransport.animatedQr
          ? splitIntoFrames(payload)
          : const [];
      _frameIndex = 0;
      _preparing  = false;
    });

    if (transport == SyncTransport.animatedQr) _startFrameLoop();
  }

  /// Cycles through the frames of an animated QR code, looping forever so the
  /// receiver can pick up whatever it missed on the pass before.
  void _startFrameLoop() {
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(kChunkFrameDuration, (_) {
      if (!mounted || _frames.isEmpty) return;
      setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
    });
  }

  /// Seconds one full pass of the animated QR code takes.
  int get _passSeconds =>
      (_frames.length * kChunkFrameDuration.inMilliseconds / 1000).ceil();

  // ── Server transport ──────────────────────────────────────────────────────

  /// Starts the local HTTP server serving the prepared packet and shows its
  /// IP and port as a connection QR for the receiver.
  Future<void> _startServer() async {
    final packet = _packet;
    if (packet == null) return;
    setState(() => _serverStarting = true);

    if (_server.isRunning) await _server.stop();
    final (ip, port) = await _server.start(packet);

    if (!mounted) return;
    setState(() { _ip = ip; _port = port; _serverStarting = false; });
  }

  /// Stops the transfer server and clears its connection details.
  Future<void> _stopServer() async {
    await _server.stop();
    if (mounted) setState(() { _ip = null; _port = null; });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Switches to a different player and prepares their payload.
  void _onPlayerChanged(Player? p) {
    if (p == null || p.id == _selectedPlayer?.id) return;
    setState(() => _selectedPlayer = p);
    _prepare();
  }

  /// Switches the range and prepares the payload again.
  void _onRangeChanged(SyncRange range) {
    if (range == _range) return;
    setState(() => _range = range);
    _prepare();
  }

  /// The localized label for [range].
  String _rangeLabel(AppLocalizations l, SyncRange range) =>
      _rangeLabelForDays(l, range.days);

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
          l.syncSendDesc,
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

        // ── Range picker ──────────────────────────────────────────────────
        _buildRangePicker(l, cs, theme),
        const SizedBox(height: 12),

        // ── Transport content ─────────────────────────────────────────────
        _buildTransportContent(l, cs, theme),
      ],
    );
  }

  /// Builds the range chips plus the line that translates the current choice
  /// into throws and the transport they call for.
  Widget _buildRangePicker(AppLocalizations l, ColorScheme cs, ThemeData theme) {
    final packet = _packet;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.syncRangeLabel,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SyncRange.values
                  .map((range) => ChoiceChip(
                        label: Text(_rangeLabel(l, range)),
                        selected: _range == range,
                        onSelected: _preparing || _server.isRunning
                            ? null
                            : (_) => _onRangeChanged(range),
                      ))
                  .toList(),
            ),
            if (packet != null && !_preparing) ...[
              const SizedBox(height: 10),
              Text(
                '${l.syncThrowCount(packet.throws.length)} · ${_transportLabel(l)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_range != SyncRange.all) ...[
                const SizedBox(height: 6),
                Text(
                  l.syncRangeNote,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// How the current payload will travel, in words.
  String _transportLabel(AppLocalizations l) => switch (_transport) {
        SyncTransport.staticQr   => l.syncViaStaticQr,
        SyncTransport.animatedQr => l.syncViaAnimatedQr(_passSeconds),
        SyncTransport.server     => l.syncViaServer,
      };

  /// Builds whichever transport the prepared payload ended up needing.
  Widget _buildTransportContent(
      AppLocalizations l, ColorScheme cs, ThemeData theme) {
    if (_selectedPlayer == null) return const SizedBox.shrink();

    if (_preparing || _payload == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return switch (_transport) {
      SyncTransport.staticQr   => _buildStaticQr(l, cs, theme),
      SyncTransport.animatedQr => _buildAnimatedQr(l, cs, theme),
      SyncTransport.server     => _buildServer(l, cs, theme),
    };
  }

  /// Shows the whole packet as one still QR code.
  Widget _buildStaticQr(AppLocalizations l, ColorScheme cs, ThemeData theme) =>
      Column(
        children: [
          _qrCard(_payload!),
          const SizedBox(height: 8),
          Text(
            l.profileAndStats,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );

  /// Shows the packet as a looping sequence of QR codes.
  ///
  /// The codes are rendered as large as the column allows: split across this
  /// many frames each one is denser than a static code, and a small rendering
  /// is what makes an animated transfer stall.
  Widget _buildAnimatedQr(AppLocalizations l, ColorScheme cs, ThemeData theme) =>
      Column(
        children: [
          _qrCard(_frames[_frameIndex]),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: (_frameIndex + 1) / _frames.length,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            l.syncScanProgress(_frameIndex + 1, _frames.length),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            l.syncAnimatedHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );

  /// Offers the Wi-Fi transfer for payloads no QR code can carry.
  Widget _buildServer(AppLocalizations l, ColorScheme cs, ThemeData theme) {
    if (!_server.isRunning) {
      return Column(
        children: [
          Text(
            l.syncServerHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _serverStarting ? null : _startServer,
            icon: _serverStarting
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering),
            label: Text(l.startServer),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
        ],
      );
    }

    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _stopServer,
          icon: const Icon(Icons.stop_circle_outlined),
          label: Text(l.stopServer),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 20),
        Text(
          '$_ip:$_port',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _qrCard(jsonEncode({'ip': _ip, 'port': _port})),
      ],
    );
  }

  /// The white card every QR code sits on, with the player's name above it.
  ///
  /// The code fills the available width instead of a fixed size, so a dense
  /// payload still renders modules large enough for another phone to read.
  Widget _qrCard(String data) => Column(
        children: [
          Text(
            _selectedPlayer!.name,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView.withQr(
              qr: buildQrCode(data),
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
        ],
      );
}

// ── Receiver ──────────────────────────────────────────────────────────────────

/// Receive tab: scans a QR code (or connects over Wi-Fi) to import a player's
/// synced stats, resolving name conflicts and confirming before importing.
class _ReceiverTab extends StatefulWidget {
  const _ReceiverTab();

  @override
  State<_ReceiverTab> createState() => _ReceiverTabState();
}

class _ReceiverTabState extends State<_ReceiverTab> {
  bool _scanning = false;
  bool _fetching = false;
  String? _error;

  /// Collects the frames of an animated QR code across many camera detections.
  final _collector = SyncFrameCollector();

  /// Set once a payload is complete, so the detections that keep arriving while
  /// the confirmation dialog opens are ignored.
  bool _handled = false;

  /// Starts a fresh scan, dropping anything a previous attempt collected.
  void _startScanning() {
    _collector.reset();
    setState(() {
      _scanning = true;
      _handled  = false;
      _error    = null;
    });
  }

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
          else if (_scanning) ...[
            Expanded(child: _QrScanner(onScanned: _onScanned)),
            if (_collector.total > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _collector.received / _collector.total,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text(
                '${context.l10n.syncKeepHolding}\n'
                '${context.l10n.syncScanProgress(_collector.received, _collector.total)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ] else
            FilledButton.icon(
              onPressed: _startScanning,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(context.l10n.scanQr),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
        ],
      ),
    );
  }

  /// Handles one camera detection.
  ///
  /// The camera keeps firing while an animated code plays, so most detections
  /// only add a frame and update the progress. Anything that is not a frame is
  /// a whole payload or a connection QR, and finishes the scan right away.
  void _onScanned(String raw) async {
    if (_handled) return;

    if (SyncFrameCollector.isFrame(raw)) {
      if (_collector.add(raw) && mounted) setState(() {});
      if (!_collector.isComplete) return;

      _handled = true;
      final payload = _collector.assemble();
      _collector.reset();
      await _finishScan(() async => decodeSyncPayload(payload));
      return;
    }

    _handled = true;
    await _finishScan(() async {
      // ── Whole packet in one code ────────────────────────────────────────
      if (raw.startsWith(kSyncPrefixV2) || raw.startsWith(kSyncPrefixV1)) {
        return decodeSyncPayload(raw);
      }

      // ── Wi-Fi transfer (IP:port) ────────────────────────────────────────
      final map  = jsonDecode(raw) as Map<String, dynamic>;
      final ip   = map['ip'] as String;
      final port = map['port'] as int;
      return SyncClient().fetch(ip, port);
    });
  }

  /// Closes the camera, resolves [read] into a packet and imports it, turning
  /// any failure into the error banner.
  Future<void> _finishScan(Future<SyncPacket> Function() read) async {
    setState(() { _scanning = false; _fetching = true; _error = null; });

    try {
      final packet = await read();
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
          await _doImport(packet.withName(resolution), null);
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

  /// Prompts the user to resolve a same-name conflict (merge into the existing
  /// player or import under a different name), returning their choice.
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
          return Center(
            child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(ctx)),
            child: AlertDialog(
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
            ),
            ),
          );
        },
      ),
    );
  }

  /// Shows a confirmation dialog summarizing the incoming stats; returns whether
  /// the user approved the import.
  Future<bool> _showConfirmDialog(
      SyncPacket packet, Player? existing) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(packet: packet, existing: existing),
    );
    return result == true;
  }

  /// Persists the incoming packet: updates the existing player or creates a new
  /// one, storing the received stats snapshot, and shows a result message.
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

      // What an earlier sync brought in is replaced, not added to: this packet's
      // snapshot may already account for those throws, and keeping both would
      // count the same legs twice. Locally played games are not affected.
      await db.deleteSyncedThrowsForPlayer(playerId);

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

/// Dialog summarizing an incoming sync packet's stats and asking to confirm import.
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

    return Center(
      child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
      child: AlertDialog(
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
                      Text(
                        l.syncRangeInPacket(
                            _rangeLabelForDays(l, packet.rangeDays)),
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
      ),
      ),
    );
  }
}

/// A label/value line in the import confirmation dialog.
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

/// Camera QR scanner that reports every decoded payload via a callback.
///
/// It keeps reporting rather than stopping after the first hit, because an
/// animated transfer arrives as a long series of codes. Deciding when enough
/// has been read is the caller's job.
class _QrScanner extends StatefulWidget {
  final void Function(String) onScanned;
  const _QrScanner({required this.onScanned});

  @override
  State<_QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<_QrScanner> {
  /// The last payload handed on, so the same code sitting in front of the
  /// camera is not reported dozens of times a second.
  String? _lastReported;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final raw = capture.barcodes.firstOrNull?.rawValue;
              if (raw == null || raw == _lastReported) return;
              _lastReported = raw;
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
