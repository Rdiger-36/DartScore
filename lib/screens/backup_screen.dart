import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../services/backup_service.dart';
import '../services/sync_service.dart';
import '../utils/layout.dart';
import '../widgets/wifi_pairing.dart';

/// Which half of the screen the user is in.
enum _Mode {
  /// The two entries, waiting to be picked.
  idle,

  /// Serving this device's database to a peer over the local network.
  sending,

  /// Camera up, waiting for the other device's code.
  receiving,
}

/// Writes the whole local database out, and reads one back in.
///
/// Both halves offer the same two routes, a file or the other device directly,
/// and the choice is a dialog rather than four entries so the symmetry stays
/// visible. The two halves are deliberately unequal past that point: creating a
/// backup is a couple of taps, taking one in goes through the file, its
/// contents and a confirmation, because it replaces everything on the device.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  /// Anchors the share sheet on an iPad, where a popover without an anchor
  /// fails instead of opening.
  final _exportKey = GlobalKey();

  final SyncServer _server = SyncServer();

  _Mode _mode = _Mode.idle;
  bool _busy = false;
  SyncConnection? _connection;
  bool _sent = false;
  String? _error;

  /// Set while the approval dialog is up, so a peer asking again does not open
  /// a second one.
  bool _askingApproval = false;

  @override
  void initState() {
    super.initState();
    _server.state.addListener(_onServerState);
  }

  @override
  void dispose() {
    _server.state.removeListener(_onServerState);
    unawaited(_server.stop());
    _server.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TabletTextScale(child: _build(context));

  /// The screen itself. [build] only wraps it, so that a tablet renders the
  /// same layout at a size that suits the distance it is read from.
  Widget _build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.backupTitle),
        leading: _mode == _Mode.idle
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _leaveMode,
              ),
      ),
      body: ListView(
        padding: contentPadding(context, top: 12, bottom: 28, innerH: 14),
        children: switch (_mode) {
          _Mode.idle      => _idleBody(l),
          _Mode.sending   => _sendingBody(l),
          _Mode.receiving => _receivingBody(l),
        },
      ),
    );
  }

  // ── The two entries ───────────────────────────────────────────────────────

  List<Widget> _idleBody(AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    return [
      _note(l.backupWhereHint),
      const SizedBox(height: 16),
      Card(
        child: Column(
          children: [
            ListTile(
              key: _exportKey,
              leading: Icon(Icons.save_alt_rounded, color: cs.primary),
              title: Text(l.backupCreate),
              subtitle: Text(l.backupCreateDesc),
              enabled: !_busy,
              onTap: _chooseCreate,
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.restore_rounded, color: cs.error),
              title: Text(l.backupRestore),
              subtitle: Text(l.backupRestoreDesc),
              enabled: !_busy,
              onTap: _chooseRestore,
            ),
          ],
        ),
      ),
      if (_busy) ...[
        const SizedBox(height: 24),
        const Center(child: CircularProgressIndicator()),
      ],
    ];
  }

  /// Asks whether the backup should become a file or go straight to the other
  /// device.
  Future<void> _chooseCreate() async {
    final l = context.l10n;
    final route = await _askRoute(
      title: l.backupCreate,
      first: (Icons.folder_outlined, l.backupToFile, l.backupToFileDesc),
      second: (Icons.wifi_rounded, l.backupToDevice, l.backupToDeviceDesc),
    );
    if (route == null || !mounted) return;
    if (route) {
      await _export();
    } else {
      await _startSending();
    }
  }

  /// The same question for the way back in.
  Future<void> _chooseRestore() async {
    final l = context.l10n;
    final route = await _askRoute(
      title: l.backupRestore,
      first: (Icons.folder_outlined, l.backupFromFile, l.backupFromFileDesc),
      second: (
        Icons.qr_code_scanner_rounded,
        l.backupFromDevice,
        l.backupFromDeviceDesc
      ),
    );
    if (route == null || !mounted) return;
    if (route) {
      await _restoreFromFile();
    } else {
      setState(() {
        _mode  = _Mode.receiving;
        _error = null;
      });
    }
  }

  /// Offers the two routes and returns true for the file one, false for the
  /// other device, or null when the user backed out.
  Future<bool?> _askRoute({
    required String title,
    required (IconData, String, String) first,
    required (IconData, String, String) second,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        Widget option((IconData, String, String) o, bool value) => ListTile(
              leading: Icon(o.$1, color: cs.primary),
              title: Text(o.$2),
              subtitle: Text(o.$3),
              onTap: () => Navigator.pop(ctx, value),
            );

        return AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [option(first, true), option(second, false)],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  // ── Sending over the network ──────────────────────────────────────────────

  List<Widget> _sendingBody(AppLocalizations l) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    if (_sent) {
      return [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(l.backupSent,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _startSending, child: Text(l.backupSendAgain)),
      ];
    }

    final connection = _connection;
    if (connection == null) {
      return [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(_error ?? l.backupSendPrep,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
                color: _error == null ? cs.onSurfaceVariant : cs.error)),
      ];
    }

    return [
      _note(l.backupSendHint),
      const SizedBox(height: 20),
      PairingQrCard(data: connection.qrPayload),
    ];
  }

  /// Prepares the database and puts it on the network for one peer.
  Future<void> _startSending() async {
    setState(() {
      _mode       = _Mode.sending;
      _sent       = false;
      _error      = null;
      _connection = null;
    });

    try {
      final bytes = await BackupService.exportBytes();
      if (!mounted) return;

      if (_server.isRunning) await _server.stop();
      // One way on purpose. A database replaces the device that takes it, so
      // there is nothing it could hand back.
      final connection = await _server.start(
        bytes,
        twoWay: false,
        contentType: ContentType.binary,
        codePrefix: kBackupWifiPrefix,
      );
      if (!mounted) return;
      setState(() => _connection = connection);
    } catch (e) {
      if (mounted) setState(() => _error = '${context.l10n.error}: $e');
    }
  }

  /// Follows the transfer: asks about a waiting peer, and closes the session
  /// once the database is out.
  void _onServerState() {
    switch (_server.state.value) {
      case SyncServerState.pending:
        _askApproval();
      case SyncServerState.served:
      case SyncServerState.rejected:
        _finishSending();
      case SyncServerState.waiting:
      case SyncServerState.approved:
      case SyncServerState.returned:
        if (mounted) setState(() {});
    }
  }

  /// Shows the peer's request with the pairing number and acts on the answer.
  Future<void> _askApproval() async {
    if (_askingApproval || !mounted) return;
    _askingApproval = true;

    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PairingDialog(pin: _server.pin),
    );

    _askingApproval = false;
    if (approved == true) {
      _server.approve();
    } else {
      _server.reject();
    }
  }

  /// Takes the server down once the session is over, either way.
  Future<void> _finishSending() async {
    final sent = _server.state.value == SyncServerState.served;
    await _server.stop();
    if (mounted) setState(() { _connection = null; _sent = sent; });
  }

  // ── Receiving over the network ────────────────────────────────────────────

  List<Widget> _receivingBody(AppLocalizations l) {
    final theme = Theme.of(context);
    final cs    = theme.colorScheme;

    if (_busy) {
      return [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(l.backupReceiving,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: cs.onSurfaceVariant)),
      ];
    }

    return [
      _note(_error ?? l.backupReceiveHint, isError: _error != null),
      const SizedBox(height: 16),
      SizedBox(
        height: 320,
        child: QrScanner(onScanned: _onScanned),
      ),
    ];
  }

  /// Reads a scanned code and, if it opens a database transfer, takes it.
  Future<void> _onScanned(String raw) async {
    if (_busy) return;

    final connection =
        SyncConnection.parse(raw, prefix: kBackupWifiPrefix);
    if (connection == null) {
      // A profile sync code is the one wrong code worth naming, because it
      // looks right and belongs to a different screen.
      final isSyncCode = SyncConnection.parse(raw) != null;
      if (mounted) {
        setState(() => _error = isSyncCode
            ? context.l10n.backupNotSyncCode
            : context.l10n.backupNotABackup);
      }
      return;
    }

    setState(() { _busy = true; _error = null; });
    try {
      final bytes = await SyncClient().fetchBytes(connection);
      if (!mounted) return;
      await _confirmAndRestore(await BackupService.acceptTransfer(bytes));
    } on BackupRejectedException catch (e) {
      if (mounted) setState(() => _error = _rejectionMessage(e));
    } catch (e) {
      if (mounted) {
        final l = context.l10n;
        setState(() => _error = switch (e) {
              SyncRejectedException() => l.syncRejected,
              TimeoutException()      => l.syncNotConfirmed,
              _ => '${l.connectionFailed}\n\n${l.error}: $e',
            });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Shared ────────────────────────────────────────────────────────────────

  /// Copies the database out and hands it to the share sheet.
  Future<void> _export() async {
    final box    = _exportKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    setState(() => _busy = true);
    try {
      final shared = await BackupService.exportAndShare(
          sharePositionOrigin: origin);
      if (shared && mounted) _toast(context.l10n.backupCreated);
    } catch (e) {
      if (mounted) _toast('${context.l10n.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Picks a backup file and replaces the local data once that is confirmed.
  Future<void> _restoreFromFile() async {
    setState(() => _busy = true);
    try {
      final picked = await BackupService.pick();
      if (picked == null) return;
      if (!mounted) return await picked.discard();
      await _confirmAndRestore(picked);
    } on BackupRejectedException catch (e) {
      if (mounted) _toast(_rejectionMessage(e));
    } catch (e) {
      if (mounted) _toast('${context.l10n.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The last step of both routes in: show what is about to replace everything,
  /// and carry it out if the user says so.
  Future<void> _confirmAndRestore(PickedBackup picked) async {
    if (!await _confirm(picked)) return await picked.discard();
    if (!mounted) return await picked.discard();

    await BackupService.restore(picked);
    if (!mounted) return;
    await context.read<PlayersProvider>().load();
    if (!mounted) return;

    _toast(context.l10n.backupRestored);
    // The screens underneath were built from data that no longer exists.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Asks whether [picked] should really replace everything on this device,
  /// showing when it was made and what it contains so two backups can be told
  /// apart.
  Future<bool> _confirm(PickedBackup picked) async {
    final l    = context.l10n;
    final info = picked.info;
    final when = info.createdAt == null
        ? l.backupUnknownDate
        : DateFormat('dd.MM.yy  HH:mm').format(info.createdAt!);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(l.backupRestoreQ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(when, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(l.backupContents(info.playerCount, info.gameCount),
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 14),
              Text(l.backupRestoreWarn),
              const SizedBox(height: 10),
              Text(l.backupDeviceNote,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.backupRestore),
            ),
          ],
        );
      },
    );
    return ok ?? false;
  }

  /// Back to the two entries, shutting down whatever the mode was running.
  Future<void> _leaveMode() async {
    await _server.stop();
    if (!mounted) return;
    setState(() {
      _mode       = _Mode.idle;
      _connection = null;
      _sent       = false;
      _error      = null;
    });
  }

  String _rejectionMessage(BackupRejectedException e) => switch (e.reason) {
        BackupRejection.notABackup => context.l10n.backupNotABackup,
        BackupRejection.tooNew     => context.l10n.backupTooNew,
      };

  /// A bordered line of explanation above whatever the mode is showing.
  Widget _note(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline_rounded,
                size: 18, color: isError ? cs.error : cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style:
                      TextStyle(color: isError ? cs.error : cs.onSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows [message] in a snackbar.
  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
