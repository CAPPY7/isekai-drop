import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

const _android = MethodChannel('isekai_drop/android');
const _apple = MethodChannel('isekai_drop/apple');

/// Audit #16: free bytes on the volume holding [dir], or null if unknown
/// (then the receiver does not check). Never throws.
Future<int?> freeBytesFor(Directory dir) async {
  try {
    await dir.create(recursive: true);
    if (Platform.isAndroid) {
      return await _android.invokeMethod<int>('freeSpace', {'path': dir.path});
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return await _apple.invokeMethod<int>('freeSpace', {'path': dir.path});
    }
    if (Platform.isLinux) return await linuxFreeBytes(dir.path);
    if (Platform.isWindows) return _windowsFreeBytes(dir.path);
  } catch (_) {}
  return null;
}

/// Linux: POSIX `df -Pk` (available 1K-blocks, 4th column).
Future<int?> linuxFreeBytes(String path) async {
  final r = await Process.run('df', ['-Pk', path]);
  if (r.exitCode != 0) return null;
  return parseDfAvailable(r.stdout as String);
}

int? parseDfAvailable(String out) {
  final lines = out.trim().split('\n');
  if (lines.length < 2) return null;
  final cols = lines.last.trim().split(RegExp(r'\s+'));
  if (cols.length < 4) return null;
  final kb = int.tryParse(cols[3]);
  return kb == null ? null : kb * 1024;
}

typedef _GetFreeC = Int32 Function(
  Pointer<Utf16> dir,
  Pointer<Uint64> avail,
  Pointer<Uint64> total,
  Pointer<Uint64> free,
);
typedef _GetFreeDart = int Function(
  Pointer<Utf16> dir,
  Pointer<Uint64> avail,
  Pointer<Uint64> total,
  Pointer<Uint64> free,
);

int? _windowsFreeBytes(String path) {
  final fn = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<_GetFreeC, _GetFreeDart>('GetDiskFreeSpaceExW');
  final p = path.toNativeUtf16();
  final avail = calloc<Uint64>();
  try {
    if (fn(p, avail, nullptr, nullptr) == 0) return null;
    return avail.value;
  } finally {
    calloc.free(p);
    calloc.free(avail);
  }
}
