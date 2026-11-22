// C6 (0.11.4): the other device can keep a transfer paused for at most
// 30 minutes in total; then this side stops it (Retry continues).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';

import 'loopback_test.dart' show Node, waitDone, pair, randomFile;

void main() {
  test('C6: the limit is 30 minutes', () {
    expect(kMaxPeerPause, const Duration(minutes: 30));
  });

  test('C6: paused time adds up over several pauses', () async {
    final j = TransferJob(
      id: 'x',
      direction: JobDirection.receiving,
      peerName: 'p',
      fileCount: 1,
      totalBytes: 1,
    )..start();
    j.setPeerPaused(true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    j.setPeerPaused(false);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    j.setPeerPaused(true);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    j.setPeerPaused(false);
    expect(
      j.peerPausedTotal,
      greaterThanOrEqualTo(const Duration(milliseconds: 120)),
    );
    expect(j.peerPausedTotal, lessThan(const Duration(milliseconds: 170)));
    j.peerPauseLimit = const Duration(milliseconds: 100);
    expect(j.peerPauseLeft, Duration.zero);
  });

  test('C6: a sender that stays paused too long: the receiver stops', () async {
    final a = await Node.create('a', useLanes: false);
    final b = await Node.create('b', useLanes: false);
    final dir = await Directory.systemTemp.createTemp('isekai_c6p');
    addTearDown(() async {
      await a.dispose();
      await b.dispose();
      await dir.delete(recursive: true);
    });
    await pair(a, b);
    b.engine.peerPauseLimit = const Duration(milliseconds: 400);
    final f = await randomFile(dir, 'big.bin', 40 * 1024 * 1024);
    final job = await a.engine.send(a.engine.trustedDevices.single, [
      FileSendSource(f),
    ]);
    while (job.bytesDone == 0 && job.isActive) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    job.pause();
    final sw = Stopwatch()..start();
    TransferJob? r;
    while (sw.elapsed < const Duration(seconds: 20)) {
      final rs = b.engine.jobs;
      if (rs.isNotEmpty && !rs.first.isActive) {
        r = rs.first;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(r, isNotNull, reason: 'receiver gave up');
    expect(r!.state, JobState.failed);
    expect(r.message, contains('paused for more than'));
    job.cancel();
    await waitDone(job);
  });
}
