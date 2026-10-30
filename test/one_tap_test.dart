// 0.9.1: one-tap pairing, pair+send with one question, stage-specific
// errors and the two root causes of "sending fails at 0 B" in 0.9.0.
// Real TLS sockets over localhost; only the Accept buttons are simulated.
import 'dart:async';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:path/path.dart' as p;

import 'loopback_test.dart' show Node, waitDone, randomFile, hashOf;

NearbyDevice nearbyOf(Node n) => NearbyDevice(
  deviceId: n.engine.identity.deviceId,
  name: n.engine.deviceName(),
  platform: 'linux',
  host: '127.0.0.1',
  port: n.port,
  seenAt: DateTime.now(),
);

class _FailingSource extends SendSource {
  _FailingSource(this.size);
  @override
  String get name => 'broken.bin';
  @override
  final int size;
  @override
  Stream<List<int>> open() => chunkedPlatformRead(
    openId: () async => 1,
    read: (_) async => throw Exception('EACCES (Permission denied)'),
    onOpened: (_) {},
  );
}

void main() {
  late Node a;
  late Node b;
  late Directory files;
  setUp(() async {
    a = await Node.create('Alice');
    b = await Node.create('Bob');
    files = await Directory.systemTemp.createTemp('isekai_onetap_files');
  });
  tearDown(() async {
    await a.dispose();
    await b.dispose();
    await files.delete(recursive: true);
  });

  test('quickPair: one question on the other device, both trust each other '
      '(not Verified)', () async {
    final dev = await a.engine.quickPair('127.0.0.1', b.port);
    expect(b.asked.length, 1);
    expect(b.asked.single.kind, RequestKind.pairing);
    expect(b.asked.single.offerCount, 0);
    expect(dev.isTrusted, isTrue);
    expect(dev.isVerified, isFalse);
    final onB = b.engine.trustedDevices.single;
    expect(onB.fingerprint, a.engine.myFingerprint);
    expect(onB.isTrusted, isTrue);
    expect(onB.isVerified, isFalse);
  });

  test('send after one-tap pairing works in both directions, >10 MB, '
      'each send asks once', () async {
    await a.engine.quickPair('127.0.0.1', b.port);
    final f1 = await randomFile(files, 'a-to-b.bin', 12 * 1024 * 1024 + 7);
    final f2 = await randomFile(files, 'b-to-a.bin', 11 * 1024 * 1024 + 3);
    final j1 = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(f1)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(j1.state, JobState.completed, reason: j1.message);
    expect(
      await hashOf(File(p.join(b.inbox.path, 'a-to-b.bin'))),
      await hashOf(f1),
    );
    final j2 = await waitDone(
      await b.engine.send(
        b.engine.trustedDevices.single,
        [FileSendSource(f2)],
        host: '127.0.0.1',
        port: a.port,
      ),
    );
    expect(j2.state, JobState.completed, reason: j2.message);
    expect(
      await hashOf(File(p.join(a.inbox.path, 'b-to-a.bin'))),
      await hashOf(f2),
    );
    expect(b.asked.map((r) => r.kind).toList(), [
      RequestKind.pairing,
      RequestKind.transfer,
    ]);
    expect(a.asked.map((r) => r.kind).toList(), [RequestKind.transfer]);
  });

  test('send to an UNPAIRED nearby device: exactly one question, file '
      'arrives, both paired afterwards (both directions)', () async {
    final f1 = await randomFile(files, 'big.bin', 12 * 1024 * 1024 + 1);
    final j1 = await waitDone(
      await a.engine.sendToNearby(nearbyOf(b), [FileSendSource(f1)]),
    );
    expect(j1.state, JobState.completed, reason: j1.message);
    expect(b.asked.length, 1, reason: 'pair+send must ask only once');
    final q = b.asked.single;
    expect(q.kind, RequestKind.pairing);
    expect(q.offerCount, 1);
    expect(q.totalBytes, f1.lengthSync());
    expect(q.fileNames, ['big.bin']);
    expect(
      await hashOf(File(p.join(b.inbox.path, 'big.bin'))),
      await hashOf(f1),
    );
    expect(a.engine.trustedDevices.single.isTrusted, isTrue);
    expect(b.engine.trustedDevices.single.isTrusted, isTrue);

    // Reverse direction: B now knows A, so it is a normal send (one ask).
    final f2 = await randomFile(files, 'back.bin', 10 * 1024 * 1024 + 9);
    final nA = nearbyOf(a).withTrust(b.engine.trustedDevices.single);
    final j2 = await waitDone(
      await b.engine.sendToNearby(nA, [FileSendSource(f2)]),
    );
    expect(j2.state, JobState.completed, reason: j2.message);
    expect(a.asked.single.kind, RequestKind.transfer);
    expect(
      await hashOf(File(p.join(a.inbox.path, 'back.bin'))),
      await hashOf(f2),
    );

    // A second send A->B is NOT pre-approved any more (one-time).
    final f3 = await randomFile(files, 'again.bin', 1000);
    final j3 = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(f3)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(j3.state, JobState.completed, reason: j3.message);
    expect(b.asked.length, 2);
    expect(b.asked.last.kind, RequestKind.transfer);
  });

  test('unpaired send declined: PairingException, nobody trusted, '
      'nothing saved', () async {
    b.approve = false;
    final f1 = await randomFile(files, 'x.bin', 5000);
    await expectLater(
      a.engine.sendToNearby(nearbyOf(b), [FileSendSource(f1)]),
      throwsA(isA<PairingException>()),
    );
    expect(a.engine.trustedDevices, isEmpty);
    expect(b.engine.trustedDevices, isEmpty);
    expect(b.inboxNames(), isEmpty);
  });

  test('pre-approval expires: the send then asks normally', () async {
    b.engine.preApprovalTtl = Duration.zero;
    final f1 = await randomFile(files, 'late.bin', 3000);
    final j = await waitDone(
      await a.engine.sendToNearby(nearbyOf(b), [FileSendSource(f1)]),
    );
    expect(j.state, JobState.completed, reason: j.message);
    expect(b.asked.map((r) => r.kind).toList(), [
      RequestKind.pairing,
      RequestKind.transfer,
    ]);
  });

  test('pre-approval covers only the offered files', () async {
    final offered = await randomFile(files, 'offered.bin', 3000);
    final other = await randomFile(files, 'other.bin', 4000);
    final s = await a.engine.beginPairing('127.0.0.1', b.port);
    final dev = await s.confirm(offer: [FileSendSource(offered)]);
    final j = await waitDone(
      await a.engine.send(
        dev,
        [FileSendSource(other)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(j.state, JobState.completed, reason: j.message);
    expect(b.asked.last.kind, RequestKind.transfer, reason: 'must ask');
  });

  test('a file that cannot be read on THIS device says so (not "could not '
      'reach")', () async {
    await a.engine.quickPair('127.0.0.1', b.port);
    final j = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [_FailingSource(1000)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(j.state, JobState.failed);
    expect(j.message, contains('Could not read the file on this device'));
    expect(
      a.engine.diagLog.entries.map((e) => e.kind),
      contains(startsWith('send_read_file_')),
    );
  });

  test('receiver cannot save: sender is told, receiver logs it', () async {
    final c = await Node.create(
      'Carol',
      finalizer: (temp, rel, batch) async =>
          throw const FileSystemException('No space left', '', OSError('', 28)),
    );
    try {
      await a.engine.quickPair('127.0.0.1', c.port);
      final f1 = await randomFile(files, 'f.bin', 2 * 1024 * 1024);
      final dev = a.engine.trustedDevices.single;
      final j = await waitDone(
        await a.engine.send(
          dev,
          [FileSendSource(f1)],
          host: '127.0.0.1',
          port: c.port,
        ),
      );
      expect(j.state, JobState.failed);
      expect(j.message, contains('could not save the file'));
      expect(
        c.engine.diagLog.entries.map((e) => e.kind),
        contains(startsWith('receive_write_')),
      );
    } finally {
      await c.dispose();
    }
  });

  test('0.9.0 root cause #1 (clock skew): a certificate from the future is '
      'reported as a certificate/clock problem', () async {
    final future = await Node.create(
      'Skewed',
      identity: Identity.generate(
        notBefore: DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
    );
    try {
      await future.engine.quickPair('127.0.0.1', b.port);
      final f1 = await randomFile(files, 's.bin', 1000);
      final j = await waitDone(
        await future.engine.send(
          future.engine.trustedDevices.single,
          [FileSendSource(f1)],
          host: '127.0.0.1',
          port: b.port,
        ),
      );
      expect(j.state, JobState.failed);
      expect(j.message, contains('clock'));
      expect(j.message, isNot(contains('Could not reach the other device')));
    } finally {
      await future.dispose();
    }
  });

  test('new identities are valid from 2 days ago (tolerates clock skew)', () {
    final id = Identity.generate();
    final cert = X509Utils.x509CertificateFromPem(id.certPem);
    final nb = cert.tbsCertificate!.validity.notBefore;
    expect(
      nb.isBefore(DateTime.now().toUtc().subtract(const Duration(days: 1))),
      isTrue,
    );
  });

  test('chunkedPlatformRead: reads to the end; errors become '
      'SourceReadException', () async {
    final chunks = [
      [1, 2],
      [3],
    ];
    var i = 0;
    var opened = -1;
    final got = await chunkedPlatformRead(
      openId: () async => 7,
      read: (id) async => i < chunks.length ? chunks[i++] : <int>[],
      onOpened: (id) => opened = id,
    ).expand((c) => c).toList();
    expect(got, [1, 2, 3]);
    expect(opened, 7);
    await expectLater(
      chunkedPlatformRead(
        openId: () async => throw PlatformExceptionLike('no_permission'),
        read: (_) async => null,
        onOpened: (_) {},
      ).toList(),
      throwsA(isA<SourceReadException>()),
    );
  });
}

class PlatformExceptionLike implements Exception {
  PlatformExceptionLike(this.code);
  final String code;
  @override
  String toString() => 'PlatformException($code)';
}
