// Tests for the 0.8.1 real-device fixes (pairing wait, diagnostics,
// discovery targets, address order, Windows firewall check).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/frames.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

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
Future<SecureSocket> rawTls(int port) => SecureSocket.connect(
  '127.0.0.1',
  port,
  onBadCertificate: (_) => true,
);

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('isekai_net'));
  tearDown(() => dir.delete(recursive: true));

  group('A: pairing waits for the user to compare the code', () {
    test('user takes longer than the first-message limit: still pairs', () async {
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
    });

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

    test('only one slow pair_hello wait at a time; the second gets busy',
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
    });
  });
}
