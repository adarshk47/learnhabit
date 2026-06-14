import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class WarningBanner extends StatefulWidget {
  final List<String> warnings;
  const WarningBanner({super.key, required this.warnings});

  @override
  State<WarningBanner> createState() => _WarningBannerState();
}

class _WarningBannerState extends State<WarningBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;
  List<String> _current = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 350), vsync: this);
    _slide = Tween<Offset>(
            begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(WarningBanner old) {
    super.didUpdateWidget(old);
    if (widget.warnings.isNotEmpty && widget.warnings != old.warnings) {
      setState(() => _current = widget.warnings);
      _ctrl.forward(from: 0).then((_) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _ctrl.reverse();
        });
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  (Color, IconData, String) _warningInfo(String type) {
    switch (type) {
      case 'SPEEDING':
        return (AppTheme.neonRed, Icons.speed, 'SLOW DOWN — Speed limit exceeded');
      case 'HARD_BRAKING':
        return (AppTheme.neonRed, Icons.car_crash, 'HARD BRAKING — Increase following distance');
      case 'ZIG_ZAG':
        return (AppTheme.neonAmber, Icons.swap_horiz, 'ZIG-ZAG DETECTED — Ride smoothly');
      case 'UNSAFE_DISTANCE':
        return (AppTheme.neonRed, Icons.social_distance, 'TOO CLOSE — Increase gap');
      case 'UNSAFE_OVERTAKING':
        return (AppTheme.neonRed, Icons.warning_rounded, 'UNSAFE OVERTAKING — Oncoming traffic');
      case 'LANE_DEPARTURE':
        return (AppTheme.neonAmber, Icons.alt_route, 'LANE DEPARTURE DETECTED');
      case 'CORNERING':
        return (AppTheme.neonAmber, Icons.turn_right, 'EXTREME LEAN — Reduce speed');
      default:
        return (AppTheme.neonAmber, Icons.info_outline, type.replaceAll('_', ' '));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_current.isEmpty) return const SizedBox.shrink();
    final (color, icon, message) = _warningInfo(_current.first);
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.6), width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 16)],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (_current.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('+${_current.length - 1}',
                      style: TextStyle(color: color, fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
