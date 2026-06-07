import 'dart:convert';
import 'package:flutter/services.dart';

/// Optional metadata for dev/test builds, read from `assets/dev_build/info.json`.
///
/// Set `active` to `true` and fill in `name`/`date` before building a build
/// meant for external testers, then revert to `active: false` afterwards.
/// When inactive (the default for release builds), [load] returns `null` and
/// no expiry check is performed.
class DevBuildInfo {
  final String name;
  final DateTime buildDate;

  const DevBuildInfo({required this.name, required this.buildDate});

  DateTime get expiry => buildDate.add(const Duration(days: 7));

  static Future<DevBuildInfo?> load() async {
    try {
      final raw = await rootBundle.loadString('assets/dev_build/info.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['active'] != true) return null;
      return DevBuildInfo(
        name: json['name'] as String,
        buildDate: DateTime.parse(json['date'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Loaded once at startup; `null` for regular release builds.
DevBuildInfo? devBuildInfo;
