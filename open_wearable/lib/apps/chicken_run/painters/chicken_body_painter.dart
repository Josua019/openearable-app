import 'package:flutter/material.dart';

/// Custom painter that draws the chicken avatar.
///
/// Renders the chicken's body, head, legs, wings, beak, comb, wattle, and eye.
/// Supports two animations:
/// - **Peck**: Rotates the head group downward around a neck pivot point.
/// - **Turn**: Shifts body parts horizontally with parallax (head moves most,
///   legs least) to create a 2.5D turning effect.
class ChickenBodyPainter extends CustomPainter {
  /// Whether the fox is currently active (enlarges the eye for a scared look).
  final bool isFoxActive;

  /// Peck animation offset (0–30), controls head rotation angle.
  final double peckOffset;

  /// Head turn value (-1.0 to 1.0), controls horizontal parallax shift.
  final double headTurn;

  ChickenBodyPainter({
    required this.isFoxActive,
    this.peckOffset = 0.0,
    this.headTurn = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Turn shifts: Calculate horizontal offsets for different body parts
    // to create a 2.5D parallax effect. Head moves most, body less, legs least.
    double headShift = headTurn * 20.0;
    double bodyShift = headTurn * 12.0;
    double legShift = headTurn * 8.0;

    // Draw Shadow
    paint.color = Colors.black.withValues(alpha: 0.1);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2 + legShift * 0.5, size.height - 10),
            width: 140,
            height: 20),
        paint);

    // Draw Legs
    paint.color = Color(0xFFE65100); // Dark Orange for contrast
    paint.strokeWidth = 6;
    paint.strokeCap = StrokeCap.round;
    // Left leg
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 40),
        Offset(size.width / 2 - 20 + legShift, size.height - 10), paint);
    // Foot
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 10),
        Offset(size.width / 2 - 10 + legShift, size.height - 5), paint);
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 10),
        Offset(size.width / 2 - 17 + legShift, size.height + 1), paint);
    canvas.drawLine(Offset(size.width / 2 - 20 + legShift, size.height - 10),
        Offset(size.width / 2 - 28 + legShift, size.height - 5), paint);

    // Right leg
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 40),
        Offset(size.width / 2 + 20 + legShift, size.height - 10), paint);
    // Foot
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 10),
        Offset(size.width / 2 + 34 + legShift, size.height - 5), paint);
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 10),
        Offset(size.width / 2 + 28 + legShift, size.height + 1), paint);
    canvas.drawLine(Offset(size.width / 2 + 20 + legShift, size.height - 10),
        Offset(size.width / 2 + 17 + legShift, size.height + 1), paint);

    paint.strokeWidth = 0;

    // BODY
    paint.color = Colors.white;
    // Main body oval
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width / 2 + bodyShift, size.height / 2 + 20),
            width: 140,
            height: 120),
        paint);

    // WING (Slightly darker or same color with shadow)
    paint.color = Color(0xFFF0F0F0);
    // Wing shape
    Path wingPath = Path();
    double wingShift = bodyShift * 1.2;
    wingPath.moveTo(size.width / 2 - 30 + wingShift, size.height / 2 + 10);
    wingPath.quadraticBezierTo(
        size.width / 2 + 10 + wingShift,
        size.height / 2 + 10,
        size.width / 2 + 20 + wingShift,
        size.height / 2 + 40);
    wingPath.quadraticBezierTo(
        size.width / 2 - 10 + wingShift,
        size.height / 2 + 60,
        size.width / 2 - 40 + wingShift,
        size.height / 2 + 40);
    canvas.drawPath(wingPath, paint);

    // HEAD GROUP (With Rotation for Peck)
    canvas.save();

    // Pivot point (Neck area approx)
    double pivotX = size.width / 2 + 20 + bodyShift;
    double pivotY = size.height / 2 - 20;

    canvas.translate(pivotX, pivotY);
    // peckOffset 0 -> 0 rotation, peckOffset 30 -> ~45 degrees down
    double rotation = (peckOffset / 30.0) * (3.14159 / 4); // Max 45 deg
    canvas.rotate(rotation);
    canvas.translate(-pivotX, -pivotY);

    // HEAD
    paint.color = Colors.white;
    canvas.drawCircle(
        Offset(size.width / 2 + 30 + headShift, size.height / 2 - 40),
        45,
        paint);

    // COMB (Red)
    paint.color = Color(0xFFE57373);
    canvas.drawCircle(
        Offset(size.width / 2 + 20 + headShift, size.height / 2 - 75),
        10,
        paint);
    canvas.drawCircle(
        Offset(size.width / 2 + 35 + headShift, size.height / 2 - 82),
        12,
        paint);
    canvas.drawCircle(
        Offset(size.width / 2 + 50 + headShift, size.height / 2 - 78),
        10,
        paint);

    // BEAK (Orange)
    paint.color = Color(0xFFE65100); // Dark Orange for contrast
    Path beakPath = Path();
    // Beak should pivot slightly to show direction
    beakPath.moveTo(size.width / 2 + 70 + headShift * 1.5,
        size.height / 2 - 45); // Tip moves more
    beakPath.lineTo(
        size.width / 2 + 90 + headShift * 1.5, size.height / 2 - 40);
    beakPath.lineTo(
        size.width / 2 + 70 + headShift * 1.5, size.height / 2 - 35);
    canvas.drawPath(beakPath, paint);

    // WATTLE (Red under beak)
    paint.color = Color(0xFFE57373);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(
                size.width / 2 + 65 + headShift * 1.3, size.height / 2 - 25),
            width: 10,
            height: 15),
        paint);

    // EYE (Black)
    paint.color = Color(0xFF333333);
    // Move eye less than beak for parallax
    canvas.drawCircle(
        Offset(size.width / 2 + 50 + headShift, size.height / 2 - 50),
        isFoxActive ? 6 : 4,
        paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ChickenBodyPainter oldDelegate) {
    return oldDelegate.isFoxActive != isFoxActive ||
        oldDelegate.peckOffset != peckOffset ||
        oldDelegate.headTurn != headTurn;
  }
}
