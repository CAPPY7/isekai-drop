// 0.9.0: "Search this network" (direct TLS probe), and pairing remembers
// the peer's listening port so "send again" works without discovery.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/net_info.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

class N {
  N(this.engine, this.store, this.root);
  final IsekaiEngine engine;
  final TrustStore store;
  final Directory root;
  bool visible = true;

  static Future<N> create(String name) async {
    final root = await Directory.systemTemp.createTemp('isekai9_$name');
    final inbox = Directory(p.join(root.path, 'inbox'));
    final store = TrustStore(File(p.join(root.path, 'trusted.json')));
    await store.load();
    late N n;
    final e = IsekaiEngine(
      identity: Identity.generate(),
      trust: store,
      deviceName: () => name,
      platformName: 'linux',
      tempDir: inbox,
      finalizer: directoryFinalizer(inbox),
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      enableDiscovery: false,
      visible: () => n.visible,
    );
    n = N(e, store, root);
    e.debugAutoDecide = (_) async => true;
    await e.start();
    return n;
  }

  int get port => engine.listeningPort!;

  Future<void> dispose() async {
    await engine.stop();
    for (var i = 0; ; i++) {
      try {
        await root.delete(recursive: true);
        return;
      } on FileSystemException {
        if (i >= 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}

void main() {
  group('scanTargets', () {
    test('/24 gives 253 hosts without network, broadcast and own IP', () {
      final t = scanTargets(
        const LocalNet(name: 'wlan0', ip: '192.168.1.37', prefix: 24),
      );
      expect(t.length, 253);
      expect(t, isNot(contains('192.168.1.0')));
      expect(t, isNot(contains('192.168.1.255')));
      expect(t, isNot(contains('192.168.1.37')));
      expect(t, contains('192.168.1.1'));
      expect(t, contains('192.168.1.254'));
    });
    test('no prefix defaults to /24; big networks are clamped to /24', () {
      expect(
        scanTargets(const LocalNet(name: 'x', ip: '10.0.0.5')).length,
        253,
      );
      final big = scanTargets(
        const LocalNet(name: 'x', ip: '10.20.30.40', prefix: 8),
      );
      expect(big.length, 253);
      expect(big.every((h) => h.startsWith('10.20.30.')), isTrue);
    });
    test('/30 and public addresses', () {
      expect(
        scanTargets(const LocalNet(name: 'x', ip: '192.168.5.1', prefix: 30)),
        ['192.168.5.2'],
      );
      expect(
        scanTargets(const LocalNet(name: 'x', ip: '8.8.8.8', prefix: 24)),
        isEmpty,
      );
    });
  });

  group('probe (direct search)', () {
    late N a;
    late N b;
    setUp(() async {
      a = await N.create('alpha');
      b = await N.create('bravo');
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    test('finds a visible device with its real identity', () async {
      final found = await a.engine.probe('127.0.0.1', b.port);
      expect(found, isNotNull);
      expect(found!.name, 'bravo');
      expect(found.port, b.port);
      expect(found.fingerprint, b.engine.identity.fingerprint);
    });

    test('says nothing when the device is hidden', () async {
      b.visible = false;
      expect(await a.engine.probe('127.0.0.1', b.port), isNull);
    });

    test('nothing listening -> null quickly', () async {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final freePort = s.port;
      await s.close();
      final sw = Stopwatch()..start();
      expect(await a.engine.probe('127.0.0.1', freePort), isNull);
      expect(sw.elapsed, lessThan(const Duration(seconds: 4)));
    });

    test('pairing still works after a probe and stores the port', () async {
      await a.engine.probe('127.0.0.1', b.port);
      final s = await a.engine.beginPairing('127.0.0.1', b.port);
      await s.confirm();
      // b learned a's listening port from pair_req.
      for (var i = 0; i < 100 && b.store.devices.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final onB = b.store.devices.single;
      expect(onB.fingerprint, a.engine.identity.fingerprint);
      expect(onB.lastPort, a.port);
      expect(a.store.devices.single.lastPort, b.port);
    });

    test('the device that ACCEPTED pairing can send back', () async {
      final s = await a.engine.beginPairing('127.0.0.1', b.port);
      await s.confirm();
      for (var i = 0; i < 100 && b.store.devices.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final src = File(p.join(b.root.path, 'back.txt'))
        ..writeAsStringSync('hello from the responder');
      final job = await b.engine.send(
        b.store.devices.single,
        [FileSendSource(src)],
        host: '127.0.0.1',
        port: a.port,
      );
      while (job.isActive) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(job.state, JobState.completed, reason: job.message);
      expect(
        File(p.join(a.root.path, 'inbox', 'back.txt')).readAsStringSync(),
        'hello from the responder',
      );
    });
  });
}
