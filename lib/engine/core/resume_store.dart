import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'safe_files.dart';

/// Receiver-side state of an interrupted transfer, so it can continue after
/// a network drop or after the app was closed/killed.
///
/// A state belongs to ONE trusted sender key (fingerprint from mutual TLS)
/// and ONE transfer id, so no other device can continue or read it.
/// Contents of a partial file are never trusted: the whole file is hashed
/// again from byte 0 when it is finished.
class ResumeState {
  ResumeState({
    required this.key,
    required this.tid,
    required this.peerFingerprint,
    required this.files,
    required this.createdAt,
    required this.updatedAt,
    Map<int, String>? done,
    Map<String, String>? topFolders,
    this.partialIndex,
  }) : done = done ?? {},
       topFolders = topFolders ?? {};

  final String key;
  final String tid;
  final String peerFingerprint;

  /// (relative path, size) as offered.
  final List<(String, int)> files;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Index -> where the verified file was saved.
  final Map<int, String> done;

  /// ReceiveBatch.topFolders, so a resumed folder lands in the same folder.
  final Map<String, String> topFolders;

  /// Index of the file whose partial data is in [partFile], if any.
  int? partialIndex;

  bool matches(List<(String, int)> offer) {
    if (offer.length != files.length) return false;
    for (var i = 0; i < offer.length; i++) {
      if (offer[i] != files[i]) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => {
    'schema_version': ResumeStore.schemaVersion,
    'tid': tid,
    'peer_fp': peerFingerprint,
    'files': [
      for (final f in files) {'path': f.$1, 'size': f.$2},
    ],
    'done': {for (final e in done.entries) '${e.key}': e.value},
    'top_folders': topFolders,
    'partial_index': partialIndex,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

class ResumeStore {
  ResumeStore(this.dir, {this.maxAge = const Duration(days: 7)});

  static const int schemaVersion = 1;

  final Directory dir;
  final Duration maxAge;

  static String keyFor(String peerFp, String tid) =>
      sha256.convert(utf8.encode('$peerFp|$tid')).toString().substring(0, 32);

  File _meta(String key) => File(p.join(dir.path, '$key.json'));
  File partFile(String key) => File(p.join(dir.path, '$key.part'));

  /// Loads a state for this sender and transfer id, or null.
  Future<ResumeState?> load(String peerFp, String tid) async {
    final key = keyFor(peerFp, tid);
    final f = _meta(key);
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (j['schema_version'] != schemaVersion ||
          j['peer_fp'] != peerFp ||
          j['tid'] != tid) {
        await discard(key);
        return null;
      }
      final s = ResumeState(
        key: key,
        tid: tid,
        peerFingerprint: peerFp,
        files: [
          for (final x in (j['files'] as List))
            ((x as Map)['path'] as String, x['size'] as int),
        ],
        done: {
          for (final e in (j['done'] as Map).entries)
            int.parse(e.key as String): e.value as String,
        },
        topFolders: {
          for (final e in ((j['top_folders'] as Map?) ?? const {}).entries)
            e.key as String: e.value as String,
        },
        partialIndex: j['partial_index'] as int?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
      if (DateTime.now().toUtc().difference(s.updatedAt) > maxAge) {
        await discard(key);
        return null;
      }
      return s;
    } catch (_) {
      await discard(key);
      return null;
    }
  }

  Future<ResumeState> create(
    String peerFp,
    String tid,
    List<(String, int)> files,
  ) async {
    final key = keyFor(peerFp, tid);
    await discard(key);
    final now = DateTime.now().toUtc();
    final s = ResumeState(
      key: key,
      tid: tid,
      peerFingerprint: peerFp,
      files: files,
      createdAt: now,
      updatedAt: now,
    );
    await save(s);
    return s;
  }

  Future<void> save(ResumeState s) async {
    await dir.create(recursive: true);
    s.updatedAt = DateTime.now().toUtc();
    final f = _meta(s.key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(s.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  /// Bytes already stored for file [i] of [s] (0 if none or not that file).
  Future<int> partialLength(ResumeState s, int i) async {
    if (s.partialIndex != i) return 0;
    final f = partFile(s.key);
    if (!await f.exists()) return 0;
    final n = await f.length();
    return n <= s.files[i].$2 ? n : 0;
  }

  Future<void> discard(String key) async {
    for (final f in [
      _meta(key),
      partFile(key),
      File('${_meta(key).path}.tmp'),
    ]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Deletes states older than [maxAge] (called at start).
  Future<void> cleanup() async {
    if (!await dir.exists()) return;
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.part')) {
        // Partial data without its state file can never be resumed.
        final meta = File('${e.path.substring(0, e.path.length - 5)}.json');
        if (!await meta.exists()) {
          try {
            await e.delete();
          } catch (_) {}
        }
        continue;
      }
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await e.readAsString()) as Map<String, dynamic>;
        final at = DateTime.parse(j['updated_at'] as String);
        if (DateTime.now().toUtc().difference(at) > maxAge) {
          await discard(p.basenameWithoutExtension(e.path));
        }
      } catch (_) {
        await discard(p.basenameWithoutExtension(e.path));
      }
    }
  }

  ReceiveBatch batchFor(ResumeState s) {
    final b = ReceiveBatch();
    b.topFolders.addAll(s.topFolders);
    return b;
  }
}
