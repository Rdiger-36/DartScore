import 'package:dartscore_app/screens/licenses_screen.dart';
import 'package:dartscore_app/utils/layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The packaged licenses, read out of the registry the app fills at startup.
///
/// The registry is global, so every test puts its own entries in and resets it
/// afterwards; left over entries would show up in whatever test runs next.
void main() {
  setUp(() {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(() async* {
      yield const LicenseEntryWithLineBreaks(['alpha'], 'Alpha license text.');
      yield const LicenseEntryWithLineBreaks(['beta'], 'Beta license text.');
      // One entry covering two packages is listed under both, the way the
      // registry means it.
      yield const LicenseEntryWithLineBreaks(
          ['alpha', 'gamma'], 'Shared license text.');
    });
  });

  tearDown(LicenseRegistry.reset);

  /// Pumps the screen and lets the registry be read.
  Future<void> pumpLicenses(WidgetTester tester, Size size) async {
    usePhoneSurface(tester, size: size);
    await tester.pumpWidget(testApp(const LicensesScreen()));
    await pumpUntilLoaded(tester);
  }

  testWidgets('lists every package, and a package under each of its licenses',
      (tester) async {
    await pumpLicenses(tester, const Size(400, 900));

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
    // Alpha carries its own license and the shared one.
    expect(find.text('2 licenses'), findsOneWidget);
    expect(find.text('1 license'), findsNWidgets(2));
  });

  testWidgets('opens a license beside the list on a tablet', (tester) async {
    await pumpLicenses(tester, const Size(1180, 820));

    expect(find.byKey(kPaneDividerKey), findsOneWidget);
    expect(find.textContaining('Pick a package'), findsOneWidget);

    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    // Beside: the list is still there, and the text stands to the right of it.
    final list = tester.getRect(find.byType(ListView).first);
    final text = tester.getRect(find.text('Alpha license text.'));
    expect(text.left, greaterThan(list.right));
    expect(find.text('Shared license text.'), findsOneWidget);
    expect(find.textContaining('Pick a package'), findsNothing);
  });

  testWidgets('opens it on top of the list on a phone', (tester) async {
    await pumpLicenses(tester, const Size(400, 900));

    expect(find.byKey(kPaneDividerKey), findsNothing);

    await tester.tap(find.text('beta'));
    await tester.pumpAndSettle();

    // Its own screen, with the bars that belong to one: the list is gone.
    expect(find.text('Beta license text.'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);
  });
}
