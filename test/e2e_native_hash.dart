// Box-only stand-ins for the Android 0.9.2 speed path, for the two-process
// e2e harness (E2E_NATIVE_HASH=1): the sender reads 4 MiB chunks with two
// reads in flight and gets the SHA-256 from a native tool (sha256sum, run
// in parallel like Kotlin's MessageDigest runs beside the Dart isolate);
// the receiver checks the finished file with sha256sum. Not used by the app.
import 'dart:io';

import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:path/path.dart' as p;

final bool e2eNativeHash = Platform.environment['E2E_NATIVE_HASH'] == '1';

Future<String> nativeFileSha256(File f) async {
  final r = await Process.run('sha256sum', [f.path]);
  if (r.exitCode != 0) throw FileSystemException('sha256sum failed', f.path);
  return (r.stdout as String).split(' ').first;
}

class NativeHashFileSource extends SendSource {
  NativeHashFileSource(this.file);
  final File file;
  RandomAccessFile? _raf;
  Future<String>? _digest;
  var _n = 0;
  Future<void> _chain = Future.value();

  @override
  String get name => p.basename(file.path);
  @override
  int get size => file.lengthSync();
  @override
  bool get hashesItself => true;

  @override
  Stream<List<int>> open() => chunkedPlatformRead(
    openId: () async {
      _raf = await file.open();
      _digest = nativeFileSha256(file);
      return 1;
    },
    read: (_) {
      final r = _chain.then((_) async {
        final c = await _raf!.read(4 * 1024 * 1024);
        _n += c.length;
        return c;
      });
      _chain = r;
      return r;
    },
    onOpened: (_) {},
  );

  @override
  Future<({String sha256, int bytes})> readDigest() async =>
      (sha256: await _digest!, bytes: _n);

  @override
  Future<void> close() async {
    await _chain.catchError((_) {});
    await _raf?.close();
    _raf = null;
  }
}
