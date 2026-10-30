// 0.10.0 Fast direct: two real engines on this computer (real TLS
// sockets). Only the Wi-Fi part is faked: the "direct link" is a second
// loopback address. Covers route choice, fallbacks and the link lifecycle.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/engine/direct/direct_link.dart';
import 'package:isekaidrop/engine/direct/route_choice.dart';
import 'package:path/path.dart' as p;

/// Linux routes all of 127.0.0.0/8 to loopback; others only 127.0.0.1.
final bool twoLoopbacks = Platform.isLinux;
final String linkIp = twoLoopbacks ? '127.0.0.2' : '127.0.0.1';

class FakeDirect implements DirectLinkPlatform {
  FakeDirect({this.hostIp = '127.0.0.1'});
  String hostIp;
  @override
  bool canHost = true;
  @override
  bool canJoin = true;
  String perm = 'granted';
  DirectLinkException? hostError;
  DirectLinkException? joinError;
  int hosts = 0, stops = 0, joins = 0, leaves = 0;
  final events$ = StreamController<String>.broadcast();

  @override
  Stream<String> get events => events$.stream;
  @override
  Future<String> permissionState() async => perm;
  @override
  Future<String> requestPermission() async => perm;
  @override
  Future<DirectLinkInfo> host({bool preferFiveGhz = true}) async {
    hosts++;
    if (hostError != null) throw hostError!;
    return DirectLinkInfo(
      kind: DirectKind.wifiDirect,
      ssid: 'DIRECT-AB-IsekaiDrop',
      passphrase: 'abcdefgh23',
      hostIp: hostIp,
      frequencyMhz: 5180,
    );
  }

  @override
  Future<void> stopHost() async => stops++;
  @override
  Future<DirectJoin> join(DirectLinkInfo link, {Duration? timeout}) async {
    joins++;
    if (joinError != null) throw joinError!;
    return const DirectJoin(
      localIp: '127.0.0.1',
      frequencyMhz: 5180,
      linkMbps: 1201,
    );
  }

  @override
  Future<void> leave() async => leaves++;
}

class N {
  N(this.engine, this.root, this.inbox, this.fake, this.trust);
  final IsekaiEngine engine;
  final TrustStore trust;
  final Directory root;
  final Directory inbox;
  final FakeDirect? fake;
  int get port => engine.listeningPort!;

  static Future<N> create(
    String name, {
    String platform = 'android',
    FakeDirect? fake,
    bool any = false,
    String Function()? routeMode,
    RouteStats? routeStats,
  }) async {
    final root = await Directory.systemTemp.createTemp('isekai_d_$name');
    final inbox = Directory(p.join(root.path, 'inbox'));
    final store = TrustStore(File(p.join(root.path, 'trusted.json')));
    await store.load();
    final e = IsekaiEngine(
      identity: Identity.generate(),
      trust: store,
      deviceName: () => name,
      platformName: platform,
      tempDir: inbox,
      finalizer: directoryFinalizer(inbox),
      port: 0,
      bindAddress: any ? InternetAddress.anyIPv4 : InternetAddress.loopbackIPv4,
      enableDiscovery: false,
      directLinks: fake,
      directIdle: const Duration(milliseconds: 300),
      directMinBytes: 1024,
      routeMode: routeMode,
      routeStats: routeStats,
    );
    e.debugAutoDecide = (_) async => true;
    await e.start();
    return N(e, root, inbox, fake, store);
  }

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

Future<TransferJob> waitDone(TransferJob job) async {
  while (job.isActive) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return job;
}

Future<File> file(Directory dir, int size) async {
  await dir.create(recursive: true);
  final f = File(p.join(dir.path, 'big.bin'));
  final r = Random(7);
  await f.writeAsBytes(
    Uint8List.fromList(List.generate(size, (_) => r.nextInt(256))),
  );
  return f;
}

Future<void> waitFor(bool Function() ok, {int ms = 3000}) async {
  final until = DateTime.now().add(Duration(milliseconds: ms));
  while (!ok()) {
    if (DateTime.now().isAfter(until)) fail('condition not reached');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late N a; // sender
  late N b; // receiver (Android phone)
  late FakeDirect fa;
  late FakeDirect fb;

  Future<void> setup({
    String bPlatform = 'android',
    bool bDirect = true,
    String Function()? routeMode,
    RouteStats? routeStats,
  }) async {
    fa = FakeDirect();
    fb = FakeDirect(hostIp: linkIp);
    a = await N.create(
      'A',
      fake: fa,
      routeMode: routeMode,
      routeStats: routeStats,
    );
    b = await N.create(
      'B',
      platform: bPlatform,
      fake: bDirect ? fb : null,
      any: twoLoopbacks,
    );
    final s = await a.engine.beginPairing('127.0.0.1', b.port);
    await s.confirm();
  }

  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  Future<TransferJob> sendBig({int size = 300 * 1024}) async {
    final f = await file(Directory(p.join(a.root.path, 'src')), size);
    final job = await a.engine.send(a.engine.trustedDevices.single, [
      FileSendSource(f),
    ]);
    return waitDone(job);
  }

  test('big send to a phone uses the Fast direct link and cleans up', () async {
    await setup();
    final job = await sendBig();
    expect(job.state, JobState.completed, reason: job.message);
    expect(job.route, LinkRoute.wifiDirect);
    expect(job.routeDetail, contains('5 GHz'));
    expect(job.routeDetail, contains('1201 Mbps'));
    expect(fb.hosts, 1);
    expect(fa.joins, 1);
    expect(fa.leaves, 1, reason: 'sender leaves the link after the send');
    final rx = b.engine.jobs.single;
    expect(rx.state, JobState.completed);
    expect(rx.route, LinkRoute.wifiDirect, reason: '${rx.routeLine}');
    // The receiver stops the link once idle.
    await waitFor(() => b.engine.hostedDirectLink == null);
    expect(fb.stops, greaterThanOrEqualTo(1));
    // The direct address is not remembered as the device's address.
    expect(a.engine.trustedDevices.single.lastHost, '127.0.0.1');
  });

  test('receiver without permission: router used, reason shown', () async {
    await setup();
    fb.perm = 'denied';
    final job = await sendBig();
    expect(job.state, JobState.completed, reason: job.message);
    expect(job.route, LinkRoute.router);
    expect(job.routeNote, contains('Nearby devices'));
    expect(fb.hosts, 0);
    expect(fa.joins, 0);
    expect(b.engine.lastDirectProblem, isNotNull);
  });

  test('link cannot be made: router used, half-made link stopped', () async {
    await setup();
    fb.hostError = const DirectLinkException('busy');
    final job = await sendBig();
    expect(job.state, JobState.completed, reason: job.message);
    expect(job.route, LinkRoute.router);
    expect(job.routeNote, contains('could not make a direct link'));
    expect(fb.stops, greaterThanOrEqualTo(1));
    expect(
      a.engine.diagLog.entries.any((e) => e.kind == 'direct_peer_peer_busy'),
      isTrue,
    );
  });

  test(
    'join fails: router used, sender leaves, receiver link idles out',
    () async {
      await setup();
      fa.joinError = const DirectLinkException('timeout');
      final job = await sendBig();
      expect(job.state, JobState.completed, reason: job.message);
      expect(job.route, LinkRoute.router);
      expect(job.routeNote, contains('did not come up in time'));
      expect(fa.leaves, 1);
      await waitFor(() => b.engine.hostedDirectLink == null);
      expect(fb.stops, greaterThanOrEqualTo(1));
    },
  );

  test('link up but other device not reachable on it: router used', () async {
    await setup();
    fb.hostIp = '192.0.2.1'; // TEST-NET: nobody answers
    final job = await sendBig();
    expect(job.state, JobState.completed, reason: job.message);
    expect(job.route, LinkRoute.router);
    expect(job.routeNote, contains('could not reach'));
    expect(fa.leaves, 1);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('small files and non-phones never try Fast direct', () async {
    await setup(bPlatform: 'windows');
    final job = await sendBig();
    expect(job.state, JobState.completed, reason: job.message);
    expect(job.route, LinkRoute.router);
    expect(fb.hosts, 0);
    expect(fa.joins, 0);
  });

  test('older receiver without Fast direct: router used', () async {
    await setup(bDirect: false);
    final job = await sendBig();
    expect(job.state, JobState.completed, reason: job.message);
    expect(job.route, LinkRoute.router);
    expect(job.routeNote, contains('cannot make a direct'));
  });

  test('QR flow: open link, stays on while pinned, idles out after', () async {
    await setup();
    final info = await b.engine.openDirectLink();
    expect(info.ssid, startsWith('DIRECT-'));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(b.engine.hostedDirectLink, isNotNull, reason: 'pinned');
    await b.engine.closeDirectLink();
    await waitFor(() => b.engine.hostedDirectLink == null);
    expect(fb.hosts, 1);
  });

  test(
    'QR join: sends go to the device\'s address on the joined link',
    () async {
      await setup();
      final dev = a.engine.trustedDevices.single;
      // The saved (router) address no longer works.
      await a.trust.rememberAddress(dev.id, '192.0.2.1', b.port);
      a.engine.noteDirectPeer(linkIp, b.port, b.engine.myFingerprint);
      final f = await file(Directory(p.join(a.root.path, 'src')), 4000);
      final sw = Stopwatch()..start();
      final job = await waitDone(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(job.state, JobState.completed, reason: job.message);
      expect(
        sw.elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: 'link address tried before the dead saved one',
      );
      await a.engine.leaveDirectLink(); // forgets the address
    },
  );

  group('0.11.0 Auto (fastest)', () {
    test('first big send: router, reason on the job', () async {
      await setup(routeMode: () => 'auto', routeStats: RouteStats());
      final job = await sendBig();
      expect(job.state, JobState.completed, reason: job.message);
      expect(job.route, LinkRoute.router);
      expect(job.routeNote, contains('Auto: first big send'));
      expect(fa.joins, 0);
      expect(
        a.engine.diagLog.entries.map((e) => e.kind),
        contains('direct_skip_auto_first'),
      );
    });

    test('router measured slow: Fast direct is tried and used', () async {
      final stats = RouteStats();
      await setup(routeMode: () => 'auto', routeStats: stats);
      await stats.record(b.engine.identity.deviceId, 'router', 6e6);
      final job = await sendBig();
      expect(job.state, JobState.completed, reason: job.message);
      expect(job.route, LinkRoute.wifiDirect);
      expect(fa.joins, 1);
    });

    test('router measured fast: stays on the router', () async {
      final stats = RouteStats();
      await setup(routeMode: () => 'auto', routeStats: stats);
      await stats.record(b.engine.identity.deviceId, 'router', 40e6);
      final job = await sendBig();
      expect(job.route, LinkRoute.router);
      expect(job.routeNote, contains('already fast'));
      expect(fa.joins, 0);
    });

    test('"direct" mode ignores the measurements (as 0.10.x)', () async {
      final stats = RouteStats();
      await setup(routeMode: () => 'direct', routeStats: stats);
      await stats.record(b.engine.identity.deviceId, 'router', 40e6);
      final job = await sendBig();
      expect(job.route, LinkRoute.wifiDirect);
    });
  });

  test('engine stop always stops a hosted link', () async {
    await setup();
    await b.engine.openDirectLink();
    await b.engine.stop();
    expect(b.engine.hostedDirectLink, isNull);
    expect(fb.stops, greaterThanOrEqualTo(1));
    await b.engine.start(); // tearDown stops again
  });
}
