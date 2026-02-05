import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final Widget child;
  const ParticleBackground({super.key, required this.child});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_P> ps;
  final rnd = Random();

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    ps = List.generate(28, (_) => _P.random(rnd));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return CustomPaint(
          painter: _ParticlePainter(ps, _c.value),
          child: widget.child,
        );
      },
    );
  }
}

class _P {
  final double x, y, r, speed, phase;
  _P(this.x, this.y, this.r, this.speed, this.phase);
  factory _P.random(Random rnd) => _P(
        rnd.nextDouble(),
        rnd.nextDouble(),
        rnd.nextDouble() * 1.8 + .6,
        rnd.nextDouble() * .4 + .1,
        rnd.nextDouble() * 6.28,
      );
}

class _ParticlePainter extends CustomPainter {
  final List<_P> ps;
  final double t;
  _ParticlePainter(this.ps, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final s in ps) {
      final dx = (s.x + (t + s.phase) * s.speed) % 1.0;
      final dy = s.y;
      canvas.drawCircle(Offset(dx * size.width, dy * size.height), s.r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}