import 'package:dartscore_app/screens/about_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The about screen and the two license screens it opens.
///
/// The version comes from a platform channel, which a widget test has to answer
/// itself: left unanswered it throws into the future the screen started in
/// `initState`, and the failure lands in whatever test is running by then.
void main() {
  const channel = MethodChannel('dev.fluttercommunity.plus/package_info');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <String, dynamic>{
              'appName':     'DartScore',
              'packageName': 'com.ratka.dartscore',
              'version':     '1.0.0',
              'buildNumber': '1',
            });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> pumpAbout(WidgetTester tester, Size size) async {
    usePhoneSurface(tester, size: size);
    await tester.pumpWidget(testApp(const AboutScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('reads the licence notice in a column, not across the tablet',
      (tester) async {
    await pumpAbout(tester, const Size(1180, 820));

    await tester.tap(find.text('License').last);
    await tester.pumpAndSettle();

    // The notice is a page of prose, so it keeps the width the rest of the app
    // reads at rather than running the whole way across.
    final notice =
        tester.getRect(find.textContaining('GNU General Public').last);
    expect(notice.width, lessThan(700));
    expect(notice.center.dx, closeTo(1180 / 2, 20));
  });

  testWidgets('keeps the packaged licenses under their master detail width',
      (tester) async {
    await pumpAbout(tester, const Size(1180, 820));

    await tester.tap(find.text('Open Source Licenses').last);
    await tester.pumpAndSettle();

    // Flutter's page divides itself into a list and a detail from 840 dp and
    // stutters in that layout; under the threshold it stays one column.
    expect(find.byType(LicensePage), findsOneWidget);
    expect(tester.getRect(find.byType(LicensePage)).width, lessThan(840));
  });
}
