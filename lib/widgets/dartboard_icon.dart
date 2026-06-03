import 'dart:math';
import 'package:flutter/material.dart';

/// A classic dartboard drawn with CustomPainter.
/// Use [size] to control the diameter.
class DartboardIcon extends StatelessWidget {
  final double size;
  const DartboardIcon({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: DartboardPainter()),
    );
  }
}

class DartboardPainter extends CustomPainter {
  // Segment colours: alternating black / cream, red / green for scoring rings
  static const _black  = Color(0xFF1A1A1A);
  static const _cream  = Color(0xFFF5E6C8);
  static const _red    = Color(0xFFC0392B);
  static const _green  = Color(0xFF1E7A3C);
  static const _wire   = Color(0xFF888888);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = min(cx, cy);

    // Radii as fractions of the full board radius
    final rBull      = r * 0.055;  // inner bull (red)
    final rBullOuter = r * 0.115;  // outer bull (green)
    final rTriple1   = r * 0.470;  // inner edge of triple ring
    final rTriple2   = r * 0.540;  // outer edge of triple ring
    final rDouble1   = r * 0.840;  // inner edge of double ring
    final rDouble2   = r * 0.940;  // outer edge of double ring (scoring)
    final rBoard     = r * 0.970;  // outer black wire rim
    final rOuter     = r * 1.000;  // outermost circle (raised rim)

    const n       = 20;
    const sweep   = (2 * pi) / n;
    // Segments start at -90° (top) minus half a segment so the 20 is centred at top
    const startAngle = -pi / 2 - sweep / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    // ── 1. Outer rim (dark gray) ─────────────────────────────────────────
    paint.color = const Color(0xFF2A2A2A);
    canvas.drawCircle(Offset(cx, cy), rOuter, paint);

    // ── 2. Black board background ────────────────────────────────────────
    paint.color = _black;
    canvas.drawCircle(Offset(cx, cy), rBoard, paint);

    // ── 3. Segments – single / double / triple ───────────────────────────
    for (int i = 0; i < n; i++) {
      final angle = startAngle + i * sweep;
      final isEven = i % 2 == 0;

      // colours for this segment pair
      final baseColor     = isEven ? _black  : _cream;
      final scoringColor  = isEven ? _red    : _green;

      // Single outer (between double outer and board edge) — black/cream
      _drawSector(canvas, cx, cy, rDouble2, rBoard, angle, sweep,
          paint, baseColor);

      // Double ring — red/green
      _drawSector(canvas, cx, cy, rDouble1, rDouble2, angle, sweep,
          paint, scoringColor);

      // Single inner (between triple outer and double inner) — black/cream
      _drawSector(canvas, cx, cy, rTriple2, rDouble1, angle, sweep,
          paint, baseColor);

      // Triple ring — red/green
      _drawSector(canvas, cx, cy, rTriple1, rTriple2, angle, sweep,
          paint, scoringColor);

      // Single inner inner (between bull outer and triple inner) — black/cream
      _drawSector(canvas, cx, cy, rBullOuter, rTriple1, angle, sweep,
          paint, baseColor);
    }

    // ── 4. Outer bull (green) ────────────────────────────────────────────
    paint.color = _green;
    canvas.drawCircle(Offset(cx, cy), rBullOuter, paint);

    // ── 5. Inner bull / bullseye (red) ───────────────────────────────────
    paint.color = _red;
    canvas.drawCircle(Offset(cx, cy), rBull, paint);

    // ── 6. Wire lines between segments (thin, subtle) ────────────────────
    final wirePaint = Paint()
      ..color = _wire.withValues(alpha: 0.55)
      ..strokeWidth = r * 0.012
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < n; i++) {
      final angle = startAngle + i * sweep;
      final dx = cos(angle);
      final dy = sin(angle);
      canvas.drawLine(
        Offset(cx + dx * rBullOuter, cy + dy * rBullOuter),
        Offset(cx + dx * rBoard,     cy + dy * rBoard),
        wirePaint,
      );
    }

    // Ring wires
    for (final rad in [rTriple1, rTriple2, rDouble1, rDouble2, rBoard]) {
      canvas.drawCircle(Offset(cx, cy), rad, wirePaint);
    }

    // Bullseye wire
    wirePaint.strokeWidth = r * 0.010;
    canvas.drawCircle(Offset(cx, cy), rBullOuter, wirePaint);
    canvas.drawCircle(Offset(cx, cy), rBull, wirePaint);
  }

  void _drawSector(
    Canvas canvas,
    double cx, double cy,
    double innerR, double outerR,
    double startAngle, double sweep,
    Paint paint,
    Color color,
  ) {
    paint.color = color;
    final path = Path()
      ..moveTo(cx + innerR * cos(startAngle), cy + innerR * sin(startAngle))
      ..lineTo(cx + outerR * cos(startAngle), cy + outerR * sin(startAngle))
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: outerR),
        startAngle, sweep, false,
      )
      ..lineTo(
        cx + innerR * cos(startAngle + sweep),
        cy + innerR * sin(startAngle + sweep),
      )
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: innerR),
        startAngle + sweep, -sweep, false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
