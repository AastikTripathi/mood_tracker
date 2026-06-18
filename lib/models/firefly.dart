import 'dart:ui';

/// Represents a single floating firefly particle in Twilight mode.
class Firefly {
  Offset position;
  double speed;
  double angle;
  double size;

  Firefly({
    required this.position,
    required this.speed,
    required this.angle,
    required this.size,
  });
}