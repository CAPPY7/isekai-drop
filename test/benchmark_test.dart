import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/benchmark_store.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/ui/screens/benchmark_screen.dart' show median;
import 'package:path/path.dart' as p;

Future<IsekaiEngine> node(Directory root, String name) async {
  final t = TrustStore(File(p.join(root.path, '$name.json')));
  await t.load();
  final inbox = Directory(p.join(root.path, '$name-in'));
  final e = IsekaiEngine(
    identity: Identity.generate(),
    trust: t,
    deviceName: () => 'Kazuto-$name',
    platformName: name == 'a' ? 'android' : 'windows',
    tempDir: inbox,
    finalizer: directoryFinalizer(inbox),
    port: 0,
    bindAddress: InternetAddress.loopbackIPv4,
    enableDiscovery: false,
  );
  e.debugAutoDecide = (_) async => true;
  await e.start();
  return e;
}

void main() {
  test('median, odd and even', () {
    expect(median([3, 1, 2]), 2);
    expect(median([4, 1, 3, 2]), 2.5);
  });

  test('real transfer -> run: measured numbers only, no names, CSV safe', () async {
    final root = await Directory.systemTemp.createTemp('isekai_bench');
    addTearDown(() => root.delete(recursive: true));
    final a = await node(root, 'a');
    final b = await node(root, 'b');
    addTearDown(a.stop);
    addTearDown(b.stop);
    await (await a.beginPairing('127.0.0.1', b.listeningPort!)).confirm();
    final f = File(p.join(root.path, 'private-holiday-photo.bin'));
    final r = Random(1);
    await f.writeAsBytes(List.generate(3 << 20, (_) => r.nextInt(256)));
    final job = await a.send(a.trustedDevices.single, [FileSendSource(f)]);
    while (job.isActive) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(job.state, JobState.completed);
    expect(benchmarkBlocker(job), isNull);
    final store = BenchmarkStore(File(p.join(root.path, 'bench.json')));
    await store.load();
    await store.add(
      BenchmarkStore.fromJob(
        job,
        thisPlatform: 'android',
        otherPlatform: job.peerPlatform,
        fileSet: 'other',
        connection: 'home Wi-Fi router',
        wifiBand: '5 GHz',
        linkMbps: 866,
        distanceM: 2,
        note: '=HYPERLINK("x"),bad',
      ),
    );
    final run = store.runs.single;
    expect(run.totalBytes, 3 << 20);
    expect(run.durationMs, job.elapsed.inMilliseconds);
    expect(run.receiverPlatform, 'windows');
    expect(
      run.mbPerSecond,
      closeTo(3 / (job.elapsed.inMilliseconds / 1000), 0.01),
    );
    final csv = store.toCsv();
    final saved = await File(p.join(root.path, 'bench.json')).readAsString();
    for (final text in [csv, saved]) {
      expect(text.contains('private-holiday-photo'), isFalse);
      expect(text.contains('Kazuto'), isFalse);
      expect(text.contains('127.0.0.1'), isFalse);
    }
    expect(csv.split('\n').first, BenchmarkRun.csvHeader.join(','));
    expect(
      csv.contains('"\'=HYPERLINK(""x""),bad"'),
      isTrue,
      reason: 'formula escaped and quoted',
    );
    final again = BenchmarkStore(File(p.join(root.path, 'bench.json')));
    await again.load();
    expect(again.runs.single.id, run.id);
    // ignore: avoid_print
    print(
      'MEASURED loopback run: ${run.mbPerSecond.toStringAsFixed(1)} MB/s (3 MiB)',
    );
  });

  test('paused or resumed or failed transfers are refused', () {
    TransferJob j() => TransferJob(
      id: 'x',
      direction: JobDirection.sending,
      peerName: 'p',
      fileCount: 1,
      totalBytes: 10,
    );
    expect(benchmarkBlocker(j()), isNotNull, reason: 'not completed');
    final paused = j()
      ..start()
      ..pause();
    paused.finish(JobState.completed);
    expect(benchmarkBlocker(paused), contains('paused'));
    final resumed = j()
      ..start()
      ..addResumed(5);
    resumed.finish(JobState.completed);
    expect(benchmarkBlocker(resumed), contains('earlier attempt'));
  });
}
