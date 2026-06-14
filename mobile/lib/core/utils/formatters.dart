import 'package:flutter/material.dart';
import 'package:bike_ai_analyzer/core/theme/app_theme.dart';

class Formatters {
  Formatters._();

  static String formatSpeed(double speedKmh) =>
      '${speedKmh.toStringAsFixed(0)} km/h';

  static String formatSpeedValue(double speedKmh) =>
      speedKmh.toStringAsFixed(0);

  static String formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  static String formatScore(double score) => score.toStringAsFixed(1);

  static Color scoreToColor(double score) {
    if (score >= 85) return AppColors.safe;
    if (score >= 70) return AppColors.warning;
    return AppColors.danger;
  }

  static String scoreToLabel(double score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Poor';
  }

  static String dangerLevelToString(double level) {
    if (level < 0.25) return 'Low';
    if (level < 0.5) return 'Moderate';
    if (level < 0.75) return 'High';
    return 'Critical';
  }

  static Color dangerLevelToColor(double level) {
    if (level < 0.25) return AppColors.safe;
    if (level < 0.5) return AppColors.warning;
    if (level < 0.75) return AppColors.orange;
    return AppColors.danger;
  }

  static Color speedToColor(double speedKmh) {
    if (speedKmh < 60) return AppColors.safe;
    if (speedKmh < 80) return AppColors.warning;
    return AppColors.danger;
  }

  static String formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static String formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static String safetyRatingToStars(double rating) {
    final full = rating.floor();
    final half = (rating - full) >= 0.5 ? 1 : 0;
    return '${'★' * full}${'☆' * half}${'☆' * (5 - full - half)}';
  }

  static String eventTypeToLabel(String type) {
    return type.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }
}
