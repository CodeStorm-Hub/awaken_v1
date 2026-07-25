import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small self-contained rendering of the Google "G" mark, in Google's
/// fixed brand colors (never themed — that's the point of the mark, same
/// as every "Sign in with Google" button). Replaces `Icons.g_mobiledata`,
/// which is a mobile-data signal-strength glyph, not a Google logo, and
/// doesn't meet Google's sign-in button branding guidelines.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final stroke = size.width * 0.22;
    final ringRadius = radius - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: ringRadius);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four ~85° arcs (with small gaps) forming the ring, positioned to
    // match the real mark's color layout: blue right, green bottom, yellow
    // left, red top.
    const gap = 6 * math.pi / 180;
    void arc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        rect,
        startDeg * math.pi / 180,
        (sweepDeg * math.pi / 180) - gap,
        false,
        ringPaint..color = color,
      );
    }

    arc(-45, 90, _blue);
    arc(45, 90, _green);
    arc(135, 90, _yellow);
    arc(225, 90, _red);

    // The crossbar: a blue horizontal stroke from the ring's mid-right
    // point in toward the center, which is what turns a plain ring into a
    // "G".
    final barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = _blue;
    canvas.drawLine(
      Offset(center.dx + stroke * 0.15, center.dy),
      Offset(center.dx + ringRadius + stroke / 2, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
