import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/analysis_result.dart';

class DetectedObjectsOverlay extends StatelessWidget {
  final List<DetectedObject> objects;

  const DetectedObjectsOverlay({super.key, required this.objects});

  Color _classColor(String cls) {
    switch (cls) {
      case 'car': return AppTheme.neonCyan;
      case 'motorcycle': return AppTheme.neonGreen;
      case 'truck': return AppTheme.neonAmber;
      case 'bus': return Colors.purple;
      case 'person': return Colors.yellow;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      // Bounding boxes are in 640x480 coordinate space
      const srcW = 640.0;
      const srcH = 480.0;
      final scaleX = w / srcW;
      final scaleY = h / srcH;

      return Stack(
        children: objects.map((obj) {
          if (obj.bbox.length < 4) return const SizedBox.shrink();
          final x1 = obj.bbox[0] * scaleX;
          final y1 = obj.bbox[1] * scaleY;
          final x2 = obj.bbox[2] * scaleX;
          final y2 = obj.bbox[3] * scaleY;
          final color = _classColor(obj.className);
          return Positioned(
            left: x1,
            top: y1,
            width: x2 - x1,
            height: y2 - y1,
            child: _BoundingBox(
              label: obj.className,
              confidence: obj.confidence,
              distanceM: obj.distanceM,
              color: color,
            ),
          );
        }).toList(),
      );
    });
  }
}

class _BoundingBox extends StatelessWidget {
  final String label;
  final double confidence;
  final double? distanceM;
  final Color color;

  const _BoundingBox({
    required this.label,
    required this.confidence,
    required this.distanceM,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tag = distanceM != null
        ? '${label} ${distanceM!.toStringAsFixed(0)}m'
        : '${label} ${(confidence * 100).toStringAsFixed(0)}%';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          color: color.withOpacity(0.75),
          child: Text(
            tag,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
