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
    // 0.10.2: plus the 4-stream rows (no native probe here).
    expect(r2.network.map((s) => s.key), [
      'raw_tcp',
      'raw_tcp_4',
      'tls_lane',
      'tls_lane_4',
      'tls_main',
    ]);
  }, timeout: const Timeout(Duration(seconds: 120)));

  test('0.10.2: 4-stream and native rows, awake hook, interface', () async {
    final awake = <String>[];
    final pa = FakeNativeProbe(), pb = FakeNativeProbe();
    SpeedProbes probes(String who, FakeNativeProbe n) => SpeedProbes(
      awake: (on) async {
        awake.add('$who:$on');
        return on ? 'Wi-Fi lock test' : null;
      },
      native: n,
      linkInfo: () async => {'transport': 'wifi', 'frequencyMhz': 5240},
    );
    final a = await Node.create('SpeedA', speedProbes: probes('a', pa));
    final b = await Node.create('SpeedB', speedProbes: probes('b', pb));
    nodes.addAll([a, b]);
    await pair(a, b);
    final stages = <String>[];
    final r = await a.engine.runSpeedTest(
      a.engine.trustedDevices.single,
      onStage: stages.add,
      bytes: 6 * 1000 * 1000,
      limit: const Duration(seconds: 5),
      host: '127.0.0.1',
      port: b.port,
    );
    expect(
      stages,
      containsAllInOrder([
        'raw_tcp',
        'raw_tcp_4',
        'native_tcp',
        'native_tcp_4',
        'tls_lane',
        'tls_lane_4',
        'tls_main',
      ]),
    );
    final net = {for (final s in r.network) s.key: s};
    for (final k in [
      'raw_tcp',
      'raw_tcp_4',
      'native_tcp',
      'native_tcp_4',
      'tls_lane',
      'tls_lane_4',
    ]) {
      expect(net[k]?.ok, isTrue, reason: '$k ${net[k]?.note}');
      expect(net[k]!.bytes, 6 * 1000 * 1000, reason: k);
    }
    expect(net['raw_tcp_4']!.note, contains('4 streams'));
    expect(net['tls_lane_4']!.note, contains('sender:'));
    expect(pa.sends, 2);
    // Both sides took and released the locks (the receiver just after).
    for (var i = 0; i < 100 && !awake.contains('b:false'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(awake, containsAll(['a:true', 'a:false', 'b:true', 'b:false']));
    expect(r.link['iface'], 'lo');
    expect(r.peerLink['iface'], 'lo');
    expect(r.peerLink['awake'], 'Wi-Fi lock test');
    final text = r.toText();
    expect(text, contains('test connection on lo (loopback)'));
    expect(text, contains('4 streams'));
    expect(text, isNot(contains('127.0.0.1')));
    expect(r.bottleneck, isNotNull);
  });

  test('0.10.2: an older peer skips the new rows with a note', () async {
    final a = await Node.create(
      'SpeedA',
      speedProbes: SpeedProbes(native: FakeNativeProbe()),
    );
    final b = await Node.create('SpeedB');
    b.engine.speedCapsForTest = const [];
    nodes.addAll([a, b]);
    await pair(a, b);
    final r = await a.engine.runSpeedTest(
      a.engine.trustedDevices.single,
      bytes: 2 * 1000 * 1000,
      limit: const Duration(seconds: 3),
      host: '127.0.0.1',
      port: b.port,
    );
    expect(r.network.map((s) => s.key), ['raw_tcp', 'tls_lane', 'tls_main']);
    expect(r.notes.join(' '), contains('older than 0.10.2'));
    expect(r.notes.join(' '), contains('Native TCP rows skipped'));
  });

  test('0.10.2: link warnings and interface kinds', () {
    expect(interfaceKind('p2p-wlan0-0'), 'Wi-Fi Direct');
    expect(interfaceKind('wlan0'), 'Wi-Fi');
    expect(interfaceKind('swlan0'), 'hotspot');
    expect(interfaceKind('ap0'), 'hotspot');
    expect(interfaceKind('rmnet_data0'), 'mobile data');
    expect(interfaceKind('lo'), 'loopback');
    final w = linkWarnings('This device', {
      'transport': 'wifi',
      'frequencyMhz': 5240,
      'directMhz': 5745,
      'iface': 'wlan0',
    }, direct: true);
    expect(w, hasLength(2));
    expect(w.join(), contains('wlan0'));
    expect(w.join(), contains('5240 MHz'));
    expect(
      linkWarnings('x', {
        'transport': 'wifi',
        'frequencyMhz': 5240,
        'directMhz': 5240,
        'iface': 'p2p-wlan0-0',
      }, direct: true),
      isEmpty,
    );
    expect(linkWarnings('x', {'iface': 'wlan0'}, direct: false), isEmpty);
  });

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

/// A stand-in for the Android native probe, same wire format (token, plus
/// one index byte per stream when streams > 1), in plain Dart.
class FakeNativeProbe implements NativeSpeedProbe {
  final _sinks = <int, (ServerSocket, List<int>, Stopwatch, List<Socket>)>{};
  var _next = 1;
  int sends = 0;

  @override
  Future<(int, int)> sinkStart(int streams, String token) async {
    final ss = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final count = [0];
    final sw = Stopwatch();
    final socks = <Socket>[];
    final need = token.length + (streams > 1 ? 1 : 0);
    ss.listen((c) {
      socks.add(c);
      var head = 0;
      c.listen((d) {
        var off = 0;
        if (head < need) {
          off = need - head < d.length ? need - head : d.length;
          head += off;
        }
        if (d.length > off) {
          sw.start();
          count[0] += d.length - off;
        }
      }, onError: (_) {});
    });
    final id = _next++;
    _sinks[id] = (ss, count, sw, socks);
    return (id, ss.port);
  }

  @override
  Future<SpeedSample> sinkEnd(
    int id,
    String key,
    int expect,
    Duration wait,
  ) async {
    final s = _sinks.remove(id)!;
    final until = DateTime.now().add(wait);
    while (s.$2[0] < expect && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await s.$1.close();
    for (final c in s.$4) {
      c.destroy();
    }
    return SpeedSample(
      key,
      s.$2[0],
      s.$3.elapsedMicroseconds + 1,
      note: 'fake receiver',
    );
  }

  @override
  Future<SpeedSample> send(
    String host,
    int port,
    String token,
    int streams,
    int bytes,
    Duration limit,
    String key,
  ) async {
    sends++;
    final socks = [
      for (var i = 0; i < streams; i++) await Socket.connect(host, port),
    ];
    for (var i = 0; i < streams; i++) {
      socks[i].add([...token.codeUnits, if (streams > 1) i]);
    }
    final sw = Stopwatch()..start();
    final chunk = List<int>.filled(1 << 20, 0);
    var sent = 0;
    var i = 0;
    while (sent < bytes) {
      final k = bytes - sent < chunk.length ? bytes - sent : chunk.length;
      socks[i % streams].add(k == chunk.length ? chunk : chunk.sublist(0, k));
      await socks[i % streams].flush();
      sent += k;
      i++;
    }
    for (final c in socks) {
      await c.close();
    }
    return SpeedSample(key, sent, sw.elapsedMicroseconds + 1);
  }
}
