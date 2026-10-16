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
    finalizer = (temp, name) async => (await _android.invokeMethod<String>(
      'exportToDownloads',
      {'path': temp.path, 'name': name},
    ))!;
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
  AndroidUriSource(this.uri, this.name, this.size);

  final String uri;
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

SendSource sendSourceFromPath(String path) => FileSendSource(File(path));
