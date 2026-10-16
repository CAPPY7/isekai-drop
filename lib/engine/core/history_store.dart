import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'identity.dart';

enum HistoryDirection { sent, received }

enum HistoryOutcome { completed, failed, cancelled }

/// One finished transfer. Never stores file contents. File names are stored
/// on this device only, and only while "Save file names in History" is on.
class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.direction,
    required this.outcome,
    required this.peerName,
    required this.peerDeviceId,
    required this.fileCount,
    required this.totalBytes,
    required this.bytesDone,
    required this.createdAt,
    required this.updatedAt,
    this.fileNames = const [],
    this.destination,
    this.message,
    this.resumedBytes = 0,
  });

  final String id;
  final HistoryDirection direction;
  final HistoryOutcome outcome;
  final String peerName;
  final String? peerDeviceId;
  final int fileCount;
  final int totalBytes;
  final int bytesDone;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> fileNames;
  final String? destination;
  final String? message;
  final int resumedBytes;

  Map<String, Object?> toJson() => {
    'id': id,
    'direction': direction.name,
    'outcome': outcome.name,
    'peer_name': peerName,
    'peer_device_id': peerDeviceId,
    'file_count': fileCount,
    'total_bytes': totalBytes,
    'bytes_done': bytesDone,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'file_names': fileNames,
    'destination': destination,
    'message': message,
    'resumed_bytes': resumedBytes,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
    id: j['id'] as String,
    direction: HistoryDirection.values.byName(j['direction'] as String),
    outcome: HistoryOutcome.values.byName(j['outcome'] as String),
    peerName: j['peer_name'] as String? ?? 'Device',
    peerDeviceId: j['peer_device_id'] as String?,
    fileCount: j['file_count'] as int? ?? 0,
    totalBytes: j['total_bytes'] as int? ?? 0,
    bytesDone: j['bytes_done'] as int? ?? 0,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse(j['updated_at'] as String),
    fileNames: [for (final n in (j['file_names'] as List? ?? const [])) '$n'],
    destination: j['destination'] as String?,
    message: j['message'] as String?,
    resumedBytes: j['resumed_bytes'] as int? ?? 0,
  );
}

/// Transfer history: a versioned JSON file written atomically. Newest first.
/// Keeps at most [maxEntries].
class HistoryStore extends ChangeNotifier {
  HistoryStore(this.file, {this.maxEntries = 500});

  /// 0 = draft layout (plain list, "device"/"files" keys, no timestamps).
  /// 1 = first stored layout (Phase 6).
  static const int schemaVersion = 1;

  final File file;
  final int maxEntries;
  final List<HistoryEntry> _entries = [];
  Future<void> _writeChain = Future.value();

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    _entries.clear();
    if (await file.exists()) {
      final raw = jsonDecode(await file.readAsString());
      final m = migrate(raw);
      for (final e in (m['entries'] as List)) {
        try {
          _entries.add(HistoryEntry.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // One damaged entry must not hide the rest.
        }
      }
      final v = raw is Map ? raw['schema_version'] : 0;
      if (v != schemaVersion) await _save();
    }
    notifyListeners();
  }

  static Map<String, dynamic> migrate(Object? raw) {
    Map<String, dynamic> out;
    int v;
    if (raw is List) {
      out = {'entries': raw};
      v = 0;
    } else {
      out = Map<String, dynamic>.from(raw as Map);
      v = out['schema_version'] as int? ?? 0;
    }
    if (v < 1) {
      final now = DateTime.now().toUtc().toIso8601String();
      out['entries'] = [
        for (final e in (out['entries'] as List? ?? const []))
          if (e is Map)
            {
              'id': e['id'] ?? randomHex(16),
              'direction': e['direction'] ?? 'received',
              'outcome': e['outcome'] ?? 'completed',
              'peer_name': e['peer_name'] ?? e['device'] ?? 'Device',
              'peer_device_id': e['peer_device_id'],
              'file_count': e['file_count'] ?? e['files'] ?? 0,
              'total_bytes': e['total_bytes'] ?? e['bytes'] ?? 0,
              'bytes_done': e['bytes_done'] ?? e['total_bytes'] ?? 0,
              'created_at': e['created_at'] ?? now,
              'updated_at': e['updated_at'] ?? e['created_at'] ?? now,
              'file_names': e['file_names'] ?? const [],
            },
      ];
      v = 1;
    }
    out['schema_version'] = v;
    return out;
  }

  Future<void> add(HistoryEntry e) {
    _entries.removeWhere((x) => x.id == e.id);
    _entries.insert(0, e);
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    notifyListeners();
    return _save();
  }

  Future<void> remove(String id) {
    _entries.removeWhere((x) => x.id == id);
    notifyListeners();
    return _save();
  }

  Future<void> clear() {
    _entries.clear();
    notifyListeners();
    return _save();
  }

  /// Removes stored file names from all entries (when the user turns the
  /// "Save file names" setting off).
  Future<void> forgetFileNames() {
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e.fileNames.isEmpty) continue;
      _entries[i] = HistoryEntry.fromJson({
        ...e.toJson(),
        'file_names': const [],
      });
    }
    notifyListeners();
    return _save();
  }

  Future<void> _save() {
    final snapshot = jsonEncode({
      'schema_version': schemaVersion,
      'entries': [for (final e in _entries) e.toJson()],
    });
    return _writeChain = _writeChain
        .then((_) async {
          await file.parent.create(recursive: true);
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsString(snapshot, flush: true);
          await tmp.rename(file.path);
        })
        .catchError((_) {});
  }
}
