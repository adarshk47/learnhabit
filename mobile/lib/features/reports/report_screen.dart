import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';
import '../../services/report_service.dart';

class ReportScreen extends ConsumerWidget {
  final String? rideId;
  const ReportScreen({super.key, this.rideId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesHistoryProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: Text('Ride Report', style: AppTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            color: AppTheme.neonCyan,
            onPressed: () async {
              final rides = ridesAsync.valueOrNull ?? [];
              if (rides.isEmpty) return;
              final ride =
                  rideId != null ? rides.firstWhere((r) => r.id == rideId) : rides.first;
              final path = await ReportService.instance.exportPdf(ride);
              if (path != null) await Share.shareXFiles([XFile(path)]);
            },
          ),
        ],
      ),
      body: ridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rides) {
          if (rides.isEmpty) {
            return Center(
                child: Text('No rides to report',
                    style: TextStyle(color: AppTheme.textSecondary)));
          }
          final ride = rideId != null
              ? rides.firstWhere((r) => r.id == rideId,
                  orElse: () => rides.first)
              : rides.first;
          return _ReportBody(ride: ride, allRides: rides);
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final RideModel ride;
  final List<RideModel> allRides;
  const _ReportBody({required this.ride, required this.allRides});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ScoreRadar(ride: ride),
        const SizedBox(height: 16),
        _EventBreakdown(ride: ride),
        const SizedBox(height: 16),
        _ComparisonChart(current: ride, allRides: allRides),
        const SizedBox(height: 16),
        _ExportButton(ride: ride),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ScoreRadar extends StatelessWidget {
  final RideModel ride;
  const _ScoreRadar({required this.ride});

  @override
  Widget build(BuildContext context) {
    final scores = [
      ride.skillScore ?? 0,
      100 - (ride.dangerScore ?? 0),
      100 - (ride.aggressionScore ?? 0),
      ride.smoothness ?? 100,
    ];
    final labels = ['Skill', 'Safety', 'Calm', 'Smooth'];

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
          Text('Score Breakdown',
              style: AppTheme.headlineMedium.copyWith(fontSize: 15)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 4,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                radarBorderData: BorderSide(
                    color: Colors.white.withOpacity(0.1), width: 1),
                gridBorderData: BorderSide(
                    color: Colors.white.withOpacity(0.05), width: 1),
                titleTextStyle: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
                getTitle: (i, _) => RadarChartTitle(text: labels[i]),
                dataSets: [
                  RadarDataSet(
                    dataEntries: scores
                        .map((s) => RadarEntry(value: s.toDouble()))
                        .toList(),
                    fillColor: AppTheme.neonCyan.withOpacity(0.15),
                    borderColor: AppTheme.neonCyan,
                    borderWidth: 2,
                    entryRadius: 3,
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

class _EventBreakdown extends StatelessWidget {
  final RideModel ride;
  const _EventBreakdown({required this.ride});

  @override
  Widget build(BuildContext context) {
    final data = [
      ('Hard Braking', ride.hardBrakeCount, AppTheme.neonRed),
      ('Zig-Zag', ride.zigzagCount, AppTheme.neonAmber),
      ('Speeding', ride.speedViolationCount, Colors.orange),
      ('Unsafe Gap', ride.unsafeDistanceCount, AppTheme.neonCyan),
      ('Overtaking', ride.overtakeCount, Colors.purple),
    ];
    final maxCount = data.map((d) => d.$2).fold(1, (a, b) => a > b ? a : b);

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
          Text('Event Breakdown',
              style: AppTheme.headlineMedium.copyWith(fontSize: 15)),
          const SizedBox(height: 14),
          ...data.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(item.$1,
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12)),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: item.$2 / maxCount,
                            child: Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: item.$3.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${item.$2}',
                        style: TextStyle(
                            color: item.$3,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ComparisonChart extends StatelessWidget {
  final RideModel current;
  final List<RideModel> allRides;
  const _ComparisonChart(
      {required this.current, required this.allRides});

  @override
  Widget build(BuildContext context) {
    final recent = allRides.take(5).toList().reversed.toList();
    final spots = recent.asMap().entries.map((e) {
      final score = e.value.skillScore ?? 0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: score,
            width: 24,
            color: e.value.id == current.id
                ? AppTheme.neonCyan
                : AppTheme.neonCyan.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();

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
          Text('vs Previous Rides',
              style: AppTheme.headlineMedium.copyWith(fontSize: 15)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                barGroups: spots,
                gridData: FlGridData(
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 25,
                      getTitlesWidget: (v, _) => Text('${v.toInt()}',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 10)),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                maxY: 100,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  final RideModel ride;
  const _ExportButton({required this.ride});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              final path = await ReportService.instance.exportPdf(widget.ride);
              setState(() => _loading = false);
              if (path != null && context.mounted) {
                await Share.shareXFiles([XFile(path)],
                    subject: 'BikeAI Ride Report');
              }
            },
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.black))
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_loading ? 'Generating…' : 'Export PDF Report'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.neonCyan,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
