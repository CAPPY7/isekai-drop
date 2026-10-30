// 0.10.1: file data over the background "data lane", and every fallback to
// the main connection. Real TLS over loopback.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:path/path.dart' as p;

import 'loopback_test.dart' show Node, pair, waitDone, randomFile, hashOf;

Future<TransferJob> sendTo(Node a, Node b, List<File> files) async => waitDone(
  await a.engine.send(
    a.engine.trustedDevices.single,
    [for (final f in files) FileSendSource(f)],
    host: '127.0.0.1',
    port: b.port,
  ),
);

Future<void> expectSame(Node b, File src) async {
  expect(
    await hashOf(File(p.join(b.inbox.path, p.basename(src.path)))),
    await hashOf(src),
  );
}

void main() {
  final nodes = <Node>[];
  Future<(Node, Node)> two({
    bool lanesA = true,
    bool lanesB = true,
    Future<String> Function(File f)? digestB,
  }) async {
    final a = await Node.create('LaneA', useLanes: lanesA);
    final b = await Node.create('LaneB', useLanes: lanesB, fileDigest: digestB);
    nodes.addAll([a, b]);
    await pair(a, b);
    return (a, b);
  }

  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
    nodes.clear();
  });

  test('both new: files go over the lane and are verified', () async {
    final (a, b) = await two();
    final f1 = await randomFile(a.root, 'one.bin', 5 * 1024 * 1024 + 7);
    final f0 = File(p.join(a.root.path, 'empty.txt'))..writeAsBytesSync([]);
    final f2 = await randomFile(a.root, 'two.bin', 1000);
    final job = await sendTo(a, b, [f1, f0, f2]);
    expect(job.state, JobState.completed, reason: job.message);
    expect(a.engine.lastDataPath, 'lane');
    expect(b.engine.lastDataPath, 'lane');
    await expectSame(b, f1);
    await expectSame(b, f0);
    await expectSame(b, f2);
    expect(b.engine.jobs.single.bytesDone, f1.lengthSync() + 1000);
  });

  test('lane with a receiver that hashes at the end (Android way)', () async {
    final (a, b) = await two(
      digestB: (f) async => (await sha256.bind(f.openRead()).first).toString(),
    );
    final f = await randomFile(a.root, 'n.bin', 3 * 1024 * 1024);
    final job = await sendTo(a, b, [f]);
    expect(job.state, JobState.completed, reason: job.message);
    expect(b.engine.lastDataPath, 'lane');
    await expectSame(b, f);
  });

  test('tampered data over the lane is rejected, nothing kept', () async {
    final (a, b) = await two();
    final f = await randomFile(a.root, 't.bin', 2 * 1024 * 1024);
    var flipped = false;
    a.engine.debugTamper = (c) {
      if (flipped) return c;
      flipped = true;
      final copy = List<int>.from(c);
      copy[3] ^= 0xFF;
      return copy;
    };
    final job = await sendTo(a, b, [f]);
    expect(job.state, JobState.failed);
    expect(b.engine.lastDataPath, 'lane');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(b.inboxNames(), isEmpty);
  });

  for (final (name, la, lb) in [
    ('old sender (no lanes)', false, true),
    ('old receiver (no lanes)', true, false),
  ]) {
    test('$name: main connection, verified', () async {
      final (a, b) = await two(lanesA: la, lanesB: lb);
      final f = await randomFile(a.root, 'x.bin', 3 * 1024 * 1024 + 1);
      final job = await sendTo(a, b, [f]);
      expect(job.state, JobState.completed, reason: job.message);
      expect(a.engine.lastDataPath, 'in-band');
      expect(b.engine.lastDataPath, 'in-band');
      await expectSame(b, f);
    });
  }

  test('lane cannot start on the receiver: falls back', () async {
    final (a, b) = await two();
    b.engine.debugFailLaneStart = true;
    final f = await randomFile(a.root, 's.bin', 2 * 1024 * 1024);
    final job = await sendTo(a, b, [f]);
    expect(job.state, JobState.completed, reason: job.message);
    expect(b.engine.lastDataPath, 'in-band');
    await expectSame(b, f);
  });

  test('lane connect fails on the sender: falls back', () async {
    final (a, b) = await two();
    a.engine.debugFailLaneConnect = true;
    final f = await randomFile(a.root, 'c.bin', 2 * 1024 * 1024);
    final job = await sendTo(a, b, [f]);
    expect(job.state, JobState.completed, reason: job.message);
    expect(a.engine.lastDataPath, 'in-band');
    expect(b.engine.lastDataPath, 'in-band');
    await expectSame(b, f);
  });

  for (final who in ['sender', 'receiver']) {
    test('$who cancels during a lane transfer: both stop, no file', () async {
      final (a, b) = await two();
      final f = await randomFile(a.root, 'big.bin', 64 * 1024 * 1024);
      final sending = await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(f)],
        host: '127.0.0.1',
        port: b.port,
      );
      while (b.engine.jobs.isEmpty || b.engine.jobs.single.bytesDone == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final rx = b.engine.jobs.single;
      (who == 'sender' ? sending : rx).cancel();
      await waitDone(sending);
      await waitDone(rx);
      expect(sending.state, isNot(JobState.completed));
      expect(rx.state, isNot(JobState.completed));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(b.inboxNames(), isEmpty);
    });
  }

  test('receiver pause and resume over the lane', () async {
    final (a, b) = await two();
    final f = await randomFile(a.root, 'pz.bin', 32 * 1024 * 1024);
    final sending = await a.engine.send(
      a.engine.trustedDevices.single,
      [FileSendSource(f)],
      host: '127.0.0.1',
      port: b.port,
    );
    while (b.engine.jobs.isEmpty || b.engine.jobs.single.bytesDone == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final rx = b.engine.jobs.single;
    rx.pause();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final held = rx.bytesDone;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // At most what was already in the pipes arrives while paused.
    expect(rx.bytesDone - held, lessThan(24 * 1024 * 1024));
    rx.resume();
    await waitDone(sending);
    expect(sending.state, JobState.completed, reason: sending.message);
    await expectSame(b, f);
  });
}
