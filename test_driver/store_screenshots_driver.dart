import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';
import 'package:path/path.dart' as p;

/// Host side of the store screenshot run: receives every picture
/// `integration_test/store_screenshots_test.dart` takes and writes it to disk.
///
/// The name the test passes carries the whole path under the raw folder
/// (`<device>/<theme>/<language>/<screen>`), so one run per device, theme and
/// language fills the tree that `tool/compose_store_screenshots.dart` reads.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File(p.join('store_assets', 'screenshots', 'raw', '$name.png'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
