import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseUrl = 'https://data.ratka.net/config/dartscore';

// Shared secret expected by register.php, supplied at build time via
// --dart-define so it never enters the source tree/git history (and is
// simply absent for anyone building the open-source code themselves).
// Must match the value deployed on the server.
const _apiKey = String.fromEnvironment('DEV_BUILD_API_KEY');

const _prefsDeviceIdKey = 'dev_build_device_id';

/// Remote status for this device's dev/test build, as controlled by the
/// developer through the JSON file stored on the config server.
class RemoteKillswitchStatus {
  final bool active;
  final DateTime expiry;

  const RemoteKillswitchStatus({required this.active, required this.expiry});
}

/// Loaded once at startup; `null` when the remote service could not be
/// reached (caller then falls back to the bundled expiry date).
RemoteKillswitchStatus? remoteKillswitchStatus;

/// Registers this install with the remote config service (device id, app
/// version/build) and fetches back its current status.
///
/// The server creates the device's JSON file on first contact with
/// `active: true` and today's date, then leaves `active`/`date` untouched on
/// later registrations — that's what lets the developer extend or disable a
/// single device's killswitch remotely (by editing that file) without
/// shipping a new build. Which device belongs to which tester is then a
/// matter of cross-referencing on the server (e.g. by `lastSeen`/`build`),
/// not something the app needs to know about. Returns `null` on any
/// network/parsing problem.
Future<RemoteKillswitchStatus?> checkRemoteKillswitch() async {
  // No key was baked in at build time (e.g. a self-built open-source copy) —
  // skip the remote call entirely and let the caller fall back to the
  // bundled expiry date.
  if (_apiKey.isEmpty) return null;

  try {
    final deviceId = await _deviceId();
    final pkg = await PackageInfo.fromPlatform();
    final build = '${pkg.version}+${pkg.buildNumber}';

    await http
        .post(
          Uri.parse('$_baseUrl/register.php'),
          headers: const {
            'Content-Type': 'application/json',
            'X-Api-Key': _apiKey,
          },
          body: jsonEncode({'device': deviceId, 'build': build}),
        )
        .timeout(const Duration(seconds: 5));

    final response = await http
        .get(Uri.parse('$_baseUrl/$deviceId.json'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final date = DateTime.parse(json['date'] as String);
    return RemoteKillswitchStatus(
      active: json['active'] == true,
      expiry: date.add(const Duration(days: 7)),
    );
  } catch (_) {
    return null;
  }
}

Future<String> _deviceId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_prefsDeviceIdKey);
  if (existing != null) return existing;

  final id = _randomId();
  await prefs.setString(_prefsDeviceIdKey, id);
  return id;
}

String _randomId() {
  final rnd = Random.secure();
  return List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
}
