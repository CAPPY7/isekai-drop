import 'dart:async';

import 'package:flutter/services.dart';

import 'direct/direct_link.dart';

/// 0.10.0 Fast direct on Android: the Dart side of `DirectLinks.kt`.
///
/// Every native error code becomes a [DirectLinkException] with the same
/// code, so the plain-language texts in [explainDirectError] apply.
class AndroidDirectLinks implements DirectLinkPlatform {
  AndroidDirectLinks._(this._ch, this._canHost, this._canJoin, this.sdk) {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'directEvent' && call.arguments is String) {
        _events.add(call.arguments as String);
      }
      return null;
    });
  }

  static const _channel = MethodChannel('isekai_drop/direct');

  /// Reads what this phone supports. Returns null when the native side is
  /// missing (should not happen) so the app simply runs without Fast direct.
  static Future<AndroidDirectLinks?> create() async {
    try {
      final caps = await _channel.invokeMapMethod<String, Object?>('caps');
      if (caps == null) return null;
      return AndroidDirectLinks._(
        _channel,
        caps['canHost'] == true,
        caps['canJoin'] == true,
        (caps['sdk'] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  final MethodChannel _ch;
  final bool _canHost;
  final bool _canJoin;

  /// Android API level (for Diagnostics and permission wording).
  final int sdk;
  final _events = StreamController<String>.broadcast();

  @override
  bool get canHost => _canHost;

  @override
  bool get canJoin => _canJoin;

  @override
  Stream<String> get events => _events.stream;

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw DirectLinkException(e.code);
    } on MissingPluginException {
      throw const DirectLinkException('unsupported');
    }
  }

  /// 0.10.1 Speed test: speeds of the joined Fast direct link right now
  /// (Android 12+; empty when not joined or not reported).
  /// Speeds/channels (positive ints) plus 0.10.2 "role" and "iface"
  /// (group interface name). No names of networks, no addresses.
  Future<Map<String, Object>> linkNow() async {
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('linkNow') ?? {};
      return {
        for (final e in m.entries)
          if ((e.value is int && (e.value as int) > 0) ||
              ((e.key == 'role' || e.key == 'iface') && e.value is String))
            e.key: e.value!,
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<String> permissionState() async {
    try {
      return await _call<String>('permissionState') ?? 'unsupported';
    } on DirectLinkException {
      return 'unsupported';
    }
  }

  @override
  Future<String> requestPermission() async {
    try {
      return await _call<String>('requestPermission') ?? 'denied';
    } on DirectLinkException catch (e) {
      return e.code == 'busy' ? 'denied' : 'unsupported';
    }
  }

  /// Opens this app's page in Android Settings (when the prompt no longer
  /// appears because it was denied twice).
  Future<void> openAppSettings() async {
    try {
      await _call<bool>('openAppSettings');
    } catch (_) {}
  }

  @override
  Future<DirectLinkInfo> host({bool preferFiveGhz = true}) async {
    final raw = await _call<Object?>('host', {'preferFiveGhz': preferFiveGhz});
    final link = DirectLinkInfo.tryFromJson(raw);
    if (link == null) throw const DirectLinkException('unsupported');
    return link;
  }

  @override
  Future<void> stopHost() async {
    try {
      await _call<bool>('stopHost');
    } catch (_) {}
  }

  @override
  Future<DirectJoin> join(
    DirectLinkInfo link, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final raw = await _call<Object?>('join', {
      'kind': link.kind.wire,
      'ssid': link.ssid,
      'pass': link.passphrase,
      'host': link.hostIp,
      'mhz': link.frequencyMhz ?? 0,
      'timeoutMs': timeout.inMilliseconds,
    });
    final m = raw is Map ? raw : const {};
    int? pos(Object? v) => v is int && v > 0 ? v : null;
    return DirectJoin(
      localIp: m['localIp'] as String?,
      frequencyMhz: pos(m['mhz']) ?? link.frequencyMhz,
      linkMbps: pos(m['mbps']),
      txMbps: pos(m['txMbps']),
      rxMbps: pos(m['rxMbps']),
    );
  }

  @override
  Future<void> leave() async {
    try {
      await _call<bool>('leave');
    } catch (_) {}
  }
}
