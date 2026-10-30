import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_name.dart';

/// App settings saved on this device (shared_preferences). Survives updates.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs, {String? systemName}) {
    _themeMode = _parseTheme(_prefs.getString(_kTheme));
    final stored = _prefs.getString(_kName);
    // 0.11.0: a name the user typed is kept. A stored old generic default
    // ("Android phone") was never typed, so the real name replaces it.
    final userSet =
        stored != null &&
        (!kGenericDeviceNames.contains(stored) ||
            _prefs.getBool(_kNameByUser) == true);
    _deviceName = userSet ? stored : (systemName ?? genericDeviceName());
  }

  /// 1 = theme + name. 2 = receive, auto-receive, history names, visibility.
  /// 3 = route mode (0.11.0; every install starts on "auto").
  static const int schemaVersion = 3;
  static const _kAccept = 'accept_files';
  static const _kAuto = 'auto_receive_verified';
  static const _kNames = 'history_file_names';
  static const _kVisible = 'visible_on_network';
  static const _kVersion = 'settings_schema_version';
  static const _kTheme = 'theme_mode';
  static const _kName = 'device_name';
  static const _kNameByUser = 'device_name_by_user';
  static const _kRoute = 'route_mode';

  /// Route choices (0.11.0).
  static const routeAuto = 'auto';
  static const routeRouter = 'router';
  static const routeDirect = 'direct';
  static const routeModes = [routeAuto, routeRouter, routeDirect];

  final SharedPreferences _prefs;
  late ThemeMode _themeMode;
  late String _deviceName;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    await migrate(prefs);
    return SettingsController(prefs, systemName: await systemDeviceName());
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
    if (v < 3) {
      // 0.11.0: "Fast direct on/off" becomes a route choice. Everyone
      // moves to Auto (Fast direct only when it is expected to be faster):
      // the old default (always on) slowed some transfers. Someone who had
      // turned Fast direct OFF keeps it off (Router only).
      final old = prefs.getBool('fast_direct');
      await prefs.setString(_kRoute, old == false ? routeRouter : routeAuto);
      v = 3;
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

  /// 0.11.0: how big transfers pick their route: 'auto' (default; Fast
  /// direct only when expected to be faster), 'router' (never Fast
  /// direct), 'direct' (Fast direct whenever possible, as 0.10.x did).
  String get routeMode {
    final v = _prefs.getString(_kRoute);
    return routeModes.contains(v) ? v! : routeAuto;
  }

  Future<void> setRouteMode(String v) async {
    if (!routeModes.contains(v)) return;
    await _prefs.setString(_kRoute, v);
    notifyListeners();
  }

  /// Fast direct allowed at all (false only for "Router only"). Also what
  /// this device answers when another phone asks for a direct link.
  bool get fastDirect => routeMode != routeRouter;

  Future<void> _setBool(String k, bool v) async {
    await _prefs.setBool(k, v);
    notifyListeners();
  }

  Future<void> setAcceptFiles(bool v) => _setBool(_kAccept, v);
  Future<void> setAutoReceiveVerified(bool v) => _setBool(_kAuto, v);
  Future<void> setHistoryFileNames(bool v) => _setBool(_kNames, v);
  Future<void> setVisibleOnNetwork(bool v) => _setBool(_kVisible, v);

  /// Old on/off API: on = Auto, off = Router only.
  Future<void> setFastDirect(bool v) =>
      setRouteMode(v ? routeAuto : routeRouter);

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
    await _prefs.setBool(_kNameByUser, true);
  }

  static ThemeMode _parseTheme(String? s) => switch (s) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    // 0.11.0: default follows the system (spec E26).
    _ => ThemeMode.system,
  };
}
