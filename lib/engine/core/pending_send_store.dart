import 'dart:convert';
import 'dart:io';

import 'send_source.dart';

/// Audit #9: a send that failed (not one the user cancelled) is kept on
/// disk so it can be retried after the app restarts. Stored locally only:
/// device id, device name, and for each file how to open it again (file
/// path or Android content URI), its name, size and folder path. Removed
/// when the send completes, is cancelled, or the user removes it.
class PendingSend {
  PendingSend({
    required this.id,
    required this.trustedId,
    required this.peerName,
    required this.totalBytes,
    required this.createdAt,
    required this.sources,
  });

  /// Transfer id (same as the receiver's resume id).
  final String id;
  final String trustedId;
  final String peerName;
  final int totalBytes;
  final DateTime createdAt;
  final List<Map<String, dynamic>> sources;

  int get fileCount => sources.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'trusted_id': trustedId,
    'peer_name': peerName,
    'total_bytes': totalBytes,
    'created_at': createdAt.toUtc().toIso8601String(),
    'sources': sources,
  };

  static PendingSend fromJson(Map<String, dynamic> j) => PendingSend(
    id: j['id'] as String,
    trustedId: j['trusted_id'] as String,
    peerName: j['peer_name'] as String,
    totalBytes: (j['total_bytes'] as num).toInt(),
    createdAt: DateTime.parse(j['created_at'] as String),
    sources: [
      for (final s in j['sources'] as List) Map<String, dynamic>.from(s as Map),
    ],
  );
}

/// Turns a [SendSource] into JSON and back. Returns null if a source cannot
/// be stored (then the send is not kept) or can no longer be opened.
class SendSourceCodec {
  const SendSourceCodec();

  Map<String, dynamic>? encode(SendSource s) => s is FileSendSource
      ? {
          'k': 'file',
          'path': s.file.path,
          'name': s.name,
          'size': s.size,
          'rel': s.relativePath,
        }
      : null;

  SendSource? decode(Map<String, dynamic> m) {
    if (m['k'] != 'file') return null;
    final f = File(m['path'] as String);
    if (!f.existsSync()) return null;
    final size = (m['size'] as num).toInt();
    if (f.lengthSync() != size) return null; // file changed: do not resume
    return FileSendSource(
      f,
      name: m['name'] as String,
      size: size,
      relativePath: m['rel'] as String,
    );
  }
}

class PendingSendStore {
  PendingSendStore(this.file);

  static const int schemaVersion = 1;
  final File file;
  final List<PendingSend> _items = [];
  Future<void> _chain = Future.value();

  List<PendingSend> get items => List.unmodifiable(_items);

  /// Completes when all writes so far are on disk.
  Future<void> get idle => _chain;

  Future<void> load() async {
    _items.clear();
    if (!await file.exists()) return;
    try {
      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final e in raw['items'] as List) {
        try {
          _items.add(PendingSend.fromJson(e as Map<String, dynamic>));
        } catch (_) {}
      }
    } catch (_) {
      // Damaged file: start empty (it only holds retry hints).
    }
  }

  Future<void> put(PendingSend p) {
    _items.removeWhere((e) => e.id == p.id);
    _items.insert(0, p);
    return _save();
  }

  Future<void> remove(String id) {
    final before = _items.length;
    _items.removeWhere((e) => e.id == id);
    return before == _items.length ? _chain : _save();
  }

  Future<void> _save() {
    final text = jsonEncode({
      'schema_version': schemaVersion,
      'items': [for (final i in _items) i.toJson()],
    });
    final next = _chain.then((_) async {
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(file.path);
    });
    _chain = next.catchError((_) {});
    return next;
  }
}
