// 0.10.1: the in-app Speed test between two paired engines over loopback.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/speed_test.dart';

import 'loopback_test.dart' show Node, pair;

void main() {
  final nodes = <Node>[];
  tearDown(() async {
    for (final n in nodes) {
      await n.dispose();
    }
    nodes.clear();
  });

  test('speed test measures every step on both devices', () async {
    var targetWrites = 0;
    final a = await Node.create('SpeedA');
    final b = await Node.create(
      'SpeedB',
      speedProbes: SpeedProbes(
        writeTarget: (bytes, limit) async {
          targetWrites++;
          return SpeedSample('write_target', bytes, 100000);
        },
        linkInfo: () async => {'linkMbps': 1201, 'frequencyMhz': 5180},
      ),
    );
    nodes.addAll([a, b]);
    await pair(a, b);
    final stages = <String>[];
    final r = await a.engine.runSpeedTest(
      a.engine.trustedDevices.single,
      onStage: stages.add,
      bytes: 8 * 1000 * 1000,
      limit: const Duration(seconds: 5),
      appVersion: 'test',
      host: '127.0.0.1',
      port: b.port,
    );
    expect(
      stages,
      containsAllInOrder([
        'connect',
        'raw_tcp',
        'tls_lane',
        'tls_main',
        'local',
      ]),
    );
    final net = {for (final s in r.network) s.key: s};
    for (final k in ['raw_tcp', 'tls_lane', 'tls_main']) {
      expect(net[k]?.ok, isTrue, reason: '$k ${net[k]?.note}');
      expect(net[k]!.bytes, greaterThanOrEqualTo(8 * 1000 * 1000));
      expect(net[k]!.mbPerSec, greaterThan(0));
    }
    expect(r.local.map((s) => s.key), contains('write_new'));
    expect(r.peerLocal.map((s) => s.key), contains('write_target'));
    expect(targetWrites, 1);
    expect(r.peerLink['linkMbps'], 1201);
    final text = r.toText();
    expect(text, contains('plain TCP'));
    expect(text, isNot(contains('127.0.0.1')));
    // Test files are gone on both sides.
    for (final n in [a, b]) {
      final left = n.inbox.existsSync()
          ? n.inbox.listSync().where((e) => e.path.contains('speed'))
          : const <FileSystemEntity>[];
      expect(left, isEmpty);
    }
    // A second run works (busy flag released).
    final r2 = await a.engine.runSpeedTest(
      a.engine.trustedDevices.single,
      bytes: 2 * 1000 * 1000,
      limit: const Duration(seconds: 3),
      host: '127.0.0.1',
      port: b.port,
    );
    expect(r2.network.length, 3);
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('receiver not accepting files refuses the speed test', () async {
    final a = await Node.create('SpeedC');
    final b = await Node.create('SpeedD', acceptingFiles: () => false);
    nodes.addAll([a, b]);
    await pair(a, b);
    await expectLater(
      a.engine.runSpeedTest(
        a.engine.trustedDevices.single,
        bytes: 1000000,
        host: '127.0.0.1',
        port: b.port,
      ),
      throwsA(
        isA<SpeedTestException>().having(
          (e) => e.code,
          'code',
          'not_accepting',
        ),
      ),
    );
  });
}
