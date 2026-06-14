import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/event_model.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';

class RideDetailScreen extends ConsumerWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesHistoryProvider);

    return ridesAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          body: Center(child: Text('Error: $e'))),
      data: (rides) {
        final ride = rides.firstWhere((r) => r.id == rideId,
            orElse: () => RideModel.empty());
        return _DetailView(ride: ride);
      },
    );
  }
}

class _DetailView extends StatelessWidget {
  final RideModel ride;
  const _DetailView({required this.ride});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: Text('Ride Details', style: AppTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            color: AppTheme.neonCyan,
            onPressed: () => context.push('/reports/${ride.id}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ScoreBanner(ride: ride),
          const SizedBox(height: 16),
          _StatsGrid(ride: ride),
          const SizedBox(height: 16),
          _SpeedChart(speedPoints: ride.speedPoints),
          const SizedBox(height: 16),
          _EventTimeline(events: ride.events),
          const SizedBox(height: 16),
          _Recommendations(recommendations: ride.recommendations),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ScoreBanner extends StatelessWidget {
  final RideModel ride;
  const _ScoreBanner({required this.ride});

  Color _rColor(String? r) {
    switch (r) {
      case 'A': return AppTheme.neonGreen;
      case 'B': return AppTheme.neonCyan;
      case 'C': return AppTheme.neonAmber;
      default:  return AppTheme.neonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rc = _rColor(ride.safetyRating);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.bgCard, rc.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rc.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BigStat('${(ride.skillScore ?? 0).toStringAsFixed(0)}',
              'Skill Score', AppTheme.neonCyan),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rc.withOpacity(0.15),
              border: Border.all(color: rc, width: 2),
            ),
            child: Center(
              child: Text(ride.safetyRating ?? 'A',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: rc)),
            ),
          ),
          _BigStat('${(ride.dangerScore ?? 0).toStringAsFixed(0)}',
              'Danger Score', AppTheme.neonRed),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _BigStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: AppTheme.labelSmall.copyWith(color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final RideModel ride;
  const _StatsGrid({required this.ride});

  @override
  Widget build(BuildContext context) {
    final dur = ride.endTime != null
        ? ride.endTime!.difference(ride.startTime)
        : Duration.zero;
    final items = [
      ('Distance', '${ride.distanceKm.toStringAsFixed(2)} km', Icons.straighten),
      ('Duration', '${dur.inMinutes}m', Icons.timer),
      ('Max Speed', '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h', Icons.speed),
      ('Avg Speed', '${ride.avgSpeedKmh.toStringAsFixed(0)} km/h', Icons.show_chart),
      ('Aggression', '${(ride.aggressionScore ?? 0).toStringAsFixed(0)}', Icons.local_fire_department),
      ('Context', ride.ridingContext ?? 'Unknown', Icons.location_city),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.2,
      children: items
          .map((item) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.$3,
                        size: 18, color: AppTheme.neonCyan),
                    const SizedBox(height: 4),
                    Text(item.$2,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(item.$1,
                        style: AppTheme.labelSmall
                            .copyWith(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _SpeedChart extends StatelessWidget {
  final List<double> speedPoints;
  const _SpeedChart({required this.speedPoints});

  @override
  Widget build(BuildContext context) {
    if (speedPoints.isEmpty) return const SizedBox.shrink();
    final spots = speedPoints
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Speed Profile',
              style: AppTheme.headlineMedium.copyWith(fontSize: 14)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: 40,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 40,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.neonCyan,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.neonCyan.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTimeline extends StatelessWidget {
  final List<RideEvent> events;
  const _EventTimeline({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Events (${events.length})',
              style: AppTheme.headlineMedium.copyWith(fontSize: 14)),
          const SizedBox(height: 12),
          ...events.take(20).map((e) => _EventRow(event: e)),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final RideEvent event;
  const _EventRow({required this.event});

  Color _sevColor(String s) {
    switch (s) {
      case 'CRITICAL': return AppTheme.neonRed;
      case 'HIGH':     return Colors.orange;
      case 'MEDIUM':   return AppTheme.neonAmber;
      default:         return AppTheme.neonGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _sevColor(event.severity);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.description.isNotEmpty
                  ? event.description
                  : event.type.replaceAll('_', ' '),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(event.severity,
                style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _Recommendations extends StatelessWidget {
  final List<String> recommendations;
  const _Recommendations({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.neonCyan, size: 18),
              const SizedBox(width: 8),
              Text('Recommendations',
                  style: AppTheme.headlineMedium.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...recommendations.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, color: AppTheme.neonCyan, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(r,
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
