import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'identity.dart';
import 'jobs.dart';

/// One benchmark run. Stores ONLY measured numbers and test conditions:
/// never file names, device names, addresses or keys.
class BenchmarkRun {
  BenchmarkRun({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.app,
    required this.source,
    required this.fileSet,
    required this.fileCount,
    required this.totalBytes,
    required this.durationMs,
    required this.senderPlatform,
    required this.receiverPlatform,
    required this.direction,
    required this.connection,
    required this.wifiBand,
    this.linkMbps,
    this.distanceM,
    this.verified = false,
    this.note = '',
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// "Isekai Drop" or "LocalSend".
  final String app;

  /// "measured by app" (Isekai Drop's own clock) or "entered by hand"
  /// (stopwatch, e.g. for LocalSend).
  final String source;
  final String fileSet; // 100MB / 1GB / 5GB / 1000small / other
  final int fileCount;
  final int totalBytes;
  final int durationMs;
  final String senderPlatform;
  final String receiverPlatform;
  final String direction; // send / receive (from this device)
  final String connection; // home Wi-Fi / hotspot by ... / other
  final String wifiBand; // 2.4 / 5 / 6 / unknown
  final int? linkMbps;
  final double? distanceM;
  final bool verified;

  /// Free text. The UI warns: no names or personal data.
  final String note;

  double get mbPerSecond =>
      durationMs <= 0 ? 0 : totalBytes / (1024 * 1024) / (durationMs / 1000);

  Map<String, Object?> toJson() => {
    'id': id,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'app': app,
    'source': source,
    'file_set': fileSet,
    'file_count': fileCount,
    'total_bytes': totalBytes,
    'duration_ms': durationMs,
    'sender_platform': senderPlatform,
    'receiver_platform': receiverPlatform,
    'direction': direction,
    'connection': connection,
    'wifi_band': wifiBand,
    'link_mbps': linkMbps,
    'distance_m': distanceM,
    'verified': verified,
    'note': note,
  };

  factory BenchmarkRun.fromJson(Map<String, dynamic> j) => BenchmarkRun(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
    app: j['app'] as String,
    source: j['source'] as String,
    fileSet: j['file_set'] as String,
    fileCount: j['file_count'] as int,
    totalBytes: j['total_bytes'] as int,
    durationMs: j['duration_ms'] as int,
    senderPlatform: j['sender_platform'] as String,
    receiverPlatform: j['receiver_platform'] as String,
    direction: j['direction'] as String,
    connection: j['connection'] as String,
    wifiBand: j['wifi_band'] as String,
    linkMbps: j['link_mbps'] as int?,
    distanceM: (j['distance_m'] as num?)?.toDouble(),
    verified: j['verified'] as bool? ?? false,
    note: j['note'] as String? ?? '',
  );

  static const csvHeader = [
    'id',
    'created_at_utc',
    'app',
    'source',
    'file_set',
    'file_count',
    'total_bytes',
    'duration_ms',
    'mb_per_s',
    'sender_platform',
    'receiver_platform',
    'direction',
    'connection',
    'wifi_band',
    'link_mbps',
    'distance_m',
    'verified',
    'note',
  ];

  List<String> toCsvRow() => [
    id,
    createdAt.toUtc().toIso8601String(),
    app,
    source,
    fileSet,
    '$fileCount',
    '$totalBytes',
    '$durationMs',
    mbPerSecond.toStringAsFixed(2),
    senderPlatform,
    receiverPlatform,
    direction,
    connection,
    wifiBand,
    linkMbps?.toString() ?? '',
    distanceM?.toString() ?? '',
    verified ? 'yes' : 'no',
    note,
  ];
}

/// Why a finished job can't be saved as an Isekai Drop benchmark run, or
/// null if it can. Only clean, complete, verified, uninterrupted runs count.
String? benchmarkBlocker(TransferJob j) {
  if (j.state != JobState.completed) return 'Only completed transfers count.';
  if (j.resumedBytes > 0) {
    return 'This transfer continued an earlier attempt, so its time is not comparable.';
  }
  if (j.wasPaused) {
    return 'This transfer was paused, so its time is not comparable.';
  }
  if (j.elapsed.inMilliseconds <= 0) return 'No measured time.';
  return null;
}

String _csvCell(String v) {
  final needs =
      v.contains(RegExp('[",\n\r]')) || v.startsWith(RegExp(r'[=+\-@]'));
  // Leading = + - @ are escaped so spreadsheets don't run it as a formula.
  final t = v.startsWith(RegExp(r'[=+\-@]')) ? "'$v" : v;
  return needs ? '"${t.replaceAll('"', '""')}"' : t;
}

class BenchmarkStore extends ChangeNotifier {
  BenchmarkStore(this.file);

  static const int schemaVersion = 1;
  final File file;
  final List<BenchmarkRun> _runs = [];
  Future<void> _chain = Future.value();

  List<BenchmarkRun> get runs => List.unmodifiable(_runs);

  Future<void> load() async {
    _runs.clear();
    if (await file.exists()) {
      final m = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final r in (m['runs'] as List? ?? const [])) {
        try {
          _runs.add(BenchmarkRun.fromJson(r as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  /// Builds a run from a finished job: numbers come only from the job's
  /// own measurement.
  static BenchmarkRun fromJob(
    TransferJob j, {
    required String thisPlatform,
    required String otherPlatform,
    required String fileSet,
    required String connection,
    required String wifiBand,
    int? linkMbps,
    double? distanceM,
    String note = '',
  }) {
    final now = DateTime.now().toUtc();
    final sending = j.direction == JobDirection.sending;
    return BenchmarkRun(
      id: randomHex(8),
      createdAt: now,
      updatedAt: now,
      app: 'Isekai Drop',
      source: 'measured by app',
      fileSet: fileSet,
      fileCount: j.fileCount,
      totalBytes: j.totalBytes,
      durationMs: j.elapsed.inMilliseconds,
      senderPlatform: sending ? thisPlatform : otherPlatform,
      receiverPlatform: sending ? otherPlatform : thisPlatform,
      direction: sending ? 'send' : 'receive',
      connection: connection,
      wifiBand: wifiBand,
      linkMbps: linkMbps,
      distanceM: distanceM,
      verified: true,
      note: note,
    );
  }

  Future<void> add(BenchmarkRun r) {
    _runs.insert(0, r);
    notifyListeners();
    return _save();
  }

  Future<void> remove(String id) {
    _runs.removeWhere((r) => r.id == id);
    notifyListeners();
    return _save();
  }

  Future<void> clear() {
    _runs.clear();
    notifyListeners();
    return _save();
  }

  String toCsv() {
    final b = StringBuffer()..writeln(BenchmarkRun.csvHeader.join(','));
    for (final r in _runs.reversed) {
      b.writeln(r.toCsvRow().map(_csvCell).join(','));
    }
    return b.toString();
  }

  Future<void> _save() {
    final snap = jsonEncode({
      'schema_version': schemaVersion,
      'runs': [for (final r in _runs) r.toJson()],
    });
    final next = _chain.then((_) async {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(snap, flush: true);
      await tmp.rename(file.path);
    });
    _chain = next.catchError((_) {});
    return next;
  }
}

/// Random id for a run.
String randomHexId() => randomHex(8);
