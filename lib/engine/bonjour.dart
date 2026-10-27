import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'core/diag_log.dart';
import 'core/discovery.dart';
import 'core/engine.dart';

/// Bonjour / mDNS service type for Isekai Drop. Listed in iOS/macOS
/// Info.plist NSBonjourServices.
const kBonjourType = '_isekaidrop._tcp';

const _apple = MethodChannel('isekai_drop/apple');
const _android = MethodChannel('isekai_drop/android');

/// Bonjour discovery, so iPhone/iPad (which may not use our UDP multicast
/// without Apple's multicast entitlement) can find and be found.
///  - iOS / macOS: native NetService advertise + browse.
///  - Android: native NsdManager advertise + browse.
///  - Windows / Linux: browse only (multicast_dns package); they cannot
///    advertise, so an iPhone finds them by QR code or typed address.
/// Everything found is only a hint; identity is checked inside TLS.
class BonjourBridge {
  BonjourBridge(this.engine);

  final IsekaiEngine engine;
  Timer? _timer;
  MDnsClient? _mdns;
  bool _busy = false;
  String? error;

  Map<String, String> _txt() => {
    'id': engine.identity.deviceId,
    'fp': engine.identity.fingerprint,
    'pl': engine.platformName,
    'v': '1',
  };

  /// Tests only: pretend to be this platform ('ios', 'android', ...).
  @visibleForTesting
  static String? debugPlatform;

  static bool get _apple_ => debugPlatform == null
      ? (Platform.isIOS || Platform.isMacOS)
      : (debugPlatform == 'ios' || debugPlatform == 'macos');
  static bool get _android_ =>
      debugPlatform == null ? Platform.isAndroid : debugPlatform == 'android';

  /// Audit #8: "Visible" off must stop only advertising. Browsing keeps
  /// running so this device still finds others.
  Future<void> setVisible(bool visible) async {
    await stop();
    await start(advertise: visible);
  }

  Future<void> start({bool advertise = true}) async {
    final port = engine.listeningPort;
    if (port == null) return;
    try {
      if (_apple_) {
        _apple.setMethodCallHandler(_onNative);
        await _apple.invokeMethod('bonjourStart', {
          'name': engine.myName,
          'port': port,
          'txt': _txt(),
          'advertise': advertise,
        });
      } else if (_android_) {
        _android.setMethodCallHandler(_onNative);
        await _android.invokeMethod('nsdStart', {
          'name': engine.myName,
          'port': port,
          'txt': _txt(),
          'advertise': advertise,
        });
      } else {
        _timer = Timer.periodic(const Duration(seconds: 10), (_) => _query());
        unawaited(_query());
      }
    } catch (_) {
      error = 'Bonjour discovery is not available on this device.';
      engine.recordProblem('bonjour_unavailable', error!);
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _mdns?.stop();
    try {
      if (_apple_) {
        await _apple.invokeMethod('bonjourStop');
      } else if (_android_) {
        await _android.invokeMethod('nsdStop');
      }
    } catch (_) {}
  }

  Future<dynamic> _onNative(MethodCall call) async {
    if (call.method == 'bonjourEvent') {
      final m = Map<String, dynamic>.from(call.arguments as Map);
      onNativeEvent(
        m['what'] as String? ?? '',
        (m['code'] as num?)?.toInt() ?? 0,
      );
      return null;
    }
    if (call.method != 'bonjourFound') return null;
    final m = Map<String, dynamic>.from(call.arguments as Map);
    final txt = Map<String, dynamic>.from((m['txt'] as Map?) ?? const {});
    _add(
      name: m['name'] as String? ?? 'Device',
      host: m['host'] as String? ?? '',
      port: (m['port'] as num?)?.toInt() ?? 0,
      txt: txt.map((k, v) => MapEntry(k, '$v')),
    );
    return null;
  }

  /// Android NSD status (see MainActivity.nsdEvent), counted for
  /// Diagnostics. Codes: 0 internal error, 3 already active, 4 max limit.
  @visibleForTesting
  void onNativeEvent(String what, int code) {
    final c = engine.diagCounters;
    switch (what) {
      case 'registered':
        c.bonjourRegistered = true;
      case 'found':
        c.bonjourFound++;
      case 'resolved':
        c.bonjourResolved++;
      case 'discovery_started':
      case 'resolved_not_ipv4':
        break;
      default:
        c.bonjourErrors++;
        c.bonjourErrorCodes.add('$what:$code');
        if (c.bonjourErrorCodes.length > 5) c.bonjourErrorCodes.removeAt(0);
        if (what == 'register_failed') c.bonjourRegistered = false;
        // Resolve failures are frequent and harmless one by one: count only.
        if (!what.startsWith('resolve')) {
          engine.recordProblem(
            'bonjour_$what',
            'Bonjour (NSD) $what, code $code.',
          );
        }
    }
  }

  @visibleForTesting
  void debugAdd({
    required String name,
    required String host,
    required int port,
    required Map<String, String> txt,
  }) => _add(name: name, host: host, port: port, txt: txt);

  void _add({
    required String name,
    required String host,
    required int port,
    required Map<String, String> txt,
  }) {
    final id = txt['id'];
    final fp = txt['fp'];
    if (id == null || fp == null || host.isEmpty || port <= 0) return;
    if (InternetAddress.tryParse(host) == null) return;
    engine.addAnnouncement(
      Announcement(
        deviceId: id,
        name: cleanDeviceName(name),
        platform: txt['pl'] ?? 'unknown',
        port: port,
        fingerprint: fp,
        host: host,
        seenAt: DateTime.now(),
      ),
    );
  }

  /// Windows / Linux: one browse round with the multicast_dns client.
  Future<void> _query() async {
    if (_busy) return;
    _busy = true;
    final client = _mdns = MDnsClient();
    try {
      await client.start();
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer('$kBonjourType.local'),
        timeout: const Duration(seconds: 3),
      )) {
        final txt = <String, String>{};
        await for (final t in client.lookup<TxtResourceRecord>(
          ResourceRecordQuery.text(ptr.domainName),
          timeout: const Duration(seconds: 2),
        )) {
          for (final line in t.text.split('\n')) {
            final i = line.indexOf('=');
            if (i > 0) txt[line.substring(0, i)] = line.substring(i + 1);
          }
        }
        await for (final srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
          timeout: const Duration(seconds: 2),
        )) {
          await for (final ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
            timeout: const Duration(seconds: 2),
          )) {
            _add(
              name: ptr.domainName.split('.').first,
              host: ip.address.address,
              port: srv.port,
              txt: txt,
            );
          }
        }
      }
    } catch (e) {
      error = 'mDNS browsing failed on this network.';
      engine.diagCounters.bonjourErrors++;
      engine.diagCounters.bonjourErrorCodes.add('mdns_${classifyError(e)}');
      if (engine.diagCounters.bonjourErrorCodes.length > 5) {
        engine.diagCounters.bonjourErrorCodes.removeAt(0);
      }
    } finally {
      client.stop();
      _busy = false;
    }
  }
}
