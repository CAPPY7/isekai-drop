import 'dart:io';

import 'package:path/path.dart' as p;

import 'identity.dart';

const _reserved = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// Makes a received file name safe: no folders, no "..", no hidden files,
/// no control or Windows-forbidden characters, no reserved device names.
String sanitizeFileName(String raw) {
  var name = raw.split(RegExp(r'[/\\]')).last;
  name = name.replaceAll(RegExp(r'[\x00-\x1F\x7F<>:"|?*]'), '_').trim();
  while (name.startsWith('.')) {
    name = name.substring(1);
  }
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = 'file';
  final base = name.split('.').first.toUpperCase();
  if (_reserved.contains(base)) name = '_$name';
  if (name.length > 180) {
    final ext = p.extension(name);
    final keep = ext.length <= 20 ? ext : '';
    name = name.substring(0, 180 - keep.length) + keep;
  }
  return name;
}

bool isInsideDirectory(Directory dir, String path) =>
    p.isWithin(p.canonicalize(dir.path), p.canonicalize(path));

/// Reserves a new, not-yet-existing target file inside [dir]. Creates it
/// exclusively so an existing file is never overwritten.
Future<File> reserveTarget(Directory dir, String safeName) async {
  final ext = p.extension(safeName);
  final base = p.basenameWithoutExtension(safeName);
  for (var i = 0; i < 10000; i++) {
    final candidate = i == 0 ? safeName : '$base ($i)$ext';
    final f = File(p.join(dir.path, candidate));
    if (!isInsideDirectory(dir, f.path)) {
      throw const FileSystemException('Unsafe path rejected');
    }
    try {
      await f.create(exclusive: true);
      return f;
    } on FileSystemException {
      continue;
    }
  }
  throw const FileSystemException('No free file name');
}

/// A hidden temporary file in [dir], created exclusively.
Future<File> createTempPart(Directory dir) async {
  await dir.create(recursive: true);
  final f = File(p.join(dir.path, '.isekai-${randomHex(8)}.part'));
  await f.create(exclusive: true);
  return f;
}

/// Makes a received RELATIVE path safe (for folders). Every part is cleaned
/// like a file name; "", "." and ".." parts are dropped, so the result can
/// never point outside the receive folder. Returns parts joined with "/".
String sanitizeRelativePath(String raw) {
  final parts = <String>[];
  for (final seg in raw.split(RegExp(r'[/\\]'))) {
    final t = seg.trim();
    if (t.isEmpty || t == '.' || t == '..') continue;
    if (RegExp(r'^[A-Za-z]:$').hasMatch(t)) continue; // drive letters
    parts.add(sanitizeFileName(t));
  }
  if (parts.isEmpty) return 'file';
  // Limit depth: keep the last 32 parts at most.
  final kept = parts.length > 32 ? parts.sublist(parts.length - 32) : parts;
  return kept.join('/');
}

/// Folder names already chosen in one transfer, so a received folder never
/// merges into an existing folder with the same name ("Photos (1)").
class ReceiveBatch {
  final Map<String, String> topFolders = {};
}

/// Reserves a NEW top-level folder inside [dir] (never reuses an existing one).
Future<Directory> reserveFolder(Directory dir, String safeName) async {
  for (var i = 0; i < 10000; i++) {
    final candidate = i == 0 ? safeName : '$safeName ($i)';
    final d = Directory(p.join(dir.path, candidate));
    if (!isInsideDirectory(dir, d.path)) {
      throw const FileSystemException('Unsafe path rejected');
    }
    if (await d.exists() || await File(d.path).exists()) continue;
    await d.create(recursive: true);
    return d;
  }
  throw const FileSystemException('No free folder name');
}

/// Places a relative path inside [dir]: picks a unique top folder once per
/// batch, creates sub-folders, and never overwrites a file.
Future<File> reserveRelativeTarget(
  Directory dir,
  String safeRelPath,
  ReceiveBatch batch,
) async {
  final parts = safeRelPath.split('/');
  if (parts.length == 1) return reserveTarget(dir, parts.single);
  final top = parts.first;
  var topName = batch.topFolders[top];
  if (topName == null) {
    topName = p.basename((await reserveFolder(dir, top)).path);
    batch.topFolders[top] = topName;
  }
  final sub = Directory(
    p.joinAll([dir.path, topName, ...parts.sublist(1, parts.length - 1)]),
  );
  if (!isInsideDirectory(dir, sub.path)) {
    throw const FileSystemException('Unsafe path rejected');
  }
  await sub.create(recursive: true);
  return reserveTarget(sub, parts.last);
}
