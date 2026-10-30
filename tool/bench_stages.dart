// Stage-by-stage speed measurement (box / desktop only). Run AOT for numbers
// close to a release build:
//   dart compile exe tool/bench_stages.dart -o /tmp/bench_stages
//   /tmp/bench_stages <stage> <file> [chunkKiB] [certDir]
// Stages: read, hash, bghash, write, tls, tlsframes. Prints MB/s
// (MB = 1024*1024 bytes). Loopback numbers are NOT Wi-Fi numbers.
// FLUSH_KIB=<n> changes how often the TLS stages wait for the socket.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:isekaidrop/engine/core/bg_hasher.dart';
import 'package:isekaidrop/engine/core/frames.dart';

final int _flushEvery =
    int.parse(Platform.environment['FLUSH_KIB'] ?? '1024') * 1024;

Future<void> main(List<String> args) async {
  final stage = args[0];
  final file = File(args[1]);
  final chunk = (args.length > 2 ? int.parse(args[2]) : 64) * 1024;
  final certDir = args.length > 3 ? args[3] : '/tmp/bench';
  final size = await file.length();
  final sw = Stopwatch()..start();
  switch (stage) {
    case 'read':
      var n = 0;
      await for (final c in _read(file, chunk)) {
        n += c.length;
      }
      _report(stage, chunk, n, sw);
    case 'hash':
      final out = _Sink();
      final h = sha256.startChunkedConversion(out);
      var n = 0;
      await for (final c in _read(file, chunk)) {
        h.add(c);
        n += c.length;
      }
      h.close();
      _report(stage, chunk, n, sw);
    case 'bghash':
      final h = await BgHasher.start();
      var n = 0;
      await for (final c in _read(file, chunk)) {
        await h.add(c);
        n += c.length;
      }
      await h.close();
      _report(stage, chunk, n, sw);
    case 'write':
      final out = await File('${file.path}.out').open(mode: FileMode.write);
      var n = 0;
      await for (final c in _read(file, chunk)) {
        await out.writeFrom(c);
        n += c.length;
      }
      await out.close();
      await File('${file.path}.out').delete();
      _report(stage, chunk, n, sw);
    case 'tls':
    case 'tlsframes':
      final ctx = SecurityContext()
        ..useCertificateChain('$certDir/cert.pem')
        ..usePrivateKey('$certDir/key.pem');
      final server = await SecureServerSocket.bind('127.0.0.1', 0, ctx);
      final got = Completer<int>();
      server.listen((s) async {
        var n = 0;
        if (stage == 'tls') {
          await for (final b in s) {
            n += b.length;
            if (n >= size) break;
          }
        } else {
          final r = FrameReader(s);
          while (n < size) {
            final f = await r.next();
            n += f.payload.length;
          }
        }
        got.complete(n);
        s.destroy();
      });
      final c = await SecureSocket.connect(
        '127.0.0.1',
        server.port,
        onBadCertificate: (_) => true,
      );
      c.setOption(SocketOption.tcpNoDelay, true);
      sw.reset();
      var since = 0;
      await for (final b in _read(file, chunk)) {
        c.add(stage == 'tls' ? b : encodeFrame(frameData, b));
        since += b.length;
        if (since >= _flushEvery) {
          since = 0;
          await c.flush();
        }
      }
      await c.flush();
      final n = await got.future;
      _report(stage, chunk, n, sw);
      c.destroy();
      await server.close();
    case 'pipeline':
      // Mimics the engine: sender hashes + frames + flushes, receiver
      // parses frames, writes to disk and hashes. PIPE_NOHASH=1,
      // PIPE_NOWRITE=1 switch parts off to find the slow one.
      final noHash = Platform.environment['PIPE_NOHASH'] == '1';
      final noWrite = Platform.environment['PIPE_NOWRITE'] == '1';
      final ctx = SecurityContext()
        ..useCertificateChain('$certDir/cert.pem')
        ..usePrivateKey('$certDir/key.pem');
      final server = await SecureServerSocket.bind('127.0.0.1', 0, ctx);
      final got = Completer<int>();
      server.listen((s) async {
        var n = 0;
        final r = FrameReader(s);
        final h = await BgHasher.start();
        final out = await File('${file.path}.rx').open(mode: FileMode.write);
        while (n < size) {
          final f = await r.next();
          if (!noWrite) await out.writeFrom(f.payload);
          if (!noHash) await h.add(f.payload);
          n += f.payload.length;
        }
        await out.close();
        await h.close();
        await File('${file.path}.rx').delete();
        got.complete(n);
        s.destroy();
      });
      final c = await SecureSocket.connect(
        '127.0.0.1',
        server.port,
        onBadCertificate: (_) => true,
      );
      c.setOption(SocketOption.tcpNoDelay, true);
      sw.reset();
      final h = await BgHasher.start();
      var since = 0;
      await for (final b in _read(file, chunk)) {
        if (!noHash) await h.add(b);
        c.add(encodeFrame(frameData, b));
        since += b.length;
        if (since >= _flushEvery) {
          since = 0;
          await c.flush();
        }
      }
      await c.flush();
      await h.close();
      final n = await got.future;
      _report(stage, chunk, n, sw);
      c.destroy();
      await server.close();
    default:
      throw ArgumentError(stage);
  }
  exit(0);
}

Stream<Uint8List> _read(File f, int chunk) async* {
  if (chunk == 64 * 1024) {
    // File.openRead default chunking (what FileSendSource uses).
    yield* f.openRead().map((c) => c is Uint8List ? c : Uint8List.fromList(c));
    return;
  }
  final raf = await f.open();
  try {
    while (true) {
      final b = await raf.read(chunk);
      if (b.isEmpty) break;
      yield b;
    }
  } finally {
    await raf.close();
  }
}

void _report(String stage, int chunk, int n, Stopwatch sw) {
  final s = sw.elapsedMicroseconds / 1e6;
  print(
    'STAGE $stage chunk=${chunk ~/ 1024}KiB bytes=$n '
    'time=${s.toStringAsFixed(2)}s '
    'speed=${(n / 1048576 / s).toStringAsFixed(1)}MB/s',
  );
}

class _Sink implements Sink<Digest> {
  @override
  void add(Digest data) {}
  @override
  void close() {}
}
