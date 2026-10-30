import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App settings saved on this device (shared_preferences). Survives updates.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _themeMode = _parseTheme(_prefs.getString(_kTheme));
    _deviceName = _prefs.getString(_kName) ?? _defaultName();
  }

  /// 1 = theme + name. 2 = receive, auto-receive, history names, visibility.
  static const int schemaVersion = 2;
  static const _kAccept = 'accept_files';
  static const _kAuto = 'auto_receive_verified';
  static const _kNames = 'history_file_names';
  static const _kVisible = 'visible_on_network';
  static const _kFastDirect = 'fast_direct';
  static const _kVersion = 'settings_schema_version';
  static const _kTheme = 'theme_mode';
  static const _kName = 'device_name';

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;
  late String _deviceName;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    await migrate(prefs);
    return SettingsController(prefs);
  }

  /// Settings migrations, step by step. Safe to run many times.
  @visibleForTesting
  static Future<void> migrate(SharedPreferences prefs) async {
    var v = prefs.getInt(_kVersion) ?? 0;
    if (v < 1) {
      v = 1;
      await prefs.setInt(_kVersion, v);
    }
    if (v < 2) {
      // New options get their safe defaults. Auto-receive is OFF.
      await prefs.setBool(_kAccept, prefs.getBool(_kAccept) ?? true);
      await prefs.setBool(_kAuto, false);
      await prefs.setBool(_kNames, prefs.getBool(_kNames) ?? true);
      await prefs.setBool(_kVisible, prefs.getBool(_kVisible) ?? true);
      v = 2;
      await prefs.setInt(_kVersion, v);
    }
  }

  /// Receive files from trusted devices at all.
  bool get acceptFiles => _prefs.getBool(_kAccept) ?? true;

  /// Accept without asking, ONLY from verified devices. Off by default.
  bool get autoReceiveVerified => _prefs.getBool(_kAuto) ?? false;

  /// Store file names in History (this device only).
  bool get historyFileNames => _prefs.getBool(_kNames) ?? true;

  /// Announce this device on the local network.
  bool get visibleOnNetwork => _prefs.getBool(_kVisible) ?? true;

  /// 0.10.0: use a phone-to-phone Wi-Fi link (no router) for big
  /// transfers between Android phones when possible. On by default; the
  /// normal network is always the fallback.
  bool get fastDirect => _prefs.getBool(_kFastDirect) ?? true;

  Future<void> _setBool(String k, bool v) async {
    await _prefs.setBool(k, v);
    notifyListeners();
  }

  Future<void> setAcceptFiles(bool v) => _setBool(_kAccept, v);
  Future<void> setAutoReceiveVerified(bool v) => _setBool(_kAuto, v);
  Future<void> setHistoryFileNames(bool v) => _setBool(_kNames, v);
  Future<void> setVisibleOnNetwork(bool v) => _setBool(_kVisible, v);
  Future<void> setFastDirect(bool v) => _setBool(_kFastDirect, v);

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
