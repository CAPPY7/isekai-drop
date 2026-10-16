import 'dart:io';

/// A file to send. [open] returns a stream that reads it in pieces, so the
/// whole file is never loaded into memory.
abstract class SendSource {
  String get name;
  int get size;
  Stream<List<int>> open();
  Future<void> close() async {}
}

class FileSendSource extends SendSource {
  FileSendSource(this.file, {String? name, int? size})
    : name = name ?? file.uri.pathSegments.last,
      size = size ?? file.lengthSync();

  final File file;
  @override
  final String name;
  @override
  final int size;

  @override
  Stream<List<int>> open() => file.openRead();
}
