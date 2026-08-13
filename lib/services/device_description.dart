import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What this device calls itself, for the other end of a transfer to read.
///
/// A sync packet and a backup both carry a label naming where they came from,
/// and "iPhone" or "Android" stopped being enough the moment two devices of the
/// same kind were involved. This resolves the closest thing each platform will
/// give to a device name, with the operating system after it in brackets.
///
/// Both halves are written by hand, in `DeviceDescriptionHandler.swift` and
/// `MainActivity.kt`, for the reason the document picker is: a package for this
/// would pull CocoaPods onto the iOS side, and the plus_plugins family that
/// covers it is already held back in `pubspec.yaml` over the Kotlin plugin.
class DeviceDescription {
  static const MethodChannel _channel =
      MethodChannel('dartscore/device_description');

  /// Resolved once and kept: nothing it reads changes while the app runs.
  static String? _cached;

  /// The label to put on anything leaving this device, for example
  /// "iPhone 15 Pro (iOS 18.5)" or "Niklas' S23 (Android 14)".
  ///
  /// Falls back to the platform's name alone if the channel cannot answer,
  /// which is what the label was before it carried anything else. Never throws:
  /// a transfer must not fail over what it is called.
  static Future<String> get label async {
    if (_cached != null) return _cached!;
    try {
      final info = await _channel.invokeMapMethod<String, String>('describe');
      final name = info?['name'];
      final os   = info?['os'];
      if (name != null && name.isNotEmpty) {
        _cached = os == null || os.isEmpty
            ? resolveName(name)
            : '${resolveName(name)} ($os)';
        return _cached!;
      }
    } catch (_) {
      // Falls through to the plain name below.
    }
    return _cached ??= defaultTargetPlatform == TargetPlatform.iOS
        ? 'iPhone'
        : 'Android';
  }

  /// Turns what the platform reported into what a person would recognise.
  ///
  /// Android already answers with something readable, so this only has work to
  /// do on iOS, where the readable name is not available at all: since iOS 16,
  /// `UIDevice.name` returns the model rather than the name the owner gave the
  /// device, unless the app carries an entitlement Apple grants case by case.
  /// The best left is the model identifier, which is a code
  /// ("iPhone16,1") and has to be looked up.
  ///
  /// An identifier that is not in the table is returned unchanged rather than
  /// guessed at. It stays unique and readable enough to tell two devices apart,
  /// and naming a device wrongly would be worse than naming it dryly.
  @visibleForTesting
  static String resolveName(String reported) =>
      _appleModelNames[reported] ?? reported;

  /// Marketing names for the model identifiers iOS reports.
  ///
  /// Only entries that are certain are listed. This needs a line adding for
  /// each new generation; until it gets one, that generation falls back to its
  /// identifier, which is the visible sign that it is due.
  static const Map<String, String> _appleModelNames = {
    'iPhone10,1': 'iPhone 8',        'iPhone10,4': 'iPhone 8',
    'iPhone10,2': 'iPhone 8 Plus',   'iPhone10,5': 'iPhone 8 Plus',
    'iPhone10,3': 'iPhone X',        'iPhone10,6': 'iPhone X',
    'iPhone11,2': 'iPhone XS',
    'iPhone11,4': 'iPhone XS Max',   'iPhone11,6': 'iPhone XS Max',
    'iPhone11,8': 'iPhone XR',
    'iPhone12,1': 'iPhone 11',
    'iPhone12,3': 'iPhone 11 Pro',
    'iPhone12,5': 'iPhone 11 Pro Max',
    'iPhone12,8': 'iPhone SE',
    'iPhone13,1': 'iPhone 12 mini',
    'iPhone13,2': 'iPhone 12',
    'iPhone13,3': 'iPhone 12 Pro',
    'iPhone13,4': 'iPhone 12 Pro Max',
    'iPhone14,4': 'iPhone 13 mini',
    'iPhone14,5': 'iPhone 13',
    'iPhone14,2': 'iPhone 13 Pro',
    'iPhone14,3': 'iPhone 13 Pro Max',
    'iPhone14,6': 'iPhone SE',
    'iPhone14,7': 'iPhone 14',
    'iPhone14,8': 'iPhone 14 Plus',
    'iPhone15,2': 'iPhone 14 Pro',
    'iPhone15,3': 'iPhone 14 Pro Max',
    'iPhone15,4': 'iPhone 15',
    'iPhone15,5': 'iPhone 15 Plus',
    'iPhone16,1': 'iPhone 15 Pro',
    'iPhone16,2': 'iPhone 15 Pro Max',
    'iPhone17,1': 'iPhone 16 Pro',
    'iPhone17,2': 'iPhone 16 Pro Max',
    'iPhone17,3': 'iPhone 16',
    'iPhone17,4': 'iPhone 16 Plus',
    'iPhone17,5': 'iPhone 16e',
  };

  /// Fixes the label for a test, or clears it again with null.
  @visibleForTesting
  static void debugSetLabel(String? label) => _cached = label;
}
