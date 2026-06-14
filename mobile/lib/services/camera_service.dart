import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

enum CameraMode { wifi, phone, none }

class CameraService {
  static final CameraService instance = CameraService._();
  CameraService._();

  CameraMode _mode = CameraMode.none;
  CameraController? _phoneController;
  StreamController<Uint8List>? _frameController;
  Timer? _wifiFrameTimer;
  String? _wifiUrl;
  bool _isStreaming = false;

  Stream<Uint8List> get frameStream {
    _frameController ??= StreamController<Uint8List>.broadcast();
    return _frameController!.stream;
  }

  bool get isStreaming => _isStreaming;
  CameraMode get mode => _mode;

  Future<bool> connectToWiFiCamera(String url) async {
    try {
      // Normalize URL - try to reach an MJPEG stream endpoint
      _wifiUrl = url;
      final testUrl = url.endsWith('/') ? '${url}stream' : url;
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _mode = CameraMode.wifi;
        _startWiFiStream(testUrl);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void _startWiFiStream(String url) {
    _isStreaming = true;
    _frameController ??= StreamController<Uint8List>.broadcast();

    // Poll the camera for MJPEG frames
    _wifiFrameTimer?.cancel();
    _wifiFrameTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!_isStreaming) return;
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200 &&
            !(_frameController?.isClosed ?? true)) {
          _frameController!.add(Uint8List.fromList(response.bodyBytes));
        }
      } catch (_) {}
    });
  }

  Future<bool> startPhoneCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _phoneController?.dispose();
      _phoneController = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _phoneController!.initialize();
      _mode = CameraMode.phone;
      _isStreaming = true;
      _frameController ??= StreamController<Uint8List>.broadcast();

      await _phoneController!.startImageStream((CameraImage image) {
        // Convert YUV to something usable - simplified
        // In production you'd use isolate for conversion
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  CameraController? get phoneController => _phoneController;

  Future<Uint8List?> captureFrame() async {
    if (_mode == CameraMode.phone && _phoneController != null) {
      try {
        final xFile = await _phoneController!.takePicture();
        return await xFile.readAsBytes();
      } catch (_) {
        return null;
      }
    }
    if (_mode == CameraMode.wifi && _wifiUrl != null) {
      try {
        final response = await http
            .get(Uri.parse(_wifiUrl!))
            .timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) {
          return Uint8List.fromList(response.bodyBytes);
        }
      } catch (_) {}
    }
    return null;
  }

  void stopStreaming() {
    _isStreaming = false;
    _wifiFrameTimer?.cancel();
    _phoneController?.stopImageStream();
  }

  Future<bool> testConnection(String url) async {
    try {
      final testUrl = url.replaceFirst('rtsp://', 'http://');
      final response = await http.get(Uri.parse(testUrl)).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    stopStreaming();
    _phoneController?.dispose();
    _frameController?.close();
    _frameController = null;
    _mode = CameraMode.none;
  }

  @visibleForTesting
  void reset() {
    dispose();
  }
}
