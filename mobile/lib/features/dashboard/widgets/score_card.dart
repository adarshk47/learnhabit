import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ScoreCard extends StatefulWidget {
  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final IconData icon;
  final bool invertColor;

  const ScoreCard({
    super.key,
    required this.label,
    required this.value,
    this.maxValue = 100,
    required this.color,
    required this.icon,
    this.invertColor = false,
  });

  @override
  State<ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<ScoreCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _valueAnim;
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _valueAnim = Tween<double>(begin: 0, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(ScoreCard old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _valueAnim = Tween<double>(begin: _prev, end: widget.value).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _prev = widget.value;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _dynamicColor(double v) {
    if (!widget.invertColor) return widget.color;
    final ratio = v / widget.maxValue;
    if (ratio < 0.3) return AppTheme.neonGreen;
    if (ratio < 0.6) return AppTheme.neonAmber;
    return AppTheme.neonRed;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _valueAnim,
      builder: (context, _) {
        final v = _valueAnim.value;
        final c = _dynamicColor(v);
        final ratio = (v / widget.maxValue).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(color: c.withOpacity(0.1), blurRadius: 10)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: c, size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: AppTheme.labelSmall
                          .copyWith(color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                v.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: c,
                  shadows: [Shadow(color: c.withOpacity(0.6), blurRadius: 8)],
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: AlwaysStoppedAnimation<Color>(c),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
