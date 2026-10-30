// 0.11.0: a real default device name ("OnePlus 9", the PC's computer
// name) instead of "Android phone". Used only when the user has not set a
// name themselves.
import 'dart:io';

import 'package:flutter/services.dart';

/// The old generic defaults (before 0.11.0). A stored name equal to one of
/// these was never typed by the user, so it may be replaced.
const kGenericDeviceNames = {
  'Android phone',
  'iPhone',
  'Windows PC',
  'Mac',
  'Linux PC',
  'My device',
};

String genericDeviceName([String? os]) =>
    switch (os ?? Platform.operatingSystem) {
      'android' => 'Android phone',
      'ios' => 'iPhone',
      'windows' => 'Windows PC',
      'macos' => 'Mac',
      'linux' => 'Linux PC',
      _ => 'My device',
    };

/// Cleans a system name: trims, drops a ".local" / domain suffix of host
/// names, caps at 40 characters. Null when nothing usable is left.
String? cleanDeviceName(String? raw, {bool hostname = false}) {
  if (raw == null) return null;
  var s = raw.trim();
  if (hostname) {
    final dot = s.indexOf('.');
    if (dot > 0) s = s.substring(0, dot);
  }
  s = s.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  if (s.isEmpty || s.toLowerCase() == 'localhost') return null;
  return s.length > 40 ? s.substring(0, 40) : s;
}

/// "OnePlus" + "LE2113" -> "OnePlus LE2113"; "samsung" + "SM-G991B" ->
/// "Samsung SM-G991B"; "Google" + "Pixel 7" -> "Google Pixel 7"; a model
/// that already starts with the maker is kept as is.
String friendlyModelName(String manufacturer, String model) {
  final m = manufacturer.trim();
  final mo = model.trim();
  if (mo.isEmpty) return m;
  if (m.isEmpty || mo.toLowerCase().startsWith(m.toLowerCase())) return mo;
  final maker = m[0].toUpperCase() + m.substring(1);
  return '$maker $mo';
}

const _android = MethodChannel('isekai_drop/android');
const _apple = MethodChannel('isekai_drop/apple');

/// Best real name of this device, or null (then the generic name is used).
Future<String?> systemDeviceName() async {
  try {
    if (Platform.isAndroid) {
      final m = await _android.invokeMapMethod<String, Object?>('deviceName');
      if (m == null) return null;
      final user = cleanDeviceName(m['deviceName'] as String?);
      if (user != null) return user;
      return cleanDeviceName(
        friendlyModelName(
          (m['manufacturer'] as String?) ?? '',
          (m['model'] as String?) ?? '',
        ),
      );
    }
    if (Platform.isIOS) {
      return cleanDeviceName(await _apple.invokeMethod<String>('deviceName'));
    }
    if (Platform.isWindows) {
      return cleanDeviceName(
        Platform.environment['COMPUTERNAME'] ?? Platform.localHostname,
        hostname: true,
      );
    }
    if (Platform.isMacOS || Platform.isLinux) {
      return cleanDeviceName(Platform.localHostname, hostname: true);
    }
  } catch (_) {
    // No name: the generic one is used.
  }
  return null;
}
