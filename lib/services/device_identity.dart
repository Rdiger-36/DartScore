import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// This device's identity in a sync, stable for as long as the app stays
/// installed.
///
/// A sync only stays correct in both directions if the receiving device can
/// tell whose data it is looking at: its own, the sender's, or something the
/// sender in turn received from a third device. The label a packet carries
/// beside this ("iPhone", "Android") is for the user to read and says nothing
/// about which device it was.
class DeviceIdentity {
  /// Where the id is kept between launches.
  static const _kPrefsKey = 'sync_device_id';

  /// Characters an id is built from: unambiguous to read, and all inside the
  /// QR alphanumeric set so an id never costs a code its dense mode.
  static const _kAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// 16 characters out of 32 symbols, so two devices colliding is not a case
  /// worth handling.
  static const _kLength = 16;

  static String? _cached;

  /// This device's id, generated and persisted on first use.
  static Future<String> get id async {
    final cached = _cached;
    if (cached != null) return cached;

    final prefs = await SharedPreferences.getInstance();
    var stored = prefs.getString(_kPrefsKey);

    if (stored == null || stored.isEmpty) {
      final random = Random.secure();
      stored = List.generate(
          _kLength, (_) => _kAlphabet[random.nextInt(_kAlphabet.length)]).join();
      await prefs.setString(_kPrefsKey, stored);
    }

    return _cached = stored;
  }

  /// Pins the id, or clears the cache when given null. Tests act out two
  /// devices in one process and need to say which one is speaking.
  @visibleForTesting
  static void debugSetId(String? id) => _cached = id;
}
