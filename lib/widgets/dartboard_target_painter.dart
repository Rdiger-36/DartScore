import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Standard dartboard segment order (clockwise from top)
const _order = [
  20, 1, 18, 4, 13, 6, 10, 15, 2, 17,
  3, 19, 7, 16, 8, 11, 14, 9, 12, 5,
];

/// Paints a dartboard with the given [target] segment highlighted.
///
/// When [highlightMultipliers] is null, all rings of the target segment are
/// highlighted. When provided, only the listed multipliers (1=single,
/// 2=double, 3=triple) are highlighted — used for the full-segments variant.
class DartboardTargetPainter extends CustomPainter {
  final int target;
  final Set<int>? highlightMultipliers;
  final Color highlightColor;
  final Color onSurfaceColor;

  const DartboardTargetPainter({
    required this.target,
    required this.highlightColor,
    required this.onSurfaceColor,
    this.highlightMultipliers,
  });

  bool _highlighted(int multiplier) =>
      highlightMultipliers == null || highlightMultipliers!.contains(multiplier);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = min(cx, cy);
    final center = Offset(cx, cy);

    final rBullInner = r * 0.050;
    final rBull      = r * 0.110;
    final rTriple1   = r * 0.445;
    final rTriple2   = r * 0.505;
    final rDouble1   = r * 0.705;
    final rDouble2   = r * 0.780;

    final segCount   = _order.length;
    final angleStep  = (2 * pi) / segCount;
    final halfStep   = angleStep / 2;
    final startAngle = -pi / 2 - halfStep;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final wirePaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.01;

    void drawRing(double r1, double r2, double a0, double sweep, Color fill) {
      final path = Path();
      path.moveTo(center.dx + r1 * cos(a0), center.dy + r1 * sin(a0));
      path.arcTo(Rect.fromCircle(center: center, radius: r2), a0, sweep, false);
      path.arcTo(Rect.fromCircle(center: center, radius: r1), a0 + sweep, -sweep, false);
      path.close();
      fillPaint.color = fill;
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, wirePaint);
    }

    for (var i = 0; i < segCount; i++) {
      final field = _order[i];
      final a0 = startAngle + i * angleStep;
      final isTargetField = field == target && target != 25;
      final base = onSurfaceColor.withValues(alpha: i.isEven ? 0.08 : 0.03);

      Color ringColor(int multiplier) {
        if (!isTargetField || !_highlighted(multiplier)) return base;
        return highlightColor.withValues(alpha: 0.55);
      }

      drawRing(rBull, rTriple1, a0, angleStep, ringColor(1));
      drawRing(rTriple1, rTriple2, a0, angleStep, ringColor(3));
      drawRing(rTriple2, rDouble1, a0, angleStep, ringColor(1));
      drawRing(rDouble1, rDouble2, a0, angleStep, ringColor(2));
    }

    final bullIsTarget = target == 25;
    fillPaint.color = (bullIsTarget && _highlighted(1))
        ? highlightColor.withValues(alpha: 0.55)
        : onSurfaceColor.withValues(alpha: 0.08);
    canvas.drawCircle(center, rBull, fillPaint);
    canvas.drawCircle(center, rBull, wirePaint);
    fillPaint.color = (bullIsTarget && _highlighted(2))
        ? highlightColor.withValues(alpha: 0.8)
        : onSurfaceColor.withValues(alpha: 0.16);
    canvas.drawCircle(center, rBullInner, fillPaint);
    canvas.drawCircle(center, rBullInner, wirePaint);

    canvas.drawCircle(center, rDouble2, wirePaint);

    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i < segCount; i++) {
      final field = _order[i];
      final isTargetNum = field == target;
      final angle = startAngle + i * angleStep + halfStep;
      final labelR = r * 0.93;
      final lx = cx + labelR * cos(angle);
      final ly = cy + labelR * sin(angle);

      tp.text = TextSpan(
        text: '$field',
        style: TextStyle(
          fontSize: r * (isTargetNum ? 0.135 : 0.10),
          fontWeight: isTargetNum ? FontWeight.bold : FontWeight.w500,
          color: isTargetNum
              ? highlightColor
              : onSurfaceColor.withValues(alpha: 0.7),
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(lx - tp.width / 2, ly - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant DartboardTargetPainter old) =>
      old.target != target ||
      old.highlightMultipliers != highlightMultipliers ||
      old.highlightColor != highlightColor;
}
