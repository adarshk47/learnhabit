import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/ride_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/tts_service.dart';
import '../../services/websocket_service.dart';
import 'widgets/camera_preview_widget.dart';
import 'widgets/score_card.dart';
import 'widgets/speed_gauge.dart';
import 'widgets/warning_banner.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rideState = ref.watch(rideStateProvider);
    final analysis = ref.watch(analysisResultProvider);  // AnalysisResult?
    final connectionStatus = ref.watch(connectionStatusProvider);
    final settings = ref.watch(settingsProvider);

    // Trigger voice alerts
    ref.listen(analysisResultProvider, (prev, next) {
      if (next != null && next.voiceAlerts.isNotEmpty) {
        if (settings.enableVoiceAlerts) {
          TtsService.instance.speakQueue(next.voiceAlerts);
        }
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(connectionStatus: connectionStatus),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    // Camera preview
                    CameraPreviewWidget(analysisResult: analysis),
                    const SizedBox(height: 16),
                    // Speed gauge (hero widget)
                    SpeedGauge(
                      speed: analysis?.speed ?? rideState.currentSpeed,
                      maxSpeed: 160,
                    ),
                    const SizedBox(height: 16),
                    // Score cards row
                    Row(
                      children: [
                        Expanded(
                          child: ScoreCard(
                            label: 'Ride Score',
                            value: analysis?.skillScore ?? 100.0,
                            maxValue: 100,
                            color: AppTheme.neonGreen,
                            icon: Icons.star_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ScoreCard(
                            label: 'Danger',
                            value: analysis?.dangerScore ?? 0.0,
                            maxValue: 100,
                            color: AppTheme.neonRed,
                            icon: Icons.warning_rounded,
                            invertColor: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SafetyBadge(
                            rating: analysis?.safetyRating ?? 'A',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Secondary metrics
                    Row(
                      children: [
                        Expanded(
                          child: ScoreCard(
                            label: 'Aggression',
                            value: analysis?.aggressionScore ?? 0.0,
                            maxValue: 100,
                            color: AppTheme.neonAmber,
                            icon: Icons.local_fire_department,
                            invertColor: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ScoreCard(
                            label: 'Smoothness',
                            value: analysis?.smoothness ?? 100.0,
                            maxValue: 100,
                            color: AppTheme.neonCyan,
                            icon: Icons.waves_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AccidentProbCard(
                            probability: analysis?.accidentProbability ?? 0.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Context chip
                    if (analysis != null)
                      _ContextChip(context: analysis.ridingContext),
                    const SizedBox(height: 12),
                    // Warning banner
                    WarningBanner(warnings: analysis?.warnings ?? []),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(rideState: rideState),
      floatingActionButton: _RideFab(rideState: rideState),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _TopBar extends StatelessWidget {
  final ConnectionStatus connectionStatus;
  const _TopBar({required this.connectionStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.neonCyan.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connectionStatus == ConnectionStatus.connected
                  ? AppTheme.neonGreen
                  : connectionStatus == ConnectionStatus.connecting
                      ? AppTheme.neonAmber
                      : AppTheme.neonRed,
              boxShadow: [
                BoxShadow(
                  color: (connectionStatus == ConnectionStatus.connected
                          ? AppTheme.neonGreen
                          : AppTheme.neonRed)
                      .withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            connectionStatus.label,
            style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary),
          ),
          const Spacer(),
          Text(
            'BikeAI',
            style: AppTheme.headlineMedium.copyWith(
              color: AppTheme.neonCyan,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          Icon(Icons.gps_fixed, color: AppTheme.neonGreen, size: 18),
          const SizedBox(width: 4),
          Icon(Icons.notifications_none, color: AppTheme.textSecondary, size: 20),
        ],
      ),
    );
  }
}

class _SafetyBadge extends StatelessWidget {
  final String rating;
  const _SafetyBadge({required this.rating});

  Color get _color {
    switch (rating) {
      case 'A': return AppTheme.neonGreen;
      case 'B': return AppTheme.neonCyan;
      case 'C': return AppTheme.neonAmber;
      case 'D': return Colors.orange;
      default:  return AppTheme.neonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: _color.withOpacity(0.15), blurRadius: 12)],
      ),
      child: Column(
        children: [
          Text('Safety', style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(
            rating,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _color,
              shadows: [Shadow(color: _color.withOpacity(0.8), blurRadius: 16)],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccidentProbCard extends StatelessWidget {
  final double probability;
  const _AccidentProbCard({required this.probability});

  @override
  Widget build(BuildContext context) {
    final pct = (probability * 100).toStringAsFixed(1);
    final color = probability < 0.1
        ? AppTheme.neonGreen
        : probability < 0.3
            ? AppTheme.neonAmber
            : AppTheme.neonRed;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text('Risk', style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text('$pct%',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Icon(Icons.shield_outlined, color: color, size: 14),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String context;
  const _ContextChip({required this.context});

  @override
  Widget build(BuildContext context) {
    final labels = {
      'CITY_TRAFFIC': ('City Traffic', Icons.location_city, AppTheme.neonAmber),
      'HIGHWAY': ('Highway', Icons.speed, AppTheme.neonCyan),
      'EMPTY_ROAD': ('Open Road', Icons.route, AppTheme.neonGreen),
      'TRAFFIC_JAM': ('Traffic Jam', Icons.traffic, AppTheme.neonRed),
    };
    final info = labels[this.context] ?? ('Unknown', Icons.help_outline, AppTheme.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: (info.$3 as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (info.$3 as Color).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.$2 as IconData, color: info.$3 as Color, size: 16),
          const SizedBox(width: 6),
          Text(info.$1 as String,
              style: AppTheme.labelSmall.copyWith(color: info.$3 as Color)),
        ],
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final RideState rideState;
  const _BottomNav({required this.rideState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomAppBar(
      color: AppTheme.bgCard,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            color: AppTheme.textSecondary,
            onPressed: () => context.push('/history'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            color: AppTheme.textSecondary,
            onPressed: () => context.push('/reports'),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            color: AppTheme.textSecondary,
            onPressed: () => context.push('/camera-setup'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: AppTheme.textSecondary,
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }
}

class _RideFab extends ConsumerWidget {
  final RideState rideState;
  const _RideFab({required this.rideState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = rideState.isActive;
    return FloatingActionButton.extended(
      onPressed: () {
        if (isActive) {
          ref.read(rideStateProvider.notifier).stopRide();
        } else {
          ref.read(rideStateProvider.notifier).startRide();
        }
      },
      backgroundColor: isActive ? AppTheme.neonRed : AppTheme.neonGreen,
      icon: Icon(isActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: Colors.black),
      label: Text(
        isActive ? 'STOP RIDE' : 'START RIDE',
        style: const TextStyle(
            color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }
}
