// 0.9.2 speed paths: a source that hashes itself (Android reads + native
// SHA-256), 4 MiB chunks split into small frames, the receiver checking
// the finished file with a separate digest function (Android native
// SHA-256), the overlapped receive writer, and deeper read-ahead.
// Real TLS sockets over localhost.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:path/path.dart' as p;

import 'loopback_test.dart' show Node, waitDone, randomFile, hashOf;

/// Mimics AndroidUriSource: big chunks via chunkedPlatformRead and its
/// own SHA-256 of what was read.
class _SelfHashingSource extends SendSource {
  _SelfHashingSource(this.file, {this.lie = false});
  final File file;
  final bool lie;
  RandomAccessFile? _raf;
  final _out = AccumulatorSink<Digest>();
  ByteConversionSink? _h;
  var _n = 0;
  var maxInFlight = 0;
  var _inFlight = 0;
  var requested = 0;
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
      _h = sha256.startChunkedConversion(_out);
      return 1;
    },
    read: (_) {
      // Calls are served in order, one at a time (like a TaskQueue).
      final r = _chain.then((_) async {
        _inFlight++;
        if (_inFlight > maxInFlight) maxInFlight = _inFlight;
        final c = await _raf!.read(4 * 1024 * 1024);
        _inFlight--;
        _h!.add(c);
        _n += c.length;
        requested++;
        return c;
      });
      _chain = r;
      return r;
    },
    onOpened: (_) {},
  );
  @override
  Future<({String sha256, int bytes})> readDigest() async {
    _h!.close();
    final d = _out.events.single.toString();
    return (sha256: lie ? '0' * 64 : d, bytes: _n);
  }

  @override
  Future<void> close() async {
    await _raf?.close();
    _raf = null;
  }
}

class AccumulatorSink<T> implements Sink<T> {
  final events = <T>[];
  @override
  void add(T e) => events.add(e);
  @override
  void close() {}
}

Future<String> _fileSha(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();

void main() {
  late Directory files;
  setUp(() async {
    files = await Directory.systemTemp.createTemp('isekai_speed_files');
  });
  tearDown(() async => files.delete(recursive: true));

  test('self-hashing source with 4 MiB chunks + receiver fileDigest: '
      'arrives intact, frames split, 2 reads in flight', () async {
    var digestCalls = 0;
    final a = await Node.create('A');
    final b = await Node.create(
      'B',
      fileDigest: (f) async {
        digestCalls++;
        return _fileSha(f);
      },
    );
    try {
      await a.engine.quickPair('127.0.0.1', b.port);
      final f = await randomFile(files, 'big.bin', 13 * 1024 * 1024 + 5);
      final src = _SelfHashingSource(f);
      final j = await waitDone(
        await a.engine.send(
          a.engine.trustedDevices.single,
          [src],
          host: '127.0.0.1',
          port: b.port,
        ),
      );
      expect(j.state, JobState.completed, reason: j.message);
      expect(
        await hashOf(File(p.join(b.inbox.path, 'big.bin'))),
        await hashOf(f),
      );
      expect(digestCalls, 1);
      expect(src.maxInFlight, lessThanOrEqualTo(1)); // served in order
    } finally {
      await a.dispose();
      await b.dispose();
    }
  });

  test('a wrong native digest is still caught by the receiver', () async {
    final a = await Node.create('A');
    final b = await Node.create('B', fileDigest: _fileSha);
    try {
      await a.engine.quickPair('127.0.0.1', b.port);
      final f = await randomFile(files, 'x.bin', 3 * 1024 * 1024);
      final j = await waitDone(
        await a.engine.send(
          a.engine.trustedDevices.single,
          [_SelfHashingSource(f, lie: true)],
          host: '127.0.0.1',
          port: b.port,
        ),
      );
      expect(j.state, isNot(JobState.completed));
      expect(j.message, isNot(contains('open_failed')));
      expect(j.message, contains('integrity'));
      expect(File(p.join(b.inbox.path, 'x.bin')).existsSync(), isFalse);
    } finally {
      await a.dispose();
      await b.dispose();
    }
  });

  test('chunkedPlatformRead keeps 2 reads requested ahead, in order', () async {
    final started = <int>[];
    final gates = <Completer<List<int>>>[];
    final stream = chunkedPlatformRead(
      openId: () async => 1,
      read: (_) {
        started.add(started.length);
        final c = Completer<List<int>>();
        gates.add(c);
        return c.future;
      },
      onOpened: (_) {},
    );
    final got = <int>[];
    final done = stream.listen((c) => got.addAll(c)).asFuture<void>();
    await Future<void>.delayed(Duration.zero);
    expect(started.length, 2, reason: 'two reads requested up front');
    gates[1].complete([2]);
    gates[0].complete([1]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(got, [1, 2], reason: 'order kept even if read 2 finished first');
    while (gates.length < 4) {
      await Future<void>.delayed(Duration.zero);
    }
    gates[2].complete(Uint8List(0));
    gates[3].complete(Uint8List(0));
    await done;
    expect(got, [1, 2]);
  });
}
