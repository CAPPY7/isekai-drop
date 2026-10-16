import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;

import 'package:path_provider/path_provider.dart';

import 'android_export.dart';
import 'bonjour.dart';
import 'core/benchmark_store.dart';
import 'core/engine.dart';
import 'core/history_store.dart';
import 'core/identity.dart';
import 'core/key_migration.dart';
import 'core/pending_send_store.dart';
import 'core/resume_store.dart';
import 'core/send_source.dart';
import 'core/trust_store.dart';

const _android = MethodChannel('isekai_drop/android');
final _exporter = AndroidExporter(_android);
const _apple = MethodChannel('isekai_drop/apple');
BonjourBridge? _bonjour;
const _identityKey = 'isekai_identity_v1';

/// Loads (or creates once) this install's identity. The private key is kept
/// in the platform's secure storage: Android Keystore-backed encryption,
/// Apple Keychain, Windows DPAPI-protected storage, Linux Secret Service.
/// Returns a note if secure storage was not available.
const _fallbackNote =
    'Secure key storage is not available here. Your device key is kept in the app\'s private folder instead.';

/// How long to wait for the system key store. On Linux without a set-up
/// keyring, GNOME Keyring shows a "create keyring" dialog and the call blocks
/// until the user answers (seen on the build box under Xvfb).
const _secureStorageTimeout = Duration(seconds: 30);

Future<(Identity, String?)> _loadIdentity(Directory support) async {
  final fallback = File(p.join(support.path, 'identity_fallback.json'));
  // Once the fallback file is used it stays in use, so this device's
  // identity can never silently change between the file and the keyring.
  if (await fallback.exists()) {
    // Audit #3: move it into secure storage as soon as that works.
    if (!Platform.isLinux || await _linuxKeyringReady()) {
      final r = await migrateFallbackIdentity(
        fallback,
        _SecureSlot(),
        timeout: _secureStorageTimeout,
      );
      if (r == MigrationResult.migrated) {
        final saved = await const FlutterSecureStorage().read(
          key: _identityKey,
        );
        return (
          Identity.fromJson(jsonDecode(saved!) as Map<String, dynamic>),
          null,
        );
      }
    }
    return (
      Identity.fromJson(
        jsonDecode(await fallback.readAsString()) as Map<String, dynamic>,
      ),
      _fallbackNote,
    );
  }
  if (Platform.isLinux && !await _linuxKeyringReady()) {
    return _useFallback(fallback, _linuxNoKeyringNote);
  }
  const storage = FlutterSecureStorage();
  try {
    final saved = await storage
        .read(key: _identityKey)
        .timeout(_secureStorageTimeout);
    if (saved != null) {
      return (
        Identity.fromJson(jsonDecode(saved) as Map<String, dynamic>),
        null,
      );
    }
    final id = await _generate();
    await storage
        .write(key: _identityKey, value: jsonEncode(id.toJson()))
        .timeout(_secureStorageTimeout);
    // Read back: only trust the key store if it really kept the key.
    final check = await storage
        .read(key: _identityKey)
        .timeout(_secureStorageTimeout);
    if (check == null) throw const FileSystemException('not stored');
    return (id, null);
  } catch (_) {
    return _useFallback(fallback, _fallbackNote);
  }
}

class _SecureSlot implements SecretSlot {
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read() => _s.read(key: _identityKey);
  @override
  Future<void> write(String value) => _s.write(key: _identityKey, value: value);
}

Future<(Identity, String?)> _useFallback(File fallback, String note) async {
  final id = await _generate();
  await fallback.parent.create(recursive: true);
  await fallback.writeAsString(jsonEncode(id.toJson()), flush: true);
  if (!Platform.isWindows) {
    try {
      await Process.run('chmod', ['600', fallback.path]);
    } catch (_) {}
  }
  return (id, note);
}

const _linuxNoKeyringNote =
    'No unlocked keyring was found (GNOME Keyring / KWallet). Your device key is kept in the app\'s private folder instead.';

/// Linux: Flutter runs Dart on the GTK thread, and libsecret blocks that
/// thread while it shows a "create/unlock keyring" dialog - the whole app
/// would freeze. So first ask the Secret Service (in a separate process,
/// which cannot freeze us) whether a default keyring exists and is unlocked.
Future<bool> _linuxKeyringReady() async {
  try {
    final r = await Process.run('gdbus', [
      'call',
      '--session',
      '--dest',
      'org.freedesktop.secrets',
      '--object-path',
      '/org/freedesktop/secrets/aliases/default',
      '--method',
      'org.freedesktop.DBus.Properties.Get',
      'org.freedesktop.Secret.Collection',
      'Locked',
    ]).timeout(const Duration(seconds: 5));
    return r.exitCode == 0 && '${r.stdout}'.contains('false');
  } catch (_) {
    return false;
  }
}

Future<Identity> _generate() async {
  final json = await Isolate.run(
    () => jsonEncode(Identity.generate().toJson()),
  );
  return Identity.fromJson(jsonDecode(json) as Map<String, dynamic>);
}

Future<IsekaiEngine> createPlatformEngine(
  String Function() deviceName, {
  bool Function()? acceptingFiles,
  bool Function(TrustedDevice device)? autoAccept,
  bool Function()? saveFileNames,
  bool Function()? visible,
}) async {
  final support = await getApplicationSupportDirectory();
  final (identity, note) = await _loadIdentity(support);
  final trust = TrustStore(File(p.join(support.path, 'trusted_devices.json')));
  try {
    await trust.load();
  } catch (_) {
    // A damaged database must not stop the app; start empty.
  }
  final benchmarks = BenchmarkStore(
    File(p.join(support.path, 'benchmarks.json')),
  );
  try {
    await benchmarks.load();
  } catch (_) {}
  final pendingSends = PendingSendStore(
    File(p.join(support.path, 'pending_sends.json')),
  );
  await pendingSends.load();
  final history = HistoryStore(File(p.join(support.path, 'history.json')));
  try {
    await history.load();
  } catch (_) {
    // Damaged history must not stop the app.
  }

  Directory tempDir;
  ReceiveFinalizer finalizer;
  String where;
  if (Platform.isAndroid) {
    String? noBackup;
    try {
      noBackup = await _android.invokeMethod<String>('noBackupDir');
    } catch (_) {}
    tempDir = androidIncomingDir(noBackup: noBackup, support: support);
    finalizer = (temp, rel, batch) async {
      final parts = rel.split('/');
      var sub = '';
      if (parts.length > 1) {
        final top = parts.first;
        var topName = batch.topFolders[top];
        if (topName == null) {
          topName = top;
          for (var i = 1; i < 10000; i++) {
            if (!await _exporter.folderExists(topName!)) break;
            topName = '$top ($i)';
          }
          batch.topFolders[top] = topName!;
        }
        sub = [topName, ...parts.sublist(1, parts.length - 1)].join('/');
      }
      return _exporter.export(temp.path, parts.last, sub);
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
    final base = await _desktopReceiveBase(support);
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
    // iPhone/iPad: UDP multicast/broadcast needs Apple's multicast
    // entitlement (not available to us), so only Bonjour is used there.
    enableDiscovery: !Platform.isIOS,
    history: history,
    benchmarks: benchmarks,
    // Partial data of interrupted receives, next to where files land
    // (hidden folder), so finishing a file is a cheap rename.
    resume: ResumeStore(Directory(p.join(tempDir.path, '.isekai-resume'))),
    pendingSends: pendingSends,
    sourceCodec: const _PlatformSourceCodec(),
    acceptingFiles: acceptingFiles,
    autoAccept: autoAccept,
    saveFileNames: saveFileNames,
    visible: visible,
    discoveryOffNote: Platform.isIOS
        ? 'Bonjour only (iPhone rules). Windows and Linux PCs do not appear here: scan their QR code or type their address.'
        : null,
  );
  await engine.start();
  _bonjour = BonjourBridge(engine);
  if (visible?.call() ?? true) await _bonjour!.start();
  return engine;
}

/// Android: streams a picked file through a file descriptor (no copy).
/// Audit #9: also stores Android content URIs (persistable read access is
/// not guaranteed after a restart; if opening fails, the retry reports it).
class _PlatformSourceCodec extends SendSourceCodec {
  const _PlatformSourceCodec();

  @override
  Map<String, dynamic>? encode(SendSource s) => s is AndroidUriSource
      ? {
          'k': 'uri',
          'uri': s.uri,
          'name': s.name,
          'size': s.size,
          'rel': s.relativePath,
        }
      : super.encode(s);

  @override
  SendSource? decode(Map<String, dynamic> m) => m['k'] == 'uri'
      ? AndroidUriSource(
          m['uri'] as String,
          m['name'] as String,
          (m['size'] as num).toInt(),
          relativePath: m['rel'] as String?,
        )
      : super.decode(m);
}

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
  try {
    if (Platform.isAndroid) {
      await _android.invokeMethod('keepScreenOn', {'on': on});
    } else if (Platform.isIOS) {
      // Also asks iOS for a short background grace period.
      await _apple.invokeMethod('keepAwake', {'on': on});
    }
  } catch (_) {}
}

/// iPhone/iPad only: system share sheet (Save to Files, AirDrop, ...).
bool get canShareFiles => Platform.isIOS;

Future<void> shareFiles(List<String> paths) async {
  if (!Platform.isIOS || paths.isEmpty) return;
  try {
    await _apple.invokeMethod('share', {'paths': paths});
  } catch (_) {}
}

/// Folder picking: not offered by the iOS file picker plugin we use.
bool get canPickFolder => !Platform.isIOS;

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

/// Where desktop receives go: Downloads, else Documents, else ~/Downloads,
/// else the app's own folder. Some Linux sessions have no XDG user folders,
/// where path_provider returns null or throws (found by running the Linux
/// build on the build box).
Future<Directory> _desktopReceiveBase(Directory support) async {
  try {
    final d = await getDownloadsDirectory();
    if (d != null) return d;
  } catch (_) {}
  try {
    return await getApplicationDocumentsDirectory();
  } catch (_) {}
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null && home.isNotEmpty) {
    return Directory(p.join(home, 'Downloads'));
  }
  return support;
}

/// Settings "Visible to nearby devices" changed. UDP announcements check the
/// setting each time; Bonjour is stopped/started here.
Future<void> setPlatformVisible(bool visible) async {
  final b = _bonjour;
  if (b == null) return;
  try {
    await b.setVisible(visible);
  } catch (_) {}
}

/// Audit #15: where Android keeps incoming partial files (and resume
/// state). Never the cache folder, which Android may clear at any time.
/// Preferred: the app's no-backup folder; otherwise app support files.
Directory androidIncomingDir({String? noBackup, required Directory support}) =>
    Directory(p.join(noBackup ?? support.path, 'incoming'));

/// Saves benchmark CSV text where the user can get it. Returns a plain
/// description of where it went, or null if the user cancelled.
Future<String?> exportBenchmarkCsv(String csv) async {
  final stamp = DateTime.now()
      .toIso8601String()
      .replaceAll(RegExp(r'[:.]'), '-')
      .substring(0, 19);
  final name = 'isekai-benchmarks-$stamp.csv';
  if (Platform.isAndroid) {
    final tmp = File(p.join((await getTemporaryDirectory()).path, name));
    await tmp.writeAsString(csv, flush: true);
    return _exporter.export(tmp.path, name, '');
  }
  if (Platform.isIOS) {
    final dir = Directory(
      p.join((await getApplicationDocumentsDirectory()).path, 'Benchmarks'),
    );
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, name));
    await f.writeAsString(csv, flush: true);
    await shareFiles([f.path]);
    return 'Files app > On My iPhone > Isekai Drop > Benchmarks';
  }
  final loc = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'CSV', extensions: ['csv']),
    ],
  );
  if (loc == null) return null;
  await File(loc.path).writeAsString(csv, flush: true);
  return loc.path;
}
