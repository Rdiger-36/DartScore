import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/players_provider.dart';
import '../services/backup_service.dart';
import '../utils/layout.dart';

/// Writes the whole local database out as one file, and reads one back in.
///
/// The two halves are deliberately unequal: creating a backup is a single tap,
/// restoring one goes through the file, its contents and a confirmation before
/// anything is touched, because it replaces everything on the device.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  /// Anchors the share sheet on an iPad, where a popover without an anchor
  /// fails instead of opening.
  final _exportKey = GlobalKey();

  bool _busy = false;

  @override
  Widget build(BuildContext context) => TabletTextScale(child: _build(context));

  /// The screen itself. [build] only wraps it, so that a tablet renders the
  /// same layout at a size that suits the distance it is read from.
  Widget _build(BuildContext context) {
    final l  = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l.backupTitle)),
      body: ListView(
        padding: contentPadding(context, top: 12, bottom: 28, innerH: 14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.backupWhereHint,
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ),
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
                  onTap: _export,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.restore_rounded, color: cs.error),
                  title: Text(l.backupRestore),
                  subtitle: Text(l.backupRestoreDesc),
                  enabled: !_busy,
                  onTap: _restore,
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

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

  /// Picks a backup, shows what it holds and replaces the local data once that
  /// is confirmed.
  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final picked = await BackupService.pick();
      if (picked == null) return;
      if (!mounted) return await picked.discard();
      if (!await _confirm(picked)) return await picked.discard();
      if (!mounted) return;

      await BackupService.restore(picked);
      if (!mounted) return;
      await context.read<PlayersProvider>().load();
      if (!mounted) return;

      _toast(context.l10n.backupRestored);
      // The screens underneath were built from data that no longer exists.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on BackupRejectedException catch (e) {
      if (mounted) {
        _toast(switch (e.reason) {
          BackupRejection.notABackup => context.l10n.backupNotABackup,
          BackupRejection.tooNew     => context.l10n.backupTooNew,
        });
      }
    } catch (e) {
      if (mounted) _toast('${context.l10n.error}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  /// Shows [message] in a snackbar.
  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
