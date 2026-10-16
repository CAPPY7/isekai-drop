// Phase 4 tests over REAL TLS loopback: folders, pause/resume, queue, QR.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/qr_payload.dart';
import 'package:isekaidrop/engine/core/safe_files.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:path/path.dart' as p;

import 'loopback_test.dart' show Node, pair, waitDone, randomFile, hashOf;

class _FakeSource extends SendSource {
  _FakeSource(this.relativePath, this.bytes);
  @override
  final String relativePath;
  final List<int> bytes;
  @override
  String get name => p.basename(relativePath);
  @override
  int get size => bytes.length;
  @override
  Stream<List<int>> open() => Stream.value(bytes);
}

Future<void> until(bool Function() test, {int ms = 10000}) async {
  final sw = Stopwatch()..start();
  while (!test()) {
    if (sw.elapsedMilliseconds > ms) throw TimeoutException('condition');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late Node a;
  late Node b;
  late Directory src;
  setUp(() async {
    a = await Node.create('Alice');
    b = await Node.create('Bob');
    await pair(a, b);
    src = await Directory.systemTemp.createTemp('isekai_src');
  });
  tearDown(() async {
    await a.dispose();
    await b.dispose();
    await src.delete(recursive: true);
  });

  TransferJob receiverJob() => b.engine.jobs.first;

  test('sanitizeRelativePath keeps folders but never escapes', () {
    expect(sanitizeRelativePath('Album/sub/a.jpg'), 'Album/sub/a.jpg');
    expect(sanitizeRelativePath('../../etc/passwd'), 'etc/passwd');
    expect(sanitizeRelativePath('/abs/x.txt'), 'abs/x.txt');
    expect(sanitizeRelativePath(r'C:\Windows\x.dll'), 'Windows/x.dll');
    expect(sanitizeRelativePath('a/./../b'), 'a/b');
    expect(sanitizeRelativePath('../..'), 'file');
    expect(sanitizeRelativePath('ok/CON/.hidden'), 'ok/_CON/hidden');
  });

  test(
    'folder is sent with its structure; a second copy never merges',
    () async {
      final album = Directory(p.join(src.path, 'Album'));
      await Directory(p.join(album.path, 'sub', 'deep'))
          .create(recursive: true);
      final f1 = await randomFile(album, 'a.bin', 100000);
      final f2 = await randomFile(
        Directory(p.join(album.path, 'sub')),
        'b.bin',
        2500000,
      );
      final f3 = await randomFile(
        Directory(p.join(album.path, 'sub', 'deep')),
        'c.bin',
        0,
      );
      final files = await folderSources(album);
      expect(files.map((f) => f.relativePath).toList(), [
        'Album/a.bin',
        'Album/sub/b.bin',
        'Album/sub/deep/c.bin',
      ]);
      final dev = a.engine.trustedDevices.single;
      var job = await waitDone(
        await a.engine.send(dev, files, host: '127.0.0.1', port: b.port),
      );
      expect(job.state, JobState.completed, reason: job.message);
      final got = p.join(b.inbox.path, 'Album');
      expect(await hashOf(File(p.join(got, 'a.bin'))), await hashOf(f1));
      expect(await hashOf(File(p.join(got, 'sub', 'b.bin'))), await hashOf(f2));
      expect(
        await hashOf(File(p.join(got, 'sub', 'deep', 'c.bin'))),
        await hashOf(f3),
      );
      job = await waitDone(
        await a.engine.send(
          dev,
          await folderSources(album),
          host: '127.0.0.1',
          port: b.port,
        ),
      );
      expect(job.state, JobState.completed, reason: job.message);
      expect(
        File(p.join(b.inbox.path, 'Album (1)', 'sub', 'b.bin')).existsSync(),
        isTrue,
      );
    },
  );

  test('hostile relative paths stay inside the receive folder', () async {
    final evil = [
      _FakeSource('../../evil1.txt', [1]),
      _FakeSource('/etc/evil2.txt', [2]),
      _FakeSource('x/../../../evil3.txt', [3]),
      _FakeSource(r'..\..\evil4.txt', [4]),
    ];
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        evil,
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.completed, reason: job.message);
    final all = b.root
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('evil'))
        .toList();
    expect(all.length, 4);
    for (final f in all) {
      expect(p.isWithin(b.inbox.path, f.path), isTrue, reason: f.path);
    }
  });

  test(
    'sender pause stops data on both sides; resume finishes verified',
    () async {
      final f = await randomFile(src, 'big.bin', 48 * 1024 * 1024);
      final job = await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(f)],
        host: '127.0.0.1',
        port: b.port,
      );
      await until(() => job.bytesDone > 0);
      job.pause();
      expect(job.paused, isTrue);
      await until(() => receiverJob().pausedByPeer);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final s1 = job.bytesDone, r1 = receiverJob().bytesDone;
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(job.bytesDone, s1, reason: 'sender moved data while paused');
      expect(
        receiverJob().bytesDone,
        r1,
        reason: 'receiver got data while paused',
      );
      expect(job.currentSpeed, isNull, reason: 'no speed shown while paused');
      job.resume();
      await waitDone(job);
      expect(job.state, JobState.completed, reason: job.message);
      expect(receiverJob().pausedByPeer, isFalse);
      expect(
        await hashOf(File(p.join(b.inbox.path, 'big.bin'))),
        await hashOf(f),
      );
    },
  );

  test(
    'receiver pause holds the sender (back-pressure); resume finishes',
    () async {
      final f = await randomFile(src, 'big2.bin', 64 * 1024 * 1024);
      final job = await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(f)],
        host: '127.0.0.1',
        port: b.port,
      );
      await until(
        () => b.engine.jobs.isNotEmpty && receiverJob().bytesDone > 0,
      );
      final r = receiverJob()..pause();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      final s1 = job.bytesDone, r1 = r.bytesDone;
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(r.bytesDone, r1);
      // The sender can only fill the network buffers, then must wait.
      expect(job.bytesDone - s1, lessThan(8 * 1024 * 1024));
      expect(job.bytesDone, lessThan(f.lengthSync()));
      r.resume();
      await waitDone(job);
      await waitDone(r);
      expect(job.state, JobState.completed, reason: job.message);
      expect(
        await hashOf(File(p.join(b.inbox.path, 'big2.bin'))),
        await hashOf(f),
      );
    },
  );

  test('cancel while paused deletes the unfinished file', () async {
    final f = await randomFile(src, 'c.bin', 32 * 1024 * 1024);
    final job = await a.engine.send(
      a.engine.trustedDevices.single,
      [FileSendSource(f)],
      host: '127.0.0.1',
      port: b.port,
    );
    await until(() => job.bytesDone > 0);
    job.pause();
    await until(() => receiverJob().pausedByPeer);
    job.cancel();
    await waitDone(receiverJob());
    expect(receiverJob().state, isNot(JobState.completed));
    expect(b.inboxNames().where((n) => !n.startsWith('.')).toList(), isEmpty);
    expect(b.inboxNames().where((n) => n.endsWith('.part')).toList(), isEmpty);
  });

  test('queue: a second send waits until the first one finishes', () async {
    final f1 = await randomFile(src, 'q1.bin', 16 * 1024 * 1024);
    final f2 = await randomFile(src, 'q2.bin', 1024);
    final dev = a.engine.trustedDevices.single;
    final j1 = await a.engine.send(
      dev,
      [FileSendSource(f1)],
      host: '127.0.0.1',
      port: b.port,
    );
    final j2 = await a.engine.send(
      dev,
      [FileSendSource(f2)],
      host: '127.0.0.1',
      port: b.port,
    );
    expect(j2.queued, isTrue);
    await until(() => j1.state == JobState.running);
    expect(j2.state, JobState.waiting);
    await waitDone(j1);
    await waitDone(j2);
    expect(j1.state, JobState.completed);
    expect(j2.state, JobState.completed);
    expect(b.inboxNames(), containsAll(['q1.bin', 'q2.bin']));
  });

  test('QR payload round-trips and rejects junk', () {
    final fp = 'ab' * 32;
    final q = PairingQr(
      hosts: ['192.168.43.1', '10.0.0.2'],
      port: 47820,
      fingerprint: fp,
      name: 'My Phone',
    );
    final back = PairingQr.tryParse(q.encode())!;
    expect(back.hosts, q.hosts);
    expect(back.port, 47820);
    expect(back.fingerprint, fp);
    expect(back.name, 'My Phone');
    expect(PairingQr.tryParse('https://example.com'), isNull);
    expect(
      PairingQr.tryParse('isekaidrop:pair?v=1&h=1.2.3.4&p=1&f=zz'),
      isNull,
    );
    expect(
      PairingQr.tryParse('isekaidrop:pair?v=1&h=evil;rm&p=80&f=$fp'),
      isNull,
    );
  });

  test('QR pairing refuses a device whose key differs from the code', () async {
    final c = await Node.create('Carol');
    try {
      await expectLater(
        c.engine.beginPairing(
          '127.0.0.1',
          b.port,
          expectFingerprint: 'cd' * 32,
        ),
        throwsA(anything),
      );
      final ok = await c.engine.beginPairing(
        '127.0.0.1',
        b.port,
        expectFingerprint: b.engine.myFingerprint,
      );
      expect(ok.verifiedByQr, isTrue);
      ok.cancel();
    } finally {
      await c.dispose();
    }
  });

  test('500 small files in a folder (measured on loopback)', () async {
    final dir = Directory(p.join(src.path, 'Many'));
    await dir.create();
    for (var i = 0; i < 500; i++) {
      await File(p.join(dir.path, 'f$i.txt'))
          .writeAsString('file $i ' * (1 + i % 50));
    }
    final files = await folderSources(dir);
    final sw = Stopwatch()..start();
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        files,
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    sw.stop();
    expect(job.state, JobState.completed, reason: job.message);
    expect(Directory(p.join(b.inbox.path, 'Many')).listSync().length, 500);
    // ignore: avoid_print
    print(
      'MEASURED: 500 small files (${job.totalBytes} bytes) in '
      '${sw.elapsedMilliseconds} ms on loopback',
    );
  });
}
