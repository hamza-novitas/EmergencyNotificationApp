import 'dart:math' as math;

import 'package:flutter/material.dart';

class NovitasLogo extends StatelessWidget {
  const NovitasLogo({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _NovitasLogoPainter()),
    );
  }
}

class _NovitasLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final purple = const Color(0xFF6B3CFF);
    final stroke = size.width * 0.13;

    final arcPaint = Paint()
      ..color = purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final center = Offset(size.width / 2, size.height / 2);

    final outerRect = Rect.fromCircle(center: center, radius: size.width * 0.44);
    canvas.drawArc(outerRect, -2.72, 1.35, false, arcPaint);
    canvas.drawArc(outerRect, 0.42, 1.35, false, arcPaint);

    final innerRect = Rect.fromCircle(center: center, radius: size.width * 0.23);
    canvas.drawArc(innerRect, -0.1, 2.1, false, arcPaint);

    final wedgePaint = Paint()..color = purple;
    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + size.width * 0.03, center.dy + size.height * 0.18)
      ..lineTo(center.dx - size.width * 0.17, center.dy + size.height * 0.05)
      ..close();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 5.5);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(path, wedgePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
