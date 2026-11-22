// C3 (0.11.4): what the file and folder pickers added, and how many files
// they could NOT add (and why), so the Send screen can say so.
import 'dart:io';

import 'core/send_source.dart';
import 'platform_engine.dart' show AndroidUriSource;

/// Most folders deep a picked Android folder is read (MainActivity.walk).
const int kPickMaxDepth = 32;

/// Most files one picked Android folder can add (MainActivity.walk).
const int kPickMaxFiles = 20000;

class SkippedFiles {
  const SkippedFiles({
    this.unknownSize = 0,
    this.tooDeep = 0,
    this.tooMany = 0,
    this.unreadable = 0,
  });

  /// Files whose size the system did not tell (cannot be verified).
  final int unknownSize;

  /// Folders (with everything in them) deeper than [kPickMaxDepth].
  final int tooDeep;

  /// Files over the [kPickMaxFiles] limit of one folder.
  final int tooMany;

  /// Files that could not be opened or read.
  final int unreadable;

  int get total => unknownSize + tooDeep + tooMany + unreadable;

  SkippedFiles operator +(SkippedFiles o) => SkippedFiles(
    unknownSize: unknownSize + o.unknownSize,
    tooDeep: tooDeep + o.tooDeep,
    tooMany: tooMany + o.tooMany,
    unreadable: unreadable + o.unreadable,
  );

  /// Plain sentences for the Send screen (empty when nothing was skipped).
  List<String> get messages => [
    if (unknownSize > 0)
      unknownSize == 1
          ? '1 file was not added: its size could not be read.'
          : '$unknownSize files were not added: their size could not be read.',
    if (unreadable > 0)
      unreadable == 1
          ? '1 file was not added: it could not be read.'
          : '$unreadable files were not added: they could not be read.',
    if (tooDeep > 0)
      tooDeep == 1
          ? '1 folder was not added: it is more than $kPickMaxDepth folders deep.'
          : '$tooDeep folders were not added: they are more than '
                '$kPickMaxDepth folders deep.',
    if (tooMany > 0)
      tooMany == 1
          ? '1 file was not added: a folder can add at most $kPickMaxFiles files.'
          : '$tooMany files were not added: a folder can add at most '
                '$kPickMaxFiles files.',
  ];
}

class PickResult {
  const PickResult(this.files, [this.skipped = const SkippedFiles()]);
  static const empty = PickResult(<SendSource>[]);
  final List<SendSource> files;
  final SkippedFiles skipped;
}

int _size(Object? v) => v is num ? v.toInt() : -1;

/// Result of the Android 'pickFiles' call.
PickResult parseAndroidPicked(List<Object?> list) {
  final out = <SendSource>[];
  var unknown = 0;
  for (final x in list) {
    final m = x as Map;
    final size = _size(m['size']);
    if (size < 0) {
      unknown++; // Unknown size: cannot be verified.
      continue;
    }
    out.add(AndroidUriSource(m['uri'] as String, m['name'] as String, size));
  }
  return PickResult(out, SkippedFiles(unknownSize: unknown));
}

/// Result of the Android 'pickFolder' call (null = cancelled).
PickResult parseAndroidFolder(Map<Object?, Object?>? m) {
  if (m == null) return PickResult.empty;
  final out = <SendSource>[];
  var unknown = 0;
  for (final f in (m['files'] as List? ?? const [])) {
    final x = f as Map;
    final size = _size(x['size']);
    if (size < 0) {
      unknown++;
      continue;
    }
    out.add(
      AndroidUriSource(
        x['uri'] as String,
        x['name'] as String,
        size,
        relativePath: x['rel'] as String,
      ),
    );
  }
  return PickResult(
    out,
    SkippedFiles(
      unknownSize: unknown,
      tooDeep: _size(m['skippedDeep']).clamp(0, 1 << 30),
      tooMany: _size(m['skippedMany']).clamp(0, 1 << 30),
    ),
  );
}

/// C6: a picker result Android kept because the app was recreated while
/// the picker was open ({'files': [...]} or {'folder': {...}}; null: none).
PickResult parseLostPick(Map<Object?, Object?>? m) {
  if (m == null) return PickResult.empty;
  final folder = m['folder'];
  if (folder is Map) return parseAndroidFolder(folder);
  final files = m['files'];
  if (files is List) return parseAndroidPicked(files);
  return PickResult.empty;
}

/// Desktop: every file inside [dir], keeping the structure; files that
/// cannot be read are counted, not added.
Future<PickResult> folderPick(
  Directory dir, {
  bool Function(File f)? canRead,
}) async {
  final parent = dir.parent.path;
  final out = <SendSource>[];
  var unreadable = 0;
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final rel = e.path
        .substring(parent.length)
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    if (canRead != null && !canRead(e)) {
      unreadable++;
      continue;
    }
    try {
      out.add(FileSendSource(e, relativePath: rel));
    } on FileSystemException {
      unreadable++;
    }
  }
  out.sort((a, b) => a.relativePath.compareTo(b.relativePath));
  return PickResult(out, SkippedFiles(unreadable: unreadable));
}
