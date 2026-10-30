import 'dart:io';

/// A file to send. [open] returns a stream that reads it in pieces, so the
/// whole file is never loaded into memory.
///
/// [name] is the display name. [relativePath] keeps folder structure
/// ("Holiday/day1/a.jpg") when a folder is sent; for single files it is just
/// the name.
abstract class SendSource {
  String get name;
  String get relativePath => name;
  int get size;
  Stream<List<int>> open();
  Future<void> close() async {}

  /// Audit #14: something that changes when the content changes (here the
  /// modification time), so a different file with the same name and size
  /// gets a different resume id. Null if the source cannot tell.
  String? get versionTag => null;
}

class FileSendSource extends SendSource {
  FileSendSource(this.file, {String? name, int? size, String? relativePath})
    : name = name ?? file.uri.pathSegments.last,
      size = size ?? file.lengthSync(),
      _rel = relativePath,
      _mtime = _safeMtime(file);

  static int? _safeMtime(File f) {
    try {
      return f.lastModifiedSync().microsecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  final int? _mtime;

  @override
  String? get versionTag => _mtime == null ? null : 'm$_mtime';

  final File file;
  @override
  final String name;
  @override
  final int size;
  final String? _rel;

  @override
  String get relativePath => _rel ?? name;

  @override
  Stream<List<int>> open() => file.openRead();
}

/// Lists all regular files inside [dir] (symbolic links are skipped), with
/// paths relative to the folder's parent so the folder name is kept.
Future<List<SendSource>> folderSources(Directory dir) async {
  final parent = dir.parent.path;
  final out = <SendSource>[];
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final rel = e.path
        .substring(parent.length)
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    try {
      out.add(FileSendSource(e, relativePath: rel));
    } catch (_) {
      // Unreadable file: skipped.
    }
  }
  out.sort((a, b) => a.relativePath.compareTo(b.relativePath));
  return out;
}

/// Reading the file on THIS device failed (not a network problem).
class SourceReadException implements Exception {
  const SourceReadException(this.reason);

  /// Short class only ("no_permission", "not_found", ...). No paths.
  final String reason;
  @override
  String toString() => 'SourceReadException($reason)';
}

/// Streams a file from a platform reader in chunks: [openId] opens it,
/// [read] returns the next chunk (empty = end). One read is always in
/// flight ahead, so the network is not idle while the next chunk loads.
/// Every failure is reported as [SourceReadException].
Stream<List<int>> chunkedPlatformRead({
  required Future<int> Function() openId,
  required Future<List<int>?> Function(int id) read,
  required void Function(int id) onOpened,
}) async* {
  int id;
  try {
    id = await openId();
  } on SourceReadException {
    rethrow;
  } catch (e) {
    throw SourceReadException(_reasonOf(e));
  }
  onOpened(id);
  Future<List<int>?> next() => read(id)..ignore();
  var pending = next();
  while (true) {
    List<int>? chunk;
    try {
      chunk = await pending;
    } catch (e) {
      throw SourceReadException(_reasonOf(e));
    }
    if (chunk == null || chunk.isEmpty) return;
    pending = next();
    yield chunk;
  }
}

String _reasonOf(Object e) {
  final s = e.toString();
  for (final r in const [
    'no_permission',
    'not_found',
    'read_failed',
    'closed',
  ]) {
    if (s.contains(r)) return r;
  }
  return 'open_failed';
}
