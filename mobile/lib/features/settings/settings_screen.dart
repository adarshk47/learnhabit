import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/database_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: Text('Settings', style: AppTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('Backend'),
          _SettingsTile(
            title: 'Server URL',
            subtitle: settings.backendUrl,
            icon: Icons.dns_outlined,
            onTap: () => _editUrl(context, ref, settings.backendUrl),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Voice Alerts'),
          _SwitchTile(
            title: 'Enable Voice Alerts',
            subtitle: 'TTS alerts for dangerous events',
            icon: Icons.record_voice_over_outlined,
            value: settings.enableVoiceAlerts,
            onChanged: (v) => notifier.setVoiceAlerts(v),
          ),
          const SizedBox(height: 8),
          _SliderTile(
            title: 'Alert Volume',
            icon: Icons.volume_up_outlined,
            value: settings.alertVolume,
            onChanged: (v) => notifier.setAlertVolume(v),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Ride Analysis'),
          _SliderTile(
            title: 'Speed Limit (km/h)',
            icon: Icons.speed,
            value: settings.speedLimitKmh,
            min: 30,
            max: 120,
            divisions: 18,
            onChanged: (v) => notifier.setSpeedLimit(v),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Display'),
          _SwitchTile(
            title: 'Keep Screen On',
            subtitle: 'Prevent screen sleep during rides',
            icon: Icons.brightness_high_outlined,
            value: settings.keepScreenOn,
            onChanged: (v) => notifier.setKeepScreenOn(v),
          ),
          const SizedBox(height: 16),
          _SectionLabel('Data'),
          _SettingsTile(
            title: 'Clear All Ride Data',
            subtitle: 'Permanently delete all saved rides',
            icon: Icons.delete_forever_outlined,
            iconColor: AppTheme.neonRed,
            onTap: () => _confirmClear(context),
          ),
          const SizedBox(height: 24),
          _SectionLabel('About'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BikeAI Analyzer',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Version 1.0.0',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'AI-powered bike riding analysis using YOLOv8 computer vision + sensor fusion.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _editUrl(BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Backend URL', style: AppTheme.headlineMedium),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'http://192.168.1.x:8000',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setBackendUrl(ctrl.text);
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: AppTheme.neonCyan)),
          ),
        ],
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Clear All Data?', style: AppTheme.headlineMedium),
        content: Text('All saved rides will be permanently deleted.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(
            onPressed: () async {
              await DatabaseService.instance.clearAll();
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Delete',
                style: TextStyle(color: AppTheme.neonRed)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: AppTheme.labelSmall.copyWith(
          color: AppTheme.neonCyan,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? AppTheme.neonCyan, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.neonCyan, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.neonCyan,
          ),
        ],
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.icon,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.neonCyan, size: 20),
              const SizedBox(width: 14),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(value.toStringAsFixed(0),
                  style: TextStyle(
                      color: AppTheme.neonCyan,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            activeColor: AppTheme.neonCyan,
            inactiveColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}
