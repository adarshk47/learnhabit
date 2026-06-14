import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_ai_analyzer/core/constants/app_constants.dart';

enum CameraType { WIFI, PHONE }

enum SpeedUnit { KMH, MPH }

class AppSettings {
  final String backendUrl;
  final CameraType cameraType;
  final String wifiCameraUrl;
  final bool enableVoiceAlerts;
  final double alertVolume;
  final SpeedUnit speedUnit;
  final bool autoStartOnBoot;
  final double speedLimitKmh;
  final bool keepScreenOn;

  // Derived helpers used by providers/screens
  String get backendWsUrl {
    final base = backendUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$base/ws/stream/mobile';
  }

  String get cameraRtspUrl => wifiCameraUrl;

  const AppSettings({
    this.backendUrl = AppConstants.defaultBackendUrl,
    this.cameraType = CameraType.PHONE,
    this.wifiCameraUrl = 'rtsp://10.5.5.9:554/live',
    this.enableVoiceAlerts = true,
    this.alertVolume = 0.8,
    this.speedUnit = SpeedUnit.KMH,
    this.autoStartOnBoot = false,
    this.speedLimitKmh = 60,
    this.keepScreenOn = true,
  });

  AppSettings copyWith({
    String? backendUrl,
    CameraType? cameraType,
    String? wifiCameraUrl,
    bool? enableVoiceAlerts,
    double? alertVolume,
    SpeedUnit? speedUnit,
    bool? autoStartOnBoot,
    double? speedLimitKmh,
    bool? keepScreenOn,
  }) {
    return AppSettings(
      backendUrl: backendUrl ?? this.backendUrl,
      cameraType: cameraType ?? this.cameraType,
      wifiCameraUrl: wifiCameraUrl ?? this.wifiCameraUrl,
      enableVoiceAlerts: enableVoiceAlerts ?? this.enableVoiceAlerts,
      alertVolume: alertVolume ?? this.alertVolume,
      speedUnit: speedUnit ?? this.speedUnit,
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      speedLimitKmh: speedLimitKmh ?? this.speedLimitKmh,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  static const _keyBackendUrl = 'backendUrl';
  static const _keyCameraType = 'cameraType';
  static const _keyWifiCameraUrl = 'wifiCameraUrl';
  static const _keyEnableVoiceAlerts = 'enableVoiceAlerts';
  static const _keyAlertVolume = 'alertVolume';
  static const _keySpeedUnit = 'speedUnit';
  static const _keyAutoStartOnBoot = 'autoStartOnBoot';

  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      backendUrl:
          prefs.getString(_keyBackendUrl) ?? AppConstants.defaultBackendUrl,
      cameraType: CameraType.values[prefs.getInt(_keyCameraType) ?? 1],
      wifiCameraUrl: prefs.getString(_keyWifiCameraUrl) ?? '',
      enableVoiceAlerts: prefs.getBool(_keyEnableVoiceAlerts) ?? true,
      alertVolume: prefs.getDouble(_keyAlertVolume) ?? 0.8,
      speedUnit: SpeedUnit.values[prefs.getInt(_keySpeedUnit) ?? 0],
      autoStartOnBoot: prefs.getBool(_keyAutoStartOnBoot) ?? false,
    );
  }

  Future<void> updateBackendUrl(String url) async {
    state = state.copyWith(backendUrl: url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBackendUrl, url);
  }

  Future<void> updateCameraType(CameraType type) async {
    state = state.copyWith(cameraType: type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCameraType, type.index);
  }

  Future<void> updateWifiCameraUrl(String url) async {
    state = state.copyWith(wifiCameraUrl: url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWifiCameraUrl, url);
  }

  Future<void> updateEnableVoiceAlerts(bool enabled) async {
    state = state.copyWith(enableVoiceAlerts: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnableVoiceAlerts, enabled);
  }

  Future<void> updateAlertVolume(double volume) async {
    state = state.copyWith(alertVolume: volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyAlertVolume, volume);
  }

  Future<void> updateSpeedUnit(SpeedUnit unit) async {
    state = state.copyWith(speedUnit: unit);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySpeedUnit, unit.index);
  }

  Future<void> updateAutoStartOnBoot(bool value) async {
    state = state.copyWith(autoStartOnBoot: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoStartOnBoot, value);
  }

  // Shorthand setters used by settings_screen.dart
  void setBackendUrl(String url) => updateBackendUrl(url);
  void setCameraUrl(String url) => updateWifiCameraUrl(url);
  void setVoiceAlerts(bool v) => updateEnableVoiceAlerts(v);
  void setAlertVolume(double v) => updateAlertVolume(v);
  void setSpeedLimit(double v) {
    state = state.copyWith(speedLimitKmh: v);
  }
  void setKeepScreenOn(bool v) {
    state = state.copyWith(keepScreenOn: v);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);
