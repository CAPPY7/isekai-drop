// Speed measurement over localhost TLS. Only runs when ISEKAI_BENCH is set:
//   ISEKAI_BENCH=1024 flutter test test/loopback_bench_test.dart
// (value = size in MB). Loopback speed is NOT Wi-Fi speed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:path/path.dart' as p;

import 'loopback_test.dart' show Node, pair, waitDone, randomFile, hashOf;

int _rssKb() {
  try {
    final l = File('/proc/self/status')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('VmRSS'));
    return int.parse(RegExp(r'\d+').firstMatch(l)!.group(0)!);
  } catch (_) {
    return -1;
  }
}

String _vmHwm() {
  try {
    return File('/proc/self/status')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('VmHWM'))
        .replaceAll(RegExp(r'\s+'), ' ');
  } catch (_) {
    return 'VmHWM unknown';
  }
}

void main() {
  final mb = int.tryParse(Platform.environment['ISEKAI_BENCH'] ?? '');
  test(
    'loopback benchmark',
    () async {
      // ISEKAI_BENCH_LANES=0: everything in the main connection (0.10.0 way).
      final lanes = Platform.environment['ISEKAI_BENCH_LANES'] != '0';
      final a = await Node.create('BenchA', useLanes: lanes);
      final b = await Node.create('BenchB', useLanes: lanes);
      try {
        await pair(a, b);
        final src = await randomFile(a.root, 'big.bin', mb! * 1024 * 1024);
        final before = _vmHwm();
        final rssStart = _rssKb();
        var rssMax = rssStart;
        final sampler = Stream.periodic(const Duration(milliseconds: 100))
            .listen((_) {
              final r = _rssKb();
              if (r > rssMax) rssMax = r;
            });
        final sw = Stopwatch()..start();
        final job = await waitDone(
          await a.engine.send(
            a.engine.trustedDevices.single,
            [FileSendSource(src)],
            host: '127.0.0.1',
            port: b.port,
          ),
        );
        sw.stop();
        await sampler.cancel();
        expect(job.state, JobState.completed, reason: job.message);
        final ok =
            await hashOf(File(p.join(b.inbox.path, 'big.bin'))) ==
            await hashOf(src);
        final mbps =
            job.totalBytes / (1024 * 1024) / (sw.elapsedMilliseconds / 1000);
        // ignore: avoid_print
        print(
          'BENCH lanes=$lanes size=${mb}MB time=${sw.elapsedMilliseconds}ms '
          'speed=${mbps.toStringAsFixed(1)}MB/s hashMatch=$ok '
          'rssStartKB=$rssStart rssPeakDuringTransferKB=$rssMax '
          'memBefore=[$before] memAfter=[${_vmHwm()}]',
        );
        expect(ok, isTrue);
      } finally {
        await a.dispose();
        await b.dispose();
      }
    },
    skip: mb == null ? 'Set ISEKAI_BENCH=<MB> to run' : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
