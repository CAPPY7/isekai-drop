import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'core/engine.dart';
import 'core/identity.dart';
import 'core/send_source.dart';
import 'core/trust_store.dart';

const _android = MethodChannel('isekai_drop/android');
const _identityKey = 'isekai_identity_v1';

/// Loads (or creates once) this install's identity. The private key is kept
/// in the platform's secure storage: Android Keystore-backed encryption,
/// Apple Keychain, Windows DPAPI-protected storage, Linux Secret Service.
/// Returns a note if secure storage was not available.
Future<(Identity, String?)> _loadIdentity(Directory support) async {
  const storage = FlutterSecureStorage();
  try {
    final saved = await storage.read(key: _identityKey);
    if (saved != null) {
      return (
        Identity.fromJson(jsonDecode(saved) as Map<String, dynamic>),
        null,
      );
    }
    final id = await _generate();
    await storage.write(key: _identityKey, value: jsonEncode(id.toJson()));
    return (id, null);
  } catch (_) {
    // e.g. Linux without a keyring service. Fall back to a private app file.
    final f = File(p.join(support.path, 'identity_fallback.json'));
    if (await f.exists()) {
      return (
        Identity.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>,
        ),
        'Secure key storage is not available here. Your device key is kept in the app\'s private folder instead.',
      );
    }
    final id = await _generate();
    await f.writeAsString(jsonEncode(id.toJson()), flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', f.path]);
      } catch (_) {}
    }
    return (
      id,
      'Secure key storage is not available here. Your device key is kept in the app\'s private folder instead.',
    );
  }
}

Future<Identity> _generate() async {
  final json = await Isolate.run(
    () => jsonEncode(Identity.generate().toJson()),
  );
  return Identity.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

Future<IsekaiEngine> createPlatformEngine(String Function() deviceName) async {
  final support = await getApplicationSupportDirectory();
  final (identity, note) = await _loadIdentity(support);
  final trust = TrustStore(File(p.join(support.path, 'trusted_devices.json')));
  try {
    await trust.load();
  } catch (_) {
    // A damaged database must not stop the app; start empty.
  }

  Directory tempDir;
  ReceiveFinalizer finalizer;
  String where;
  if (Platform.isAndroid) {
    tempDir = Directory(
      p.join((await getTemporaryDirectory()).path, 'incoming'),
    );
    finalizer = (temp, rel, batch) async {
      final parts = rel.split('/');
      var sub = '';
      if (parts.length > 1) {
        final top = parts.first;
        var topName = batch.topFolders[top];
        if (topName == null) {
          topName = top;
          for (var i = 1; i < 10000; i++) {
            final taken = await _android.invokeMethod<bool>('folderExists', {
              'name': topName,
            });
            if (taken != true) break;
            topName = '$top ($i)';
          }
          batch.topFolders[top] = topName!;
        }
        sub = [topName, ...parts.sublist(1, parts.length - 1)].join('/');
      }
      return (await _android.invokeMethod<String>('exportToDownloads', {
        'path': temp.path,
        'name': parts.last,
        'sub': sub,
      }))!;
    };
    where = 'Downloads/Isekai Drop';
    try {
      await _android.invokeMethod<bool>('acquireMulticastLock');
    } catch (_) {}
  } else if (Platform.isIOS) {
    tempDir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'Received'),
    );
    finalizer = directoryFinalizer(tempDir);
    where = 'Files app > On My iPhone > Isekai Drop > Received';
  } else {
    final base =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    tempDir = Directory(p.join(base.path, 'Isekai Drop'));
    finalizer = directoryFinalizer(tempDir);
    where = tempDir.path;
  }
  // Remove leftovers of interrupted transfers (never finalised files).
  if (await tempDir.exists()) {
    await for (final f in tempDir.list()) {
      if (f is File &&
          p.basename(f.path).startsWith('.isekai-') &&
          f.path.endsWith('.part')) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  final engine = IsekaiEngine(
    identity: identity,
    trust: trust,
    deviceName: deviceName,
    platformName: Platform.operatingSystem,
    tempDir: tempDir,
    finalizer: finalizer,
    secureStorageNote: note,
    receiveLocationNote: where,
  );
  await engine.start();
  return engine;
}

/// Android: streams a picked file through a file descriptor (no copy).
class AndroidUriSource extends SendSource {
  AndroidUriSource(this.uri, this.name, this.size, {String? relativePath})
    : _rel = relativePath;

  final String uri;
  final String? _rel;
  @override
  String get relativePath => _rel ?? name;
  @override
  final String name;
  @override
  final int size;
  int? _fd;

  @override
  Stream<List<int>> open() async* {
    final fd = await _android.invokeMethod<int>('openFd', {'uri': uri});
    _fd = fd;
    yield* File('/proc/self/fd/$fd').openRead();
  }

  @override
  Future<void> close() async {
    final fd = _fd;
    _fd = null;
    if (fd != null) await _android.invokeMethod('closeFd', {'fd': fd});
  }
}

/// Opens the system file picker. Returns files ready to stream.
Future<List<SendSource>> pickFilesToSend() async {
  if (Platform.isAndroid) {
    final list =
        await _android.invokeListMethod<Map<dynamic, dynamic>>('pickFiles') ??
        [];
    final out = <SendSource>[];
    for (final m in list) {
      final size = (m['size'] as num?)?.toInt() ?? -1;
      if (size < 0) continue; // Unknown size: cannot be verified, skipped.
      out.add(AndroidUriSource(m['uri'] as String, m['name'] as String, size));
    }
    return out;
  }
  final files = await openFiles();
  return [
    for (final f in files)
      if (f.path.isNotEmpty) FileSendSource(File(f.path), name: f.name),
  ];
}

/// A dropped path: a file, or a folder (sent with its structure).
Future<List<SendSource>> sendSourcesFromPath(String path) async {
  if (await FileSystemEntity.isDirectory(path)) {
    return folderSources(Directory(path));
  }
  return [FileSendSource(File(path))];
}

/// Opens the system folder picker. Returns every file inside, keeping the
/// folder structure in [SendSource.relativePath]. Empty if cancelled.
Future<List<SendSource>> pickFolderToSend() async {
  if (Platform.isAndroid) {
    final m = await _android.invokeMapMethod<String, dynamic>('pickFolder');
    if (m == null) return const [];
    final out = <SendSource>[];
    for (final f in (m['files'] as List? ?? const [])) {
      final x = f as Map;
      final size = (x['size'] as num?)?.toInt() ?? -1;
      if (size < 0) continue;
      out.add(
        AndroidUriSource(
          x['uri'] as String,
          x['name'] as String,
          size,
          relativePath: x['rel'] as String,
        ),
      );
    }
    return out;
  }
  final dir = await getDirectoryPath();
  if (dir == null) return const [];
  return folderSources(Directory(dir));
}

/// Android only: keep the screen on while a transfer runs.
Future<void> setKeepScreenOn(bool on) async {
  if (!Platform.isAndroid) return;
  try {
    await _android.invokeMethod('keepScreenOn', {'on': on});
  } catch (_) {}
}

/// Connection facts for Diagnostics. Contains no network names, no
/// addresses and nothing personal.
class ConnectionInfo {
  ConnectionInfo({
    required this.method,
    this.linkMbps,
    this.frequencyMhz,
    this.note,
  });

  final String method;
  final int? linkMbps;
  final int? frequencyMhz;
  final String? note;
}

Future<ConnectionInfo> readConnectionInfo() async {
  final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4)
      .catchError((_) => <NetworkInterface>[]);
  bool has(bool Function(NetworkInterface i, InternetAddress a) test) =>
      ifs.any((i) => i.addresses.any((a) => test(i, a)));

  if (Platform.isAndroid) {
    Map<String, dynamic> m = {};
    try {
      m = await _android.invokeMapMethod<String, dynamic>('networkInfo') ?? {};
    } catch (_) {}
    // Interfaces used when this phone itself hosts a hotspot.
    final hosting = has(
      (i, _) => RegExp(r'^(ap|swlan|softap|wlan1)').hasMatch(i.name),
    );
    final method = m['hotspotByApp'] == true
        ? 'This phone\'s app-made hotspot (no internet)'
        : hosting
        ? 'This phone is sharing a hotspot (likely)'
        : switch (m['transport']) {
            'wifi' => 'Wi-Fi network (a router or another device\'s hotspot)',
            'ethernet' => 'Cable network',
            'cellular' => 'Mobile data only - no local Wi-Fi',
            _ => 'No network',
          };
    return ConnectionInfo(
      method: method,
      linkMbps: (m['linkMbps'] as num?)?.toInt(),
      frequencyMhz: (m['frequencyMhz'] as num?)?.toInt(),
      note: hosting || m['hotspotByApp'] == true
          ? 'Link speed is not reported while this phone hosts the hotspot.'
          : null,
    );
  }
  if (Platform.isWindows) {
    // Windows Mobile Hotspot normally uses 192.168.137.1.
    final hosting = has((_, a) => a.address == '192.168.137.1');
    int? mbps;
    try {
      final r = await Process.run('netsh', ['wlan', 'show', 'interfaces']);
      // Only the receive rate is read; network names are ignored.
      final match = RegExp(r'Receive rate \(Mbps\)\s*:\s*([0-9.]+)')
          .firstMatch('${r.stdout}');
      if (match != null) mbps = double.tryParse(match.group(1)!)?.round();
    } catch (_) {}
    return ConnectionInfo(
      method: hosting
          ? 'This PC is hosting Mobile Hotspot (likely)'
          : ifs.isEmpty
          ? 'No network'
          : 'Wi-Fi or cable network',
      linkMbps: mbps,
      note: mbps == null ? 'Link speed not available.' : null,
    );
  }
  return ConnectionInfo(
    method: ifs.isEmpty ? 'No network' : 'Wi-Fi or cable network',
    note: 'Link speed is not available on this platform yet.',
  );
}

// --------------------------------------------------- app-made hotspot (C)

enum HotspotPermission { granted, needed, locationOff, unsupported }

HotspotPermission _perm(String? s) => switch (s) {
  'granted' => HotspotPermission.granted,
  'location_off' => HotspotPermission.locationOff,
  'needed' => HotspotPermission.needed,
  _ => HotspotPermission.unsupported,
};

Future<HotspotPermission> hotspotPermission() async {
  if (!Platform.isAndroid) return HotspotPermission.unsupported;
  return _perm(await _android.invokeMethod<String>('hotspotPermission'));
}

Future<HotspotPermission> requestHotspotPermission() async {
  if (!Platform.isAndroid) return HotspotPermission.unsupported;
  return _perm(await _android.invokeMethod<String>('requestHotspotPermission'));
}

class HotspotDetails {
  HotspotDetails(this.ssid, this.password);
  final String ssid;
  final String password;

  /// Standard Wi-Fi QR text that phone cameras understand.
  String get wifiQr {
    String esc(String v) =>
        v.replaceAllMapped(RegExp(r'([\\;,:"])'), (m) => '\\${m[1]}');
    return 'WIFI:T:WPA;S:${esc(ssid)};P:${esc(password)};;';
  }
}

class HotspotException implements Exception {
  HotspotException(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<HotspotDetails> startAppHotspot() async {
  try {
    final m = await _android.invokeMapMethod<String, dynamic>('startHotspot');
    final ssid = m?['ssid'] as String?;
    final pass = m?['password'] as String?;
    if (ssid == null || pass == null) {
      throw HotspotException('The hotspot started but its details are hidden.');
    }
    return HotspotDetails(ssid, pass);
  } on PlatformException catch (e) {
    throw HotspotException(switch (e.code) {
      'incompatible_mode' => 'Turn off your normal hotspot (and Wi-Fi Direct) first, then try again.',
      'no_channel' => 'No free Wi-Fi channel right now. Try again in a moment.',
      'tethering_disallowed' =>
        'This phone (or its admin) does not allow hotspots.',
      'permission' => 'Permission is missing. Allow it and try again.',
      _ => 'The hotspot could not start on this phone.',
    });
  }
}

Future<void> stopAppHotspot() async {
  if (!Platform.isAndroid) return;
  try {
    await _android.invokeMethod('stopHotspot');
  } catch (_) {}
}
