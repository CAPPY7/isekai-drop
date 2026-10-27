// Tests for the 0.8.1 real-device fixes (pairing wait, diagnostics,
// discovery targets, address order, Windows firewall check).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/bonjour.dart';
import 'package:isekaidrop/engine/core/diag_log.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/frames.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/net_info.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/ui/diag_report.dart';
import 'package:path/path.dart' as p;

/// A local port with nothing listening on it.
Future<int> closedPort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

Future<IsekaiEngine> eng(Directory dir, String n) async {
  final t = TrustStore(File(p.join(dir.path, '$n-trust.json')));
  await t.load();
  final inbox = Directory(p.join(dir.path, '$n-in'));
  final e = IsekaiEngine(
    identity: Identity.generate(),
    trust: t,
    deviceName: () => n,
    platformName: 'linux',
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

/// Raw pairing-style TLS client (no client certificate).
Future<SecureSocket> rawTls(int port) =>
    SecureSocket.connect('127.0.0.1', port, onBadCertificate: (_) => true);

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('isekai_net'));
  tearDown(() => dir.delete(recursive: true));

  group('A: pairing waits for the user to compare the code', () {
    test(
      'user takes longer than the first-message limit: still pairs',
      () async {
        final a = await eng(dir, 'a');
        final b = await eng(dir, 'b');
        addTearDown(a.stop);
        addTearDown(b.stop);
        b.firstMessageTimeout = const Duration(seconds: 1);
        final s = await a.beginPairing('127.0.0.1', b.listeningPort!);
        // A person reading the code (longer than the server's 1 s limit).
        await Future<void>.delayed(const Duration(milliseconds: 2500));
        final dev = await s.confirm();
        expect(dev.name, 'b');
        expect(b.trustedDevices, hasLength(1));
        expect(a.trustedDevices, hasLength(1));
      },
    );

    test('silent connection without pair_hello is still dropped quickly '
        '(audit #4 limit kept)', () async {
      final b = await eng(dir, 'b');
      addTearDown(b.stop);
      b.firstMessageTimeout = const Duration(milliseconds: 500);
      final s = await rawTls(b.listeningPort!);
      final done = Completer<void>();
      s.listen((_) {}, onDone: done.complete, onError: (_) => done.complete());
      await done.future.timeout(const Duration(seconds: 5));
      s.destroy();
    });

    test(
      'only one slow pair_hello wait at a time; the second gets busy',
      () async {
        final b = await eng(dir, 'b');
        addTearDown(b.stop);
        final first = await rawTls(b.listeningPort!);
        first.add(jsonFrame({'t': 'pair_hello', 'v': 1}));
        await first.flush();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final second = await rawTls(b.listeningPort!);
        second.add(jsonFrame({'t': 'pair_hello', 'v': 1}));
        await second.flush();
        final reader = FrameReader(second);
        final r = await reader.nextJson(const Duration(seconds: 5));
        expect(r['t'], 'pair_denied');
        expect(r['reason'], 'busy');
        // The waiting hello does not hold a handshake slot.
        expect(b.debugOpenSessions, lessThanOrEqualTo(2));
        await reader.cancel();
        first.destroy();
        second.destroy();
      },
    );
  });

  group('B: Diagnostics problem log and counters', () {
    test('log keeps the newest 20, newest first', () {
      final log = DiagLog();
      for (var i = 0; i < 25; i++) {
        log.add('k$i', 'm$i');
      }
      expect(log.entries, hasLength(20));
      expect(log.entries.first.kind, 'k24');
      expect(log.entries.last.kind, 'k5');
    });

    test('errors are classified without addresses', () {
      expect(
        classifyError(
          const SocketException(
            'x',
            osError: OSError('Connection refused', 111),
          ),
        ),
        'connect_refused',
      );
      expect(
        classifyError(
          const SocketException('x', osError: OSError('No route to host', 113)),
        ),
        'network_unreachable',
      );
      expect(
        classifyError(const SocketException('Connection timed out')),
        'connect_timeout',
      );
      expect(classifyError(TimeoutException('t')), 'timeout');
      expect(
        classifyError(const HandshakeException('h')),
        'tls_handshake_failed',
      );
      expect(explainErrorClass('connect_refused'), contains('refused'));
    });

    test('pairing to a closed port is logged as connect_refused', () async {
      final a = await eng(dir, 'a');
      addTearDown(a.stop);
      final port = await closedPort();
      await expectLater(
        a.beginPairing('127.0.0.1', port),
        throwsA(isA<SocketException>()),
      );
      expect(a.diagLog.entries.first.kind, 'pair_connect_connect_refused');
      expect(a.lastError, contains('refused'));
      expect(a.lastError, isNot(contains('127.0.0.1')));
    });

    test(
      'silent incoming connection is logged as a first-message timeout',
      () async {
        final b = await eng(dir, 'b');
        addTearDown(b.stop);
        b.firstMessageTimeout = const Duration(milliseconds: 300);
        final s = await rawTls(b.listeningPort!);
        final done = Completer<void>();
        s.listen(
          (_) {},
          onDone: done.complete,
          onError: (_) => done.complete(),
        );
        await done.future.timeout(const Duration(seconds: 5));
        s.destroy();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(b.diagCounters.incomingConnections, 1);
        expect(
          b.diagLog.entries.map((e) => e.kind),
          contains('incoming_first_message_timeout'),
        );
      },
    );

    test(
      'plain (non-TLS) connection is counted as refused by secure setup',
      () async {
        final b = await eng(dir, 'b');
        addTearDown(b.stop);
        final s = await Socket.connect('127.0.0.1', b.listeningPort!);
        s.add(List<int>.filled(64, 65));
        await s.flush();
        await s
            .drain<void>()
            .timeout(const Duration(seconds: 5), onTimeout: () {})
            .catchError((_) {});
        s.destroy();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(b.diagCounters.incomingTlsRejected, 1);
        expect(b.diagLog.entries.first.kind, startsWith('incoming_'));
      },
    );

    test('failed send is logged with a class; report has no names, no peer '
        'address, no file names', () async {
      final a = await eng(dir, 'alice-private-name');
      final b = await eng(dir, 'bob-private-name');
      addTearDown(a.stop);
      await (await a.beginPairing('127.0.0.1', b.listeningPort!)).confirm();
      final bPort = b.listeningPort!;
      await b.stop();
      final f = File(p.join(dir.path, 'secret-file-name.bin'))
        ..writeAsBytesSync([1, 2, 3]);
      final j = await a.send(
        a.trustedDevices.single,
        [FileSendSource(f)],
        host: '127.0.0.1',
        port: bPort,
      );
      for (var i = 0; i < 500 && j.isActive; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(j.state, JobState.failed);
      final kinds = a.diagLog.entries.map((e) => e.kind).toList();
      expect(kinds, contains('send_connect_refused'));
      expect(kinds, contains('send_failed'));
      final report = buildDiagReport(a, platform: 'linux');
      expect(report, contains('send_connect_refused'));
      expect(report, contains('App $kAppVersion'));
      for (final secret in [
        'alice-private-name',
        'bob-private-name',
        'secret-file-name',
        '127.0.0.1',
        a.myFingerprint,
      ]) {
        expect(report, isNot(contains(secret)), reason: secret);
      }
    });

    test('Android NSD events are counted; register failure is logged, '
        'resolve failures only counted', () async {
      final a = await eng(dir, 'a');
      addTearDown(a.stop);
      final br = BonjourBridge(a);
      br.onNativeEvent('registered', 0);
      br.onNativeEvent('found', 0);
      br.onNativeEvent('resolved', 0);
      br.onNativeEvent('resolve_failed', 3);
      expect(a.diagLog.entries, isEmpty);
      br.onNativeEvent('register_failed', 0);
      final c = a.diagCounters;
      expect(c.bonjourFound, 1);
      expect(c.bonjourResolved, 1);
      expect(c.bonjourErrors, 2);
      expect(c.bonjourRegistered, isFalse);
      expect(c.bonjourErrorCodes, ['resolve_failed:3', 'register_failed:0']);
      expect(a.diagLog.entries.single.kind, 'bonjour_register_failed');
      final lines = diagCheckLines(a, ownAddresses: ['wlan0 192.168.1.5']);
      expect(lines.first, contains('wlan0 192.168.1.5'));
      expect(lines.join('\n'), contains('register_failed:0'));
    });

    test('multicast lock result is shown when known', () async {
      final a = await eng(dir, 'a');
      addTearDown(a.stop);
      expect(diagCheckLines(a).join(), isNot(contains('multicast lock')));
      a.diagCounters.multicastLock = false;
      expect(diagCheckLines(a).join(), contains('multicast lock: REFUSED'));
    });

    test('app version constant matches pubspec.yaml', () {
      final v = RegExp(
        r'^version:\s*([0-9.]+)\+',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
      expect(kAppVersion, v);
    });
  });

  group('D: which of this device\'s addresses to offer', () {
    LocalNet n(String name, String ip) => LocalNet(name: name, ip: ip);
    List<String> ips(List<LocalNet> l) => [for (final x in l) x.ip];

    test('Android: Wi-Fi first, mobile data and VPN left out', () {
      expect(
        ips(
          rankLocalNets([
            n('rmnet_data0', '10.12.0.4'),
            n('tun0', '10.8.0.2'),
            n('wlan0', '192.168.1.23'),
            n('ccmni1', '10.50.1.1'),
          ]),
        ),
        ['192.168.1.23'],
      );
    });

    test('Android hotspot interfaces are kept', () {
      expect(
        ips(
          rankLocalNets([
            n('rmnet_data1', '100.70.3.2'),
            n('ap0', '192.168.43.1'),
            n('swlan0', '10.236.5.1'),
          ]),
        ),
        ['192.168.43.1', '10.236.5.1'],
      );
    });

    test('Windows: Wi-Fi before Ethernet; WSL/VPN/Tailscale/link-local out, '
        'Mobile hotspot adapter kept', () {
      expect(
        ips(
          rankLocalNets([
            n('vEthernet (WSL)', '172.20.16.1'),
            n('Ethernet 2', '10.0.0.7'),
            n('Tailscale', '100.101.1.2'),
            n('Local Area Connection* 10', '192.168.137.1'),
            n('Wi-Fi', '192.168.1.40'),
            n('Ethernet 3', '169.254.10.2'),
            n('ProtonVPN TUN', '10.2.0.2'),
          ]),
        ),
        ['192.168.1.40', '10.0.0.7', '192.168.137.1'],
      );
    });

    test('nothing useful left: keep what there is (better than nothing)', () {
      expect(ips(rankLocalNets([n('tun0', '10.8.0.2')])), ['10.8.0.2']);
      expect(rankLocalNets([n('lo', '127.0.0.1')]), isEmpty);
    });

    test('duplicates removed, order stable for equal scores', () {
      expect(
        ips(
          rankLocalNets([
            n('eth0', '192.168.5.2'),
            n('eth1', '192.168.6.2'),
            n('eth0', '192.168.5.2'),
          ]),
        ),
        ['192.168.5.2', '192.168.6.2'],
      );
    });

    test('subnet broadcast: exact with prefix, /24 guess for private only', () {
      expect(subnetBroadcast('192.168.1.23', 24), '192.168.1.255');
      expect(subnetBroadcast('10.236.5.1', 20), '10.236.15.255');
      expect(subnetBroadcast('172.16.3.4', 16), '172.16.255.255');
      expect(subnetBroadcast('1.2.3.4', 0), isNull);
      expect(
        const LocalNet(name: 'wlan0', ip: '10.0.0.9', prefix: 8).broadcast,
        '10.255.255.255',
      );
      expect(n('wlan0', '192.168.43.7').broadcast, '192.168.43.255');
      expect(n('eth0', '8.8.4.4').broadcast, isNull);
    });

    test(
      'engine.localAddresses uses the ranking and native list when set',
      () async {
        final a = await eng(dir, 'a');
        addTearDown(a.stop);
        a.nativeNets = () async => [
          n('rmnet_data0', '10.1.1.1'),
          n('wlan0', '192.168.0.9'),
        ];
        expect(await a.localAddresses(), ['192.168.0.9']);
        a.nativeNets = () async => throw StateError('no');
        // Falls back to Dart's list: never contains loopback.
        expect(await a.localAddresses(), isNot(contains('127.0.0.1')));
      },
    );
  });
}
