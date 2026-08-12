import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import 'device_identity.dart';
import 'document_picker.dart';

/// Why a file the user picked cannot be restored.
enum BackupRejection {
  /// Not a readable SQLite database, or not one of this app's.
  notABackup,

  /// Written by a newer app version, whose schema this build cannot read.
  tooNew,
}

/// Thrown by [BackupService.restore] when the picked file is refused. The
/// screen turns [reason] into a sentence; there is nothing to retry.
class BackupRejectedException implements Exception {
  final BackupRejection reason;
  const BackupRejectedException(this.reason);
}

/// Writing the local database out as a single file and reading one back in.
///
/// The backup is the SQLite file itself rather than a dump of it, which keeps
/// restoring exact and costs no second serialiser to maintain beside the
/// schema. Where the file then goes is the platform's business: the share sheet
/// offers iCloud Drive, Files, Drive, mail or anything else the user has, and
/// the document picker takes it back, so neither platform needs its own path
/// through this class and nothing has to be hosted anywhere.
///
/// This is deliberately not the sync in [sync_service.dart]. A sync merges two
/// devices and folds what it cannot carry into snapshots; a restore replaces
/// this device wholesale, including its identity.
class BackupService {
  /// Writes the current database to a temporary file and opens the share sheet
  /// on it. [sharePositionOrigin] anchors the popover on an iPad, where a sheet
  /// without an anchor fails instead of opening.
  ///
  /// Returns false when the user dismissed the sheet without choosing a target.
  static Future<bool> exportAndShare({Rect? sharePositionOrigin}) async {
    final deviceId = await DeviceIdentity.id;
    final source   = await DbHelper.instance.prepareBackup(deviceId);
    final tmp      = await getTemporaryDirectory();
    final target   = File('${tmp.path}/${backupFileName(DateTime.now())}');

    if (await target.exists()) await target.delete();
    await File(source).copy(target.path);

    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile(target.path)],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return result.status == ShareResultStatus.success;
  }

  /// Name a backup is offered under, dated so several of them stay apart in a
  /// cloud folder.
  ///
  /// The plain `.db` extension is on purpose: iOS maps a file to an app by its
  /// type, and an invented extension is an unknown type that some targets in
  /// the share sheet then refuse to take. What the file actually is gets
  /// checked on the way back in, not by its name.
  static String backupFileName(DateTime now) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'dartscore-backup-${now.year}-${two(now.month)}-${two(now.day)}'
        '-${two(now.hour)}${two(now.minute)}.db';
  }

  /// Lets the user pick a backup and reports what it holds, without changing
  /// anything yet. Returns null when the picker was dismissed.
  ///
  /// Restoring is destructive, so it is split in two: this reads the file so
  /// the screen can show what is about to replace the current data, and
  /// [restore] carries it out once that has been confirmed.
  static Future<PickedBackup?> pick() async {
    final path = await DocumentPicker.pickFile();
    if (path == null) return null;

    // The picker offers every file rather than filtering by name, so what came
    // back is checked by what is in it. A name filter would be the weaker test
    // and, on iOS, one the system cannot always resolve to a type at all.
    final info = await DbHelper.instance.inspectBackup(path);
    if (info == null) {
      await _discard(path);
      throw const BackupRejectedException(BackupRejection.notABackup);
    }
    if (info.schemaVersion > DbHelper.schemaVersion) {
      await _discard(path);
      throw const BackupRejectedException(BackupRejection.tooNew);
    }
    return PickedBackup(path, info);
  }

  /// Removes the copy the picker left behind. A backup is the whole database,
  /// so leaving one in the cache for the system to clear whenever it feels like
  /// it doubles what the app occupies for no reason.
  static Future<void> _discard(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Replaces the local database with [picked] and takes over the device
  /// identity stored in it.
  ///
  /// The caller has to reload every provider afterwards: the data behind them
  /// is not the data they were built from any more.
  static Future<void> restore(PickedBackup picked) async {
    await DbHelper.instance.replaceDatabase(picked.path);
    final deviceId = picked.info.deviceId;
    if (deviceId != null && deviceId.isNotEmpty) {
      await DeviceIdentity.adopt(deviceId);
    }
    await _discard(picked.path);
  }
}

/// A backup the user chose, read and accepted but not yet restored.
class PickedBackup {
  /// Where the picker put its copy. Valid until the restore is through or
  /// [discard] is called.
  final String path;
  final BackupInfo info;

  const PickedBackup(this.path, this.info);

  /// Throws the picked copy away again, for when the restore is called off.
  Future<void> discard() => BackupService._discard(path);
}
