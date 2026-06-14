import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/camera/camera_setup_screen.dart';
import 'features/ride_history/ride_history_screen.dart';
import 'features/ride_history/ride_detail_screen.dart';
import 'features/reports/report_screen.dart';
import 'features/settings/settings_screen.dart';
import 'providers/ride_provider.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/camera-setup',
      name: 'camera-setup',
      builder: (context, state) => const CameraSetupScreen(),
    ),
    GoRoute(
      path: '/history',
      name: 'history',
      builder: (context, state) => const RideHistoryScreen(),
      routes: [
        GoRoute(
          path: ':id',
          name: 'ride-detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return RideDetailScreen(rideId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/reports',
      name: 'reports',
      builder: (context, state) => const ReportScreen(),
      routes: [
        GoRoute(
          path: ':id',
          name: 'report-detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return ReportScreen(rideId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

class BikeAIApp extends ConsumerWidget {
  const BikeAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the analysis sync bridge
    ref.watch(appInitProvider);

    return MaterialApp.router(
      title: 'BikeAI Analyzer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
