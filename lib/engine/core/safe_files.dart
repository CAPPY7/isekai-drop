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
