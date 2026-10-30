import 'dart:convert';
import 'dart:io';

/// 0.11.0 "Auto (fastest)" route choice for big sends to an Android phone.
///
/// Remembers the measured average speed of earlier big sends per trusted
/// device and route ('router' or 'direct'), and picks Fast direct only when
/// it is expected to be faster. Speeds only; no names or paths are stored.
class RouteStats {
  RouteStats([this.file]);

  /// Null = in memory only (tests).
  final File? file;

  /// Above this a router route is already good; Fast direct is not tried
  /// until it has been measured to be faster.
  static const double goodRouterBytesPerSec = 20 * 1000 * 1000;

  final Map<String, Map<String, double>> _by = {};

  double? speed(String deviceId, String route) => _by[deviceId]?[route];

  Future<void> load() async {
    final f = file;
    if (f == null || !await f.exists()) return;
    try {
      final j = jsonDecode(await f.readAsString());
      if (j is! Map) return;
      for (final e in j.entries) {
        final m = e.value;
        if (e.key is! String || m is! Map) continue;
        for (final r in m.entries) {
          final v = r.value;
          if ((r.key == 'router' || r.key == 'direct') && v is num && v > 0) {
            (_by[e.key as String] ??= {})[r.key as String] = v.toDouble();
          }
        }
      }
    } catch (_) {
      // Damaged file: start fresh (only speeds are lost).
    }
  }

  /// Records a finished big send. Keeps a smoothed value (newest counts 50%)
  /// so one slow run does not decide forever.
  Future<void> record(String deviceId, String route, double bytesPerSec) async {
    if (bytesPerSec <= 0 || (route != 'router' && route != 'direct')) return;
    final m = _by[deviceId] ??= {};
    final old = m[route];
    m[route] = old == null ? bytesPerSec : (old + bytesPerSec) / 2;
    final f = file;
    if (f == null) return;
    try {
      await f.writeAsString(jsonEncode(_by), flush: true);
    } catch (_) {}
  }

  /// Null = try Fast direct; else a reason code ('auto_*') to use the router.
  String? autoSkip(String deviceId) => autoRouteSkip(
    router: speed(deviceId, 'router'),
    direct: speed(deviceId, 'direct'),
  );
}

/// The Auto decision (see [RouteStats]).
String? autoRouteSkip({double? router, double? direct}) {
  const good = RouteStats.goodRouterBytesPerSec;
  if (router != null && direct != null) {
    return direct > router * 1.1 ? null : 'auto_router_faster';
  }
  if (router != null) return router < good ? null : 'auto_router_good';
  if (direct != null) return direct >= good ? null : 'auto_direct_slow';
  return 'auto_first';
}
