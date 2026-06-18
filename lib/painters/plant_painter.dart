import 'dart:math' as math;
import 'package:flutter/material.dart';

class PlantPainter extends CustomPainter {
  final double growthProgress;
  final double bloomProgress;
  final bool isTwilight;
  final bool isCloudy;
  final double sway;
  final Set<String> completedHabits;
  final String plantId;

  PlantPainter({
    required this.growthProgress,
    required this.bloomProgress,
    required this.isTwilight,
    required this.isCloudy,
    required this.sway,
    required this.completedHabits,
    required this.plantId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Color trunkColor = isTwilight ? const Color(0xFF3F3F46) : const Color(0xFF78350F);
    if (plantId == 'bonsai') {
      trunkColor = isTwilight ? const Color(0xFF27272A) : const Color(0xFF451A03); // Darker gnarled trunk
    }

    final Paint woodPaint = Paint()
      ..color = trunkColor
      ..strokeWidth = (plantId == 'bonsai' ? 8.0 : 6.0) * growthProgress // Bonsai has thicker trunk
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final Offset rootPoint = Offset(size.width / 2, size.height - 40);

    final Paint potPaint = Paint()
      ..color = isTwilight ? const Color(0xFF1E293B) : const Color(0xFFFDBA74)
      ..style = PaintingStyle.fill;

    final Path potPath = Path()
      ..moveTo(size.width / 2 - 35, size.height - 40)
      ..lineTo(size.width / 2 + 35, size.height - 40)
      ..lineTo(size.width / 2 + 25, size.height - 10)
      ..lineTo(size.width / 2 - 25, size.height - 10)
      ..close();

    canvas.drawPath(potPath, potPaint);

    double initialLength = 75.0 * growthProgress;
    _drawBranch(canvas, rootPoint, -math.pi / 2, initialLength, woodPaint, 1);
  }

  void _drawBranch(Canvas canvas, Offset start, double angle, double length, Paint paint, int depth) {
    if (depth > 4) return;

    double currentSway = sway * (depth * 0.8);
    Offset end = Offset(
      start.dx + math.cos(angle + currentSway) * length,
      start.dy + math.sin(angle + currentSway) * length,
    );

    paint.strokeWidth = math.max(1.5, paint.strokeWidth * 0.7);
    canvas.drawLine(start, end, paint);

    if (depth >= 2) {
      _drawLeaf(canvas, end, angle + currentSway + math.pi / 4, depth * 2);
      _drawLeaf(canvas, end, angle + currentSway - math.pi / 4, depth * 2 + 1);
    }

    if (depth == 4 && bloomProgress > 0) {
      _drawFlower(canvas, end);
    }

    double branchReduction = 0.75;
    double splitAngle = 0.45;

    _drawBranch(canvas, end, angle - splitAngle, length * branchReduction, paint, depth + 1);
    _drawBranch(canvas, end, angle + splitAngle, length * branchReduction, paint, depth + 1);
  }

  void _drawLeaf(Canvas canvas, Offset point, double angle, int leafIndex) {
    final List<String> habitsList = completedHabits.toList();
    String? habitId;
    if (habitsList.isNotEmpty) {
      habitId = habitsList[leafIndex % habitsList.length];
    }

    Paint leafPaint = Paint()..style = PaintingStyle.fill;
    
    // Default colors based on plantId
    Color leafColor;
    if (plantId == 'bonsai') {
      leafColor = isTwilight ? const Color(0xFF14532D) : const Color(0xFF064E3B); // Dark evergreen
    } else if (plantId == 'lavender') {
      leafColor = isTwilight ? const Color(0xFF4C1D95) : const Color(0xFF6D28D9); // Violet tints
    } else if (plantId == 'sakura') {
      leafColor = isTwilight ? const Color(0xFF831843) : const Color(0xFF9D174D); // Deep pinkish green
    } else {
      leafColor = isTwilight
          ? const Color(0xFF312E81)
          : (isCloudy ? const Color(0xFF34D399).withOpacity(0.6) : const Color(0xFF10B981));
    }

    // Custom coloring and shaping per habit
    if (habitId != null) {
      if (habitId == '1' || habitId.toLowerCase().contains('outside') || habitId.toLowerCase().contains('sun')) {
        // Stepped Outside - Sunset Amber
        leafColor = isTwilight ? const Color(0xFFB45309) : const Color(0xFFF59E0B);
      } else if (habitId == '2' || habitId.toLowerCase().contains('rest') || habitId.toLowerCase().contains('sleep')) {
        // Rested Well - Cozy Gold
        leafColor = isTwilight ? const Color(0xFF78350F) : const Color(0xFFFFD700);
      } else if (habitId == '3' || habitId.toLowerCase().contains('water') || habitId.toLowerCase().contains('drink')) {
        // Drank Water - Pure Sky Blue
        leafColor = isTwilight ? const Color(0xFF1E3A8A) : const Color(0xFF0EA5E9);
      } else if (habitId == '5' || habitId.toLowerCase().contains('read') || habitId.toLowerCase().contains('book')) {
        // Read a Book - Sage/Teal
        leafColor = isTwilight ? const Color(0xFF065F46) : const Color(0xFF14B8A6);
      }
    }

    leafPaint.color = leafColor;

    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(angle);

    double restFold = isTwilight ? 0.35 : 1.0;
    Path leafPath = Path();

    if (habitId == '3') {
      // Drank Water -> Teardrop shape leaf
      leafPath.moveTo(0, 0);
      leafPath.cubicTo(8 * restFold, -14 * restFold, 16 * restFold, -4 * restFold, 24 * restFold, 0);
      leafPath.cubicTo(16 * restFold, 4 * restFold, 8 * restFold, 14 * restFold, 0, 0);
      leafPath.close();
    } else if (habitId == '2') {
      // Rested Well -> Rounder/Heart shape leaf
      leafPath.moveTo(0, 0);
      leafPath.quadraticBezierTo(14 * restFold, -14 * restFold, 18 * restFold, 0);
      leafPath.quadraticBezierTo(14 * restFold, 14 * restFold, 0, 0);
      leafPath.close();
    } else if (habitId == '1') {
      // Stepped Outside -> Broad leaf
      leafPath.moveTo(0, 0);
      leafPath.quadraticBezierTo(12 * restFold, -16 * restFold, 26 * restFold, 0);
      leafPath.quadraticBezierTo(12 * restFold, 16 * restFold, 0, 0);
      leafPath.close();
    } else {
      // Standard leaf
      leafPath.moveTo(0, 0);
      leafPath.quadraticBezierTo(10 * restFold, -12 * restFold, 24 * restFold, 0);
      leafPath.quadraticBezierTo(10 * restFold, 12 * restFold, 0, 0);
      leafPath.close();
    }

    canvas.drawPath(leafPath, leafPaint);
    canvas.restore();
  }

  void _drawFlower(Canvas canvas, Offset point) {
    Color petalColor = isTwilight ? const Color(0xFFA5B4FC) : const Color(0xFFFCA5A5);
    Color coreColor = const Color(0xFFFEF08A);

    if (plantId == 'lavender') {
      petalColor = isTwilight ? const Color(0xFF7C3AED) : const Color(0xFFC084FC); // Purple blooms
      coreColor = const Color(0xFFDDD6FE);
    } else if (plantId == 'sakura') {
      petalColor = isTwilight ? const Color(0xFFF472B6) : const Color(0xFFFBCFE8); // Sakura Pink
      coreColor = const Color(0xFFFFF1F2);
    } else if (plantId == 'bonsai') {
      petalColor = isTwilight ? const Color(0xFFE2E8F0) : Colors.white; // Tiny white blossoms
      coreColor = const Color(0xFFFDE047);
    }

    final Paint petalPaint = Paint()
      ..color = petalColor
      ..style = PaintingStyle.fill;

    final Paint corePaint = Paint()
      ..color = coreColor
      ..style = PaintingStyle.fill;

    double size = 7.0 * bloomProgress;

    if (isTwilight) {
      canvas.drawCircle(point, size * 0.8, petalPaint);
      canvas.drawCircle(point, size * 0.4, coreColor == const Color(0xFFDDD6FE) ? corePaint : corePaint);
      return;
    }

    for (int i = 0; i < 5; i++) {
      double angle = (i * 2 * math.pi) / 5;
      Offset petalOffset = Offset(
        point.dx + math.cos(angle) * (size * 0.8),
        point.dy + math.sin(angle) * (size * 0.8),
      );
      canvas.drawCircle(petalOffset, size * 0.6, petalPaint);
    }
    canvas.drawCircle(point, size * 0.4, corePaint);
  }

  @override
  bool shouldRepaint(covariant PlantPainter oldDelegate) {
    return oldDelegate.growthProgress != growthProgress ||
        oldDelegate.bloomProgress != bloomProgress ||
        oldDelegate.isTwilight != isTwilight ||
        oldDelegate.isCloudy != isCloudy ||
        oldDelegate.sway != sway ||
        oldDelegate.plantId != plantId ||
        oldDelegate.completedHabits.length != completedHabits.length;
  }
}