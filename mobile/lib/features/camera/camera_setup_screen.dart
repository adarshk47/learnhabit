import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../services/camera_service.dart';

class CameraSetupScreen extends ConsumerStatefulWidget {
  const CameraSetupScreen({super.key});

  @override
  ConsumerState<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends ConsumerState<CameraSetupScreen> {
  final _urlController = TextEditingController();
  _TestStatus _status = _TestStatus.idle;
  String _statusMsg = '';

  final _presetUrls = [
    ('GoPro Hero 8+', 'rtsp://10.5.5.9:554/live'),
    ('DJI Action 3', 'rtsp://192.168.2.1:554/live'),
    ('Insta360', 'rtsp://192.168.42.1:554/live'),
    ('Generic IP Cam', 'rtsp://192.168.1.10:554/stream'),
  ];

  @override
  void initState() {
    super.initState();
    _urlController.text = ref.read(settingsProvider).cameraRtspUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _status = _TestStatus.testing;
      _statusMsg = 'Testing connection…';
    });
    final ok = await CameraService.instance.testConnection(_urlController.text);
    setState(() {
      _status = ok ? _TestStatus.ok : _TestStatus.failed;
      _statusMsg = ok ? 'Connected successfully!' : 'Connection failed. Check URL and network.';
    });
  }

  void _saveUrl() {
    ref.read(settingsProvider.notifier).setCameraUrl(_urlController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Camera URL saved'),
        backgroundColor: AppTheme.neonGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDeep,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: Text('Camera Setup', style: AppTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Type selector
          _SectionHeader('Connection Type'),
          const SizedBox(height: 12),
          Row(
            children: [
              _TypeChip(
                  label: 'WiFi RTSP',
                  icon: Icons.wifi,
                  selected: true,
                  onTap: () {}),
              const SizedBox(width: 10),
              _TypeChip(
                  label: 'Bluetooth',
                  icon: Icons.bluetooth,
                  selected: false,
                  onTap: () => _showComingSoon()),
              const SizedBox(width: 10),
              _TypeChip(
                  label: 'Phone Cam',
                  icon: Icons.camera_alt,
                  selected: false,
                  onTap: () {}),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader('RTSP URL'),
          const SizedBox(height: 10),
          TextField(
            controller: _urlController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'rtsp://192.168.x.x:554/live',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.bgCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.neonCyan),
              ),
              prefixIcon: Icon(Icons.link, color: AppTheme.neonCyan),
              suffixIcon: IconButton(
                icon: Icon(Icons.clear, color: AppTheme.textSecondary),
                onPressed: () => _urlController.clear(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testConnection,
                  icon: _status == _TestStatus.testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_circle_outline),
                  label: const Text('Test Connection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.bgCard,
                    foregroundColor: AppTheme.neonCyan,
                    side: BorderSide(color: AppTheme.neonCyan.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveUrl,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          if (_statusMsg.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status == _TestStatus.ok
                    ? AppTheme.neonGreen.withOpacity(0.1)
                    : AppTheme.neonRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _status == _TestStatus.ok
                        ? AppTheme.neonGreen.withOpacity(0.4)
                        : AppTheme.neonRed.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(
                    _status == _TestStatus.ok ? Icons.check_circle : Icons.error_outline,
                    color: _status == _TestStatus.ok ? AppTheme.neonGreen : AppTheme.neonRed,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(_statusMsg,
                      style: TextStyle(
                          color: _status == _TestStatus.ok
                              ? AppTheme.neonGreen
                              : AppTheme.neonRed)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeader('Quick Presets'),
          const SizedBox(height: 12),
          ..._presetUrls.map((p) => _PresetTile(
                name: p.$1,
                url: p.$2,
                onTap: () => _urlController.text = p.$2,
              )),
          const SizedBox(height: 24),
          _SectionHeader('Tips'),
          const SizedBox(height: 10),
          _TipCard(
            icon: Icons.wifi,
            title: 'Connect to camera WiFi first',
            body:
                'Enable your action camera\'s WiFi hotspot, then connect your phone to it before testing.',
          ),
          const SizedBox(height: 8),
          _TipCard(
            icon: Icons.battery_saver,
            title: 'Battery optimization',
            body:
                'Keep screen brightness low during rides. The app will auto-dim after 30 seconds of stable riding.',
          ),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bluetooth support coming in v1.1')),
    );
  }
}

enum _TestStatus { idle, testing, ok, failed }

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: AppTheme.labelSmall.copyWith(
            color: AppTheme.neonCyan,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700));
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.neonCyan.withOpacity(0.15)
              : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? AppTheme.neonCyan
                  : Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.neonCyan : AppTheme.textSecondary,
                size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? AppTheme.neonCyan
                        : AppTheme.textSecondary,
                    fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final String name;
  final String url;
  final VoidCallback onTap;
  const _PresetTile(
      {required this.name, required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Icon(Icons.videocam_outlined,
                color: AppTheme.neonCyan, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(url,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: AppTheme.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _TipCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.neonAmber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
