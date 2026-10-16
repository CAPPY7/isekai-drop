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
}

class FileSendSource extends SendSource {
  FileSendSource(this.file, {String? name, int? size, String? relativePath})
    : name = name ?? file.uri.pathSegments.last,
      size = size ?? file.lengthSync(),
      _rel = relativePath;

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
