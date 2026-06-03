// Run with:  flutter test tool/gen_icon_test.dart
// Renders the app icon to a 1024×1024 PNG and saves it to
// assets/icon/app_icon.png, ready for flutter_launcher_icons.

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dartscore_app/widgets/dartboard_icon.dart';

void main() {
  testWidgets('export dartboard as app icon PNG', (WidgetTester tester) async {
    const size = 1024.0;

    // ── Load a bold macOS system font so text renders properly ────────────
    const fontCandidates = [
      '/System/Library/Fonts/Helvetica.ttc',
      '/Library/Fonts/Arial Bold.ttf',
      '/System/Library/Fonts/SFNSDisplay.ttf',
      '/System/Library/Fonts/SFNS.ttf',
    ];
    String? loadedFamily;
    for (final path in fontCandidates) {
      final f = File(path);
      if (f.existsSync()) {
        final data = ByteData.sublistView(f.readAsBytesSync());
        final loader = FontLoader('_IconFont')..addFont(Future.value(data));
        await loader.load();
        loadedFamily = '_IconFont';
        break;
      }
    }

    // Give the test canvas enough room
    tester.view.physicalSize = const Size(size, size);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: SizedBox.expand(
            child: RepaintBoundary(
              child: Container(
                width: size,
                height: size,
                color: Colors.black,
                alignment: Alignment.center,
                child: CustomPaint(
                  size: const Size(size, size),
                  painter: _AppIconPainter(fontFamily: loadedFamily),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final outFile = File('assets/icon/app_icon.png');
    outFile.writeAsBytesSync(pngBytes);

    // ignore: avoid_print
    print('✅  Icon saved to ${outFile.absolute.path}  (${pngBytes.length} bytes)');
    expect(pngBytes.length, greaterThan(1000));
  });
}

/// Black background + dartboard (scaled, centred slightly high) +
/// bold "180" in red with a thick black outline at the bottom.
class _AppIconPainter extends CustomPainter {
  final String? fontFamily;
  const _AppIconPainter({this.fontFamily});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Black background ──────────────────────────────────────────────────
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    // ── Dartboard — full size, centred ────────────────────────────────────
    final boardSize = size.width * 0.92;
    final boardTop  = cy - boardSize / 2;
    canvas.save();
    canvas.translate(cx - boardSize / 2, boardTop);
    DartboardPainter().paint(canvas, Size(boardSize, boardSize));
    canvas.restore();

    // ── "180+" italic, centred on the bull ───────────────────────────────
    final fontSize = size.width * 0.27;
    // vertically centred on the board centre
    final textY = cy - fontSize * 0.60;

    void drawText(ui.Canvas c, String text, Color color, double strokeWidth) {
      final style = ui.TextStyle(
        color: strokeWidth == 0 ? color : null,
        foreground: strokeWidth > 0
            ? (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = color)
            : null,
        fontSize: fontSize,
        fontWeight: ui.FontWeight.w900,
        fontStyle: ui.FontStyle.italic,
        fontFamily: fontFamily,
      );
      final pb = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: ui.TextAlign.center,
        fontWeight: ui.FontWeight.w900,
        fontStyle: ui.FontStyle.italic,
        fontSize: fontSize,
        fontFamily: fontFamily,
      ))
        ..pushStyle(style)
        ..addText(text);
      final para = pb.build()
        ..layout(ui.ParagraphConstraints(width: size.width));
      c.drawParagraph(para, Offset(0, textY));
    }

    // 1. Thick black stroke (outline)
    drawText(canvas, '180+', Colors.black, fontSize * 0.18);
    // 2. Red fill on top
    drawText(canvas, '180+', const Color(0xFFD32F2F), 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
