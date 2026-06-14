import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/ride_model.dart';
import '../../providers/ride_provider.dart';

class RideHistoryScreen extends ConsumerWidget {
  const RideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ridesAsync = ref.watch(ridesHistoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: Text('Ride History', style: AppTheme.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClearAll(context, ref),
            color: AppTheme.textSecondary,
          ),
        ],
      ),
      body: ridesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: TextStyle(color: AppTheme.neonRed)),
        ),
        data: (rides) {
          if (rides.isEmpty) {
            return _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _RideCard(
              ride: rides[i],
              onTap: () => context.push('/history/${rides[i].id}'),
              onDelete: () => ref.read(ridesHistoryProvider.notifier).deleteRide(rides[i].id),
            ),
          );
        },
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Clear All?', style: AppTheme.headlineMedium),
        content: Text('This will delete all saved rides.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () {
              ref.read(ridesHistoryProvider.notifier).clearAll();
              Navigator.pop(context);
            },
            child: Text('Delete All',
                style: TextStyle(color: AppTheme.neonRed)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off,
              size: 80, color: AppTheme.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No rides yet',
              style: AppTheme.headlineMedium
                  .copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Start your first ride from the dashboard',
              style: AppTheme.labelSmall
                  .copyWith(color: AppTheme.textSecondary.withOpacity(0.6))),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideModel ride;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RideCard({
    required this.ride,
    required this.onTap,
    required this.onDelete,
  });

  Color _ratingColor(String? r) {
    switch (r) {
      case 'A': return AppTheme.neonGreen;
      case 'B': return AppTheme.neonCyan;
      case 'C': return AppTheme.neonAmber;
      case 'D': return Colors.orange;
      default:  return AppTheme.neonRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, y • h:mm a').format(ride.startTime);
    final dur = ride.endTime != null
        ? ride.endTime!.difference(ride.startTime)
        : Duration.zero;
    final durStr =
        '${dur.inMinutes}m ${dur.inSeconds.remainder(60)}s';
    final rating = ride.safetyRating ?? 'A';
    final rColor = _ratingColor(rating);

    return Dismissible(
      key: Key(ride.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.neonRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: AppTheme.neonRed),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rColor.withOpacity(0.12),
                  border: Border.all(color: rColor.withOpacity(0.4)),
                ),
                child: Center(
                  child: Text(rating,
                      style: TextStyle(
                          color: rColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr,
                        style: AppTheme.labelSmall
                            .copyWith(color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Stat(
                            icon: Icons.straighten,
                            value: '${ride.distanceKm.toStringAsFixed(1)} km'),
                        const SizedBox(width: 12),
                        _Stat(
                            icon: Icons.timer_outlined, value: durStr),
                        const SizedBox(width: 12),
                        _Stat(
                            icon: Icons.speed,
                            value:
                                '${ride.maxSpeedKmh.toStringAsFixed(0)} km/h'),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(ride.skillScore ?? 0).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.neonCyan,
                    ),
                  ),
                  Text('score',
                      style: AppTheme.labelSmall
                          .copyWith(color: AppTheme.textSecondary)),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
