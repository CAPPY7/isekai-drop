import 'dart:convert';
import 'dart:io';

import 'identity.dart';

/// verified: the user compared the code (or scanned the QR code) and the key
///   has not changed since.
/// trusted: paired earlier, but this app has no record of a code check
///   (devices migrated from schema 1). Works, shown as "Trusted".
/// identityChanged: answered with a different key. Blocked until re-paired.
/// revoked: the user removed trust. Blocked; kept so it is shown as revoked
///   until the user forgets it.
enum TrustStatus { verified, trusted, identityChanged, revoked }

/// A paired device. Trust is tied to its certificate fingerprint, never to
/// its name or IP address.
class TrustedDevice {
  TrustedDevice({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.fingerprint,
    required this.certPem,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.lastHost,
    this.lastPort,
  });

  final String id;
  final String deviceId;
  final String name;
  final String platform;
  final String fingerprint;
  final String certPem;
  final TrustStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastHost;
  final int? lastPort;

  bool get isTrusted =>
      status == TrustStatus.verified || status == TrustStatus.trusted;
  bool get isVerified => status == TrustStatus.verified;
  bool get isBlocked => !isTrusted;

  TrustedDevice copyWith({
    String? name,
    TrustStatus? status,
    String? lastHost,
    int? lastPort,
  }) => TrustedDevice(
    id: id,
    deviceId: deviceId,
    name: name ?? this.name,
    platform: platform,
    fingerprint: fingerprint,
    certPem: certPem,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
    lastHost: lastHost ?? this.lastHost,
    lastPort: lastPort ?? this.lastPort,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'device_id': deviceId,
    'name': name,
    'platform': platform,
    'fingerprint': fingerprint,
    'cert_pem': certPem,
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'last_host': lastHost,
    'last_port': lastPort,
  };

  factory TrustedDevice.fromJson(Map<String, dynamic> j) => TrustedDevice(
    id: j['id'] as String,
    deviceId: j['device_id'] as String,
    name: j['name'] as String,
    platform: j['platform'] as String,
    fingerprint: j['fingerprint'] as String,
    certPem: j['cert_pem'] as String,
    status: TrustStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
    lastHost: j['last_host'] as String?,
    lastPort: j['last_port'] as int?,
  );
}

/// Trusted-device database: a versioned JSON file, written atomically
/// (write temp file, then rename). Survives app updates.
class TrustStore {
  TrustStore(this.file);

  static const int schemaVersion = 2;

  final File file;
  final List<TrustedDevice> _devices = [];

  List<TrustedDevice> get devices => List.unmodifiable(_devices);

  /// Audit #5: set when load() had to skip damaged data. A copy of the
  /// original file is kept next to it (see [backupFile]) before any save.
  String? loadWarning;
  File? backupFile;

  Future<void> load() async {
    _devices.clear();
    loadWarning = null;
    backupFile = null;
    if (!await file.exists()) return;
    final text = await file.readAsString();
    Map<String, dynamic> raw;
    try {
      raw = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      await _backup();
      loadWarning =
          'The trusted-devices file was damaged and could not be '
          'read. A backup was kept; devices need to be paired again.';
      return;
    }
    final entries = raw['devices'] is List ? raw['devices'] as List : const [];
    var skipped = 0;
    for (final e in entries) {
      try {
        final one = migrate({
          ...raw,
          'devices': [e as Map<String, dynamic>],
        });
        _devices.add(
          TrustedDevice.fromJson(
            (one['devices'] as List).single as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        skipped++;
      }
    }
    if (skipped > 0) {
      await _backup();
      loadWarning =
          '$skipped damaged trusted-device '
          '${skipped == 1 ? 'entry was' : 'entries were'} skipped. '
          'A backup was kept; pair that device again.';
      await _save();
      return;
    }
    if ((raw['schema_version'] as int? ?? 0) != schemaVersion) await _save();
  }

  Future<void> _backup() async {
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    backupFile = await file.copy('${file.path}.bak-$ts');
  }

  /// Upgrades older files step by step. Version 0 = early draft without
  /// status / timestamps.
  static Map<String, dynamic> migrate(Map<String, dynamic> data) {
    var v = data['schema_version'] as int? ?? 0;
    final out = Map<String, dynamic>.from(data);
    if (v < 1) {
      final now = DateTime.now().toUtc().toIso8601String();
      out['devices'] = [
        for (final d in (out['devices'] as List? ?? const []))
          {
            ...(d as Map<String, dynamic>),
            'id': d['id'] ?? randomHex(16),
            'status': d['status'] ?? 'trusted',
            'created_at': d['created_at'] ?? now,
            'updated_at': d['updated_at'] ?? now,
          },
      ];
      v = 1;
    }
    if (v < 2) {
      // Schema 2 adds "verified" and "revoked". Schema-1 devices have no
      // record of a code check, so they stay "trusted" (not "verified").
      out['devices'] = [
        for (final d in (out['devices'] as List? ?? const []))
          {
            ...(d as Map<String, dynamic>),
            'status': switch (d['status']) {
              'identityChanged' => 'identityChanged',
              _ => 'trusted',
            },
          },
      ];
      v = 2;
    }
    out['schema_version'] = v;
    return out;
  }

  Future<void> _writeChain = Future.value();

  /// Writes are serialised: two saves at the same time used to race on the
  /// same .tmp file (audit #17).
  Future<void> _save() {
    final snapshot = jsonEncode({
      'schema_version': schemaVersion,
      'devices': [for (final d in _devices) d.toJson()],
    });
    final next = _writeChain.then((_) async {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(snapshot, flush: true);
      await tmp.rename(file.path);
    });
    _writeChain = next.catchError((_) {});
    return next;
  }

  TrustedDevice? byFingerprint(String fp) {
    for (final d in _devices) {
      if (d.fingerprint == fp) return d;
    }
    return null;
  }

  TrustedDevice? byDeviceId(String deviceId) {
    for (final d in _devices) {
      if (d.deviceId == deviceId) return d;
    }
    return null;
  }

  TrustedDevice? byId(String id) {
    for (final d in _devices) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<TrustedDevice> addTrusted({
    required String deviceId,
    required String name,
    required String platform,
    required String certPem,
    String? host,
    int? port,
    bool verified = true,
  }) async {
    final now = DateTime.now().toUtc();
    final fp = fingerprintOfCertPem(certPem);
    // One record per device id AND per key: re-pairing replaces the old one.
    _devices.removeWhere((d) => d.deviceId == deviceId || d.fingerprint == fp);
    final d = TrustedDevice(
      id: randomHex(16),
      deviceId: deviceId,
      name: name,
      platform: platform,
      fingerprint: fp,
      certPem: certPem,
      status: verified ? TrustStatus.verified : TrustStatus.trusted,
      createdAt: now,
      updatedAt: now,
      lastHost: host,
      lastPort: port,
    );
    _devices.add(d);
    await _save();
    return d;
  }

  Future<void> _replace(TrustedDevice d) async {
    final i = _devices.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      _devices[i] = d;
      await _save();
    }
  }

  Future<void> rename(String id, String name) async {
    final d = byId(id);
    if (d != null) await _replace(d.copyWith(name: name));
  }

  Future<void> markIdentityChanged(String id) async {
    final d = byId(id);
    if (d != null) {
      await _replace(d.copyWith(status: TrustStatus.identityChanged));
    }
  }

  Future<void> rememberAddress(String id, String host, int port) async {
    final d = byId(id);
    if (d != null && (d.lastHost != host || d.lastPort != port)) {
      await _replace(d.copyWith(lastHost: host, lastPort: port));
    }
  }

  /// Removes trust but keeps the record (shown as Revoked). A revoked
  /// device's certificate is no longer accepted by TLS.
  Future<void> revoke(String id) async {
    final d = byId(id);
    if (d != null) await _replace(d.copyWith(status: TrustStatus.revoked));
  }

  /// The user compared the code again: trusted -> verified. Blocked devices
  /// cannot be verified this way (their key changed or trust was removed);
  /// they must pair again.
  Future<bool> markVerified(String id) async {
    final d = byId(id);
    if (d == null || !d.isTrusted) return false;
    await _replace(d.copyWith(status: TrustStatus.verified));
    return true;
  }

  /// Deletes the record completely.
  Future<void> forget(String id) async {
    _devices.removeWhere((d) => d.id == id);
    await _save();
  }
}
