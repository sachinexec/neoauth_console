import 'package:flutter/material.dart';

/// The logo's own colours, the same in light and dark: the theme's seed
/// (0xFF3355CC) deepened at one end and pushed to violet at the other.
abstract final class LogoColors {
  static const deep = Color(0xFF1E2E8F);
  static const bright = Color(0xFF7C5CFF);
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deep, bright],
  );
}

/// The mark: a keyhole in a shield — sign-in, guarded — on a rounded square.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'NeoAuth Console',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LogoColors.gradient,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: const AppLogoMark(),
      ),
    );
  }
}

/// The white mark alone, filling its box, for drawing on any background (the
/// launcher icons draw it over their own). The shield spans 0.23–0.77 across
/// and 0.16–0.85 down.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _MarkPainter(), size: Size.infinite);
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    // Flat shoulders, straight sides, curving in to a point.
    final shield = Path()
      ..moveTo(0.50 * s, 0.16 * s)
      ..cubicTo(0.58 * s, 0.21 * s, 0.68 * s, 0.24 * s, 0.77 * s, 0.24 * s)
      ..lineTo(0.77 * s, 0.47 * s)
      ..cubicTo(0.77 * s, 0.66 * s, 0.65 * s, 0.78 * s, 0.50 * s, 0.85 * s)
      ..cubicTo(0.35 * s, 0.78 * s, 0.23 * s, 0.66 * s, 0.23 * s, 0.47 * s)
      ..lineTo(0.23 * s, 0.24 * s)
      ..cubicTo(0.32 * s, 0.24 * s, 0.42 * s, 0.21 * s, 0.50 * s, 0.16 * s)
      ..close();
    canvas.drawPath(shield, Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.045
        ..strokeJoin = StrokeJoin.round,
    );

    // Keyhole: a round head over a flared slot.
    final keyhole = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(0.50 * s, 0.44 * s), 0.075 * s, keyhole);
    canvas.drawPath(
      Path()
        ..moveTo(0.475 * s, 0.47 * s)
        ..lineTo(0.525 * s, 0.47 * s)
        ..lineTo(0.548 * s, 0.65 * s)
        ..lineTo(0.452 * s, 0.65 * s)
        ..close(),
      keyhole..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}
