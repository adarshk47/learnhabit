import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SpeedGauge extends StatefulWidget {
  final double speed;
  final double maxSpeed;

  const SpeedGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 160,
  });

  @override
  State<SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<SpeedGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _speedAnimation;
  double _prevSpeed = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _speedAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(SpeedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _speedAnimation = Tween<double>(
        begin: _prevSpeed,
        end: widget.speed,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _prevSpeed = widget.speed;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _speedColor(double speed) {
    if (speed < 40) return AppTheme.neonGreen;
    if (speed < 70) return AppTheme.neonAmber;
    if (speed < 100) return Colors.orange;
    return AppTheme.neonRed;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _speedAnimation,
      builder: (context, child) {
        final spd = _speedAnimation.value;
        final color = _speedColor(spd);
        return SizedBox(
          width: 240,
          height: 240,
          child: CustomPaint(
            painter: _GaugePainter(
              speed: spd,
              maxSpeed: widget.maxSpeed,
              color: color,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spd.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: color,
                      shadows: [
                        Shadow(color: color.withOpacity(0.8), blurRadius: 20),
                      ],
                    ),
                  ),
                  Text(
                    'km/h',
                    style: AppTheme.labelSmall.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final Color color;

  _GaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i <= 16; i++) {
      final angle = startAngle + (sweepAngle / 16) * i;
      final isMajor = i % 4 == 0;
      final outerR = radius + 2;
      final innerR = radius - (isMajor ? 14 : 8);
      canvas.drawLine(
        Offset(center.dx + outerR * math.cos(angle),
            center.dy + outerR * math.sin(angle)),
        Offset(center.dx + innerR * math.cos(angle),
            center.dy + innerR * math.sin(angle)),
        tickPaint,
      );
    }

    // Glow arc
    if (speed > 0) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * (speed / maxSpeed).clamp(0, 1),
        false,
        glowPaint,
      );

      // Active arc
      final arcPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [AppTheme.neonGreen, AppTheme.neonAmber, color],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * (speed / maxSpeed).clamp(0, 1),
        false,
        arcPaint,
      );
    }

    // Needle tip dot
    final tipAngle =
        startAngle + sweepAngle * (speed / maxSpeed).clamp(0, 1);
    final tipOffset = Offset(
      center.dx + (radius - 4) * math.cos(tipAngle),
      center.dy + (radius - 4) * math.sin(tipAngle),
    );
    canvas.drawCircle(
      tipOffset,
      8,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(tipOffset, 5, Paint()..color = color);

    // Inner ring
    canvas.drawCircle(
      center,
      radius - 28,
      Paint()
        ..color = Colors.white.withOpacity(0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.speed != speed || old.color != color;
}
