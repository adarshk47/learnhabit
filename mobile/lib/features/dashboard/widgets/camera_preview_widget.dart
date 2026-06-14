import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/analysis_result.dart';
import 'detected_objects_overlay.dart';

class CameraPreviewWidget extends StatelessWidget {
  final AnalysisResult? analysisResult;
  const CameraPreviewWidget({super.key, this.analysisResult});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.neonCyan.withOpacity(0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Placeholder / mock camera feed
            _CameraBackground(),
            // Object detection overlay
            if (analysisResult != null)
              DetectedObjectsOverlay(objects: analysisResult!.detectedObjects),
            // HUD overlay
            _HudOverlay(result: analysisResult),
          ],
        ),
      ),
    );
  }
}

class _CameraBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D1A),
      child: Stack(
        children: [
          // Simulated road perspective lines
          CustomPaint(painter: _RoadPainter(), size: Size.infinite),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_outlined,
                    color: AppTheme.textSecondary.withOpacity(0.3), size: 36),
                const SizedBox(height: 8),
                Text('Camera Feed',
                    style: AppTheme.labelSmall
                        .copyWith(color: AppTheme.textSecondary.withOpacity(0.4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    final cx = size.width / 2;
    // Perspective lines
    for (var x in [0.2, 0.35, 0.65, 0.8]) {
      canvas.drawLine(
        Offset(size.width * x, size.height),
        Offset(cx + (x - 0.5) * 40, size.height * 0.4),
        paint,
      );
    }
    // Horizon line
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _HudOverlay extends StatelessWidget {
  final AnalysisResult? result;
  const _HudOverlay({required this.result});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top-left: traffic density
            if (result != null)
              _HudChip(
                label: 'Density: ${(result!.trafficDensity * 100).toStringAsFixed(0)}%',
                color: AppTheme.neonCyan,
              ),
            const Spacer(),
            // Bottom: object count
            if (result != null && result!.detectedObjects.isNotEmpty)
              Row(
                children: [
                  _HudChip(
                    label: '${result!.detectedObjects.length} objects',
                    color: AppTheme.neonAmber,
                  ),
                  const SizedBox(width: 8),
                  if (result!.oncomingVehicle)
                    _HudChip(
                        label: 'ONCOMING', color: AppTheme.neonRed),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;
  final Color color;
  const _HudChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
