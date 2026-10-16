import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings saved on this device (shared_preferences). Survives updates.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _themeMode = _parseTheme(_prefs.getString(_kTheme));
    _deviceName = _prefs.getString(_kName) ?? _defaultName();
  }

  static const int schemaVersion = 1;
  static const _kVersion = 'settings_schema_version';
  static const _kTheme = 'theme_mode';
  static const _kName = 'device_name';

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;
  late String _deviceName;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrate(prefs);
    return SettingsController(prefs);
  }

  /// Settings migrations. Version 1 is the first layout.
  static Future<void> _migrate(SharedPreferences prefs) async {
    final v = prefs.getInt(_kVersion) ?? 0;
    if (v < 1) await prefs.setInt(_kVersion, 1);
  }

  ThemeMode get themeMode => _themeMode;
  String get deviceName => _deviceName;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setDeviceName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _deviceName = clean.length > 40 ? clean.substring(0, 40) : clean;
    notifyListeners();
    await _prefs.setString(_kName, _deviceName);
  }

  static String _defaultName() {
    final n = switch (Platform.operatingSystem) {
      'android' => 'Android phone',
      'ios' => 'iPhone',
      'windows' => 'Windows PC',
      'macos' => 'Mac',
      'linux' => 'Linux PC',
      _ => 'My device',
    };
    return n;
  }

  static ThemeMode _parseTheme(String? s) => switch (s) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}
