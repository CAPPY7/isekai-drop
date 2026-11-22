import 'dart:convert';
import 'dart:io';

/// A3 (0.11.2): a device the user blocked from the pairing question. Its
/// key fingerprint is refused before any dialog. The name is only for the
/// Settings list.
class BlockedDevice {
  BlockedDevice({
    required this.fingerprint,
    required this.name,
    required this.platform,
    required this.blockedAt,
  });

  final String fingerprint;
  final String name;
  final String platform;
  final DateTime blockedAt;

  Map<String, Object?> toJson() => {
    'fp': fingerprint,
    'name': name,
    'platform': platform,
    'blocked_at': blockedAt.toUtc().toIso8601String(),
  };

  static BlockedDevice fromJson(Map<String, dynamic> j) => BlockedDevice(
    fingerprint: j['fp'] as String,
    name: j['name'] as String? ?? 'Device',
    platform: j['platform'] as String? ?? 'unknown',
    blockedAt: DateTime.parse(j['blocked_at'] as String),
  );
}

/// Blocked devices: `blocked_devices.json`, schema_version 1, written
/// atomically (temp file, then rename) like the trusted-device list.
/// Without a file (tests) it is kept in memory only.
class BlockedStore {
  BlockedStore([this.file]);

  static const int schemaVersion = 1;

  final File? file;
  final List<BlockedDevice> _devices = [];

  List<BlockedDevice> get devices => List.unmodifiable(_devices);

  bool isBlocked(String fingerprint) =>
      _devices.any((d) => d.fingerprint == fingerprint);

  /// A damaged file starts an empty list (it never stops the app).
  Future<void> load() async {
    _devices.clear();
    final f = file;
    if (f == null || !await f.exists()) return;
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final e in (raw['devices'] as List? ?? const [])) {
        try {
          _devices.add(BlockedDevice.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (_) {
      _devices.clear();
    }
  }

  Future<void> block(
    String fingerprint, {
    required String name,
    required String platform,
  }) async {
    if (isBlocked(fingerprint)) return;
    _devices.add(
      BlockedDevice(
        fingerprint: fingerprint,
        name: name,
        platform: platform,
        blockedAt: DateTime.now().toUtc(),
      ),
    );
    await _save();
  }

  Future<void> unblock(String fingerprint) async {
    _devices.removeWhere((d) => d.fingerprint == fingerprint);
    await _save();
  }

  Future<void> _writeChain = Future.value();

  Future<void> _save() {
    final f = file;
    if (f == null) return Future.value();
    final snapshot = jsonEncode({
      'schema_version': schemaVersion,
      'devices': [for (final d in _devices) d.toJson()],
    });
    final next = _writeChain.then((_) async {
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(snapshot, flush: true);
      await tmp.rename(f.path);
    });
    _writeChain = next.catchError((_) {});
    return next;
  }
}
