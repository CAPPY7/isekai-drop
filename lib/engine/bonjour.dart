import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

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

  Future<void> start() async {
    final port = engine.listeningPort;
    if (port == null) return;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        _apple.setMethodCallHandler(_onNative);
        await _apple.invokeMethod('bonjourStart', {
          'name': engine.myName,
          'port': port,
          'txt': _txt(),
        });
      } else if (Platform.isAndroid) {
        _android.setMethodCallHandler(_onNative);
        await _android.invokeMethod('nsdStart', {
          'name': engine.myName,
          'port': port,
          'txt': _txt(),
        });
      } else {
        _timer = Timer.periodic(const Duration(seconds: 10), (_) => _query());
        unawaited(_query());
      }
    } catch (_) {
      error = 'Bonjour discovery is not available on this device.';
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _mdns?.stop();
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        await _apple.invokeMethod('bonjourStop');
      } else if (Platform.isAndroid) {
        await _android.invokeMethod('nsdStop');
      }
    } catch (_) {}
  }

  Future<dynamic> _onNative(MethodCall call) async {
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
        name: name.length > 40 ? name.substring(0, 40) : name,
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
    } catch (_) {
      error = 'mDNS browsing failed on this network.';
    } finally {
      client.stop();
      _busy = false;
    }
  }
}
