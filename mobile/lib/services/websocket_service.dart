import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:bike_ai_analyzer/models/analysis_result.dart';
import 'package:bike_ai_analyzer/models/sensor_data.dart';
import 'package:bike_ai_analyzer/core/constants/app_constants.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  final _resultController =
      StreamController<AnalysisResult>.broadcast();
  final _statusController =
      StreamController<ConnectionStatus>.broadcast();

  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  bool _disposed = false;
  String? _currentUrl;

  Stream<AnalysisResult> get results => _resultController.stream;
  Stream<ConnectionStatus> get status => _statusController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  void _setStatus(ConnectionStatus s) {
    _currentStatus = s;
    if (!_statusController.isClosed) {
      _statusController.add(s);
    }
  }

  Future<void> connect(String wsUrl) async {
    if (_isConnecting || _disposed) return;
    _currentUrl = wsUrl;
    _isConnecting = true;
    _setStatus(ConnectionStatus.connecting);

    await _channelSub?.cancel();
    _channel?.sink.close();

    try {
      final uri = Uri.parse('$wsUrl${AppConstants.wsAnalysisEndpoint}');
      _channel = WebSocketChannel.connect(uri);

      _channelSub = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _reconnectAttempts = 0;
      _isConnecting = false;
      _setStatus(ConnectionStatus.connected);
    } catch (e) {
      _isConnecting = false;
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final result = AnalysisResult.fromJson(data);
      if (!_resultController.isClosed) {
        _resultController.add(result);
      }
    } catch (_) {
      // Ignore parse errors
    }
  }

  void _onError(Object error) {
    _setStatus(ConnectionStatus.error);
    _scheduleReconnect();
  }

  void _onDone() {
    if (_currentStatus == ConnectionStatus.connected) {
      _setStatus(ConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void sendSensorData(SensorData data) {
    if (_currentStatus != ConnectionStatus.connected) return;
    try {
      final payload = jsonEncode({
        'type': 'sensor',
        'data': data.toJson(),
      });
      _channel?.sink.add(payload);
    } catch (_) {}
  }

  void sendVideoFrame(List<int> jpegBytes) {
    if (_currentStatus != ConnectionStatus.connected) return;
    try {
      // Send as base64 encoded JSON message
      final b64 = base64Encode(jpegBytes);
      final payload = jsonEncode({
        'type': 'frame',
        'data': b64,
      });
      _channel?.sink.add(payload);
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    if (_reconnectAttempts >= AppConstants.maxReconnectAttempts) return;

    final delay = Duration(
      milliseconds: (AppConstants.reconnectBaseDelayMs *
              pow(2, _reconnectAttempts))
          .toInt()
          .clamp(1000, 30000),
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      if (_currentUrl != null && !_disposed) {
        connect(_currentUrl!);
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _currentUrl = null;
    _reconnectAttempts = 0;
    _isConnecting = false;
    _setStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _resultController.close();
    _statusController.close();
  }
}
