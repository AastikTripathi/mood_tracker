import 'package:flutter/material.dart';
import '../models/firefly.dart';

class FireflyPainter extends CustomPainter {
  final List<Firefly> fireflies;

  FireflyPainter(this.fireflies);

  @override
  void paint(Canvas canvas, Size size) {
    for (var f in fireflies) {
      final Paint glowPaint = Paint()
        ..color = const Color(0xFFFDE047).withOpacity(0.18)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final Paint corePaint = Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.fill;

      Offset pixelPos = Offset(
        f.position.dx * size.width,
        f.position.dy * size.height,
      );

      canvas.drawCircle(pixelPos, f.size * 3.5, glowPaint);
      canvas.drawCircle(pixelPos, f.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant FireflyPainter oldDelegate) => true;
}