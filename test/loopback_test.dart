// Real loopback tests: two engines on this computer talk over localhost
// using real TLS sockets. Nothing is mocked except the approval buttons.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

class Node {
  Node._(this.engine, this.root, this.inbox);
  final IsekaiEngine engine;
  final Directory root;
  final Directory inbox;
  final List<PendingRequest> asked = [];
  bool approve = true;

  static Future<Node> create(
    String name, {
    Identity? identity,
    ReceiveFinalizer? finalizer,
    Future<String> Function(File f)? fileDigest,
    bool useLanes = true,
  }) async {
    final root = await Directory.systemTemp.createTemp('isekai_$name');
    final inbox = Directory(p.join(root.path, 'inbox'));
    final store = TrustStore(File(p.join(root.path, 'trusted.json')));
    await store.load();
    late Node node;
    final e = IsekaiEngine(
      identity: identity ?? Identity.generate(),
      trust: store,
      deviceName: () => name,
      platformName: 'linux',
      tempDir: inbox,
      finalizer: finalizer ?? directoryFinalizer(inbox),
      fileDigest: fileDigest,
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      enableDiscovery: false,
      useLanes: useLanes,
    );
    node = Node._(e, root, inbox);
    e.debugAutoDecide = (r) async {
      node.asked.add(r);
      return node.approve;
    };
    await e.start();
    return node;
  }

  int get port => engine.listeningPort!;

  Future<void> dispose() async {
    await engine.stop();
    // Windows/CI: a file handle can close a moment after stop().
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

  List<String> inboxNames() => inbox.existsSync()
      ? inbox.listSync().map((f) => p.basename(f.path)).toList()
      : <String>[];
}

Future<void> pair(Node a, Node b) async {
  final session = await a.engine.beginPairing('127.0.0.1', b.port);
  await session.confirm();
}

Future<TransferJob> waitDone(TransferJob job) async {
  while (job.isActive) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return job;
}

Future<File> randomFile(Directory dir, String name, int size) async {
  final f = File(p.join(dir.path, name));
  final r = Random(42);
  final sink = f.openWrite();
  var left = size;
  while (left > 0) {
    final n = min(left, 1 << 20);
    final buf = Uint8List(n);
    for (var i = 0; i < n; i += 4) {
      final v = r.nextInt(1 << 32);
      for (var k = 0; k < 4 && i + k < n; k++) {
        buf[i + k] = (v >> (8 * k)) & 0xFF;
      }
    }
    sink.add(buf);
    left -= n;
  }
  await sink.close();
  return f;
}

Future<String> hashOf(File f) async =>
    (await sha256.bind(f.openRead()).first).toString();

void main() {
  late Node a;
  late Node b;
  setUp(() async {
    a = await Node.create('Alice');
    b = await Node.create('Bob');
  });
  tearDown(() async {
    await a.dispose();
    await b.dispose();
  });

  test(
    'pairing: both sides see the same code and both trust each other',
    () async {
      final session = await a.engine.beginPairing('127.0.0.1', b.port);
      await session.confirm();
      expect(b.asked.single.kind, RequestKind.pairing);
      expect(b.asked.single.code, session.code);
      expect(
        a.engine.trustedDevices.single.fingerprint,
        b.engine.myFingerprint,
      );
      expect(
        b.engine.trustedDevices.single.fingerprint,
        a.engine.myFingerprint,
      );
    },
  );

  test('pairing declined: nobody is trusted', () async {
    b.approve = false;
    final session = await a.engine.beginPairing('127.0.0.1', b.port);
    await expectLater(session.confirm(), throwsA(isA<PairingException>()));
    expect(a.engine.trustedDevices, isEmpty);
    expect(b.engine.trustedDevices, isEmpty);
  });

  test(
    'transfer: file arrives identical, verified, no temp files left',
    () async {
      await pair(a, b);
      final src = await randomFile(a.root, 'photo.jpg', 5 * 1024 * 1024 + 123);
      final watch = Stopwatch()..start();
      final job = await waitDone(
        await a.engine.send(
          a.engine.trustedDevices.single,
          [FileSendSource(src)],
          host: '127.0.0.1',
          port: b.port,
        ),
      );
      expect(job.state, JobState.completed, reason: job.message);
      expect(b.asked.last.kind, RequestKind.transfer);
      expect(b.inboxNames(), ['photo.jpg']);
      expect(
        await hashOf(File(p.join(b.inbox.path, 'photo.jpg'))),
        await hashOf(src),
      );
      // The app shows no speed for transfers under 300 ms (too short to
      // measure). On a fast machine 5 MiB can finish that quickly.
      if (watch.elapsedMilliseconds >= 1000) {
        expect(job.averageSpeed, isNotNull);
      } else if (job.averageSpeed != null) {
        expect(job.averageSpeed, greaterThan(0));
      }
    },
  );

  test('tampered chunk is rejected and nothing is kept', () async {
    await pair(a, b);
    final src = await randomFile(a.root, 'doc.pdf', 300000);
    var flipped = false;
    a.engine.debugTamper = (chunk) {
      if (flipped) return chunk;
      flipped = true;
      final copy = List<int>.from(chunk);
      copy[10] ^= 0xFF;
      return copy;
    };
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(src)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.failed);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(b.inboxNames(), isEmpty, reason: 'no final file and no .part file');
    expect(b.engine.jobs.single.state, JobState.failed);
  });

  test('unknown (unpaired) device is rejected and never asked about', () async {
    // Alice fakes a trust entry for Bob locally, but Bob never paired Alice.
    await a.engine.trust.addTrusted(
      deviceId: 'bob',
      name: 'Bob',
      platform: 'linux',
      certPem: (b.engine.identity).certPem,
    );
    final src = await randomFile(a.root, 'x.bin', 1000);
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(src)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.failed);
    expect(b.asked, isEmpty);
    expect(b.inboxNames(), isEmpty);
  });

  test('revoked device can no longer connect', () async {
    await pair(a, b);
    await b.engine.revokeTrustedDevice(b.engine.trustedDevices.single.id);
    final src = await randomFile(a.root, 'x.bin', 1000);
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(src)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.failed);
    expect(b.asked.where((r) => r.kind == RequestKind.transfer), isEmpty);
  });

  test('declined transfer writes nothing', () async {
    await pair(a, b);
    b.approve = false;
    final src = await randomFile(a.root, 'x.bin', 1000);
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(src)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.failed);
    expect(job.message, contains('declined'));
    expect(b.inboxNames(), isEmpty);
  });

  test('path traversal name is saved safely inside the inbox', () async {
    await pair(a, b);
    final src = await randomFile(a.root, 'evil.txt', 100);
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(src, name: '../../../evil.txt')],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.completed, reason: job.message);
    expect(b.inboxNames(), ['evil.txt']);
    expect(File(p.join(b.root.path, 'evil.txt')).existsSync(), isFalse);
  });

  test('identity change is detected and blocks until paired again', () async {
    await pair(a, b);
    final port = b.port;
    await b.engine.stop();
    // "Bob" comes back with a different key on the same port.
    final impostor = await Node.create('Bob2');
    addTearDown(impostor.dispose);
    await impostor.engine.stop();
    final fake = IsekaiEngine(
      identity: Identity.generate(deviceId: b.engine.identity.deviceId),
      trust: impostor.engine.trust,
      deviceName: () => 'Bob',
      platformName: 'linux',
      tempDir: impostor.inbox,
      finalizer: directoryFinalizer(impostor.inbox),
      port: port,
      bindAddress: InternetAddress.loopbackIPv4,
      enableDiscovery: false,
    );
    await fake.start();
    addTearDown(fake.stop);
    final src = await randomFile(a.root, 'x.bin', 1000);
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(src)],
        host: '127.0.0.1',
        port: port,
      ),
    );
    expect(job.state, JobState.failed);
    expect(job.message, contains('identity changed'));
    expect(a.engine.trustedDevices.single.status, TrustStatus.identityChanged);
    // Blocked: further sends fail immediately.
    final again = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(src)],
        host: '127.0.0.1',
        port: port,
      ),
    );
    expect(again.message, contains('blocked'));
  });

  test('several files in one transfer', () async {
    await pair(a, b);
    final f1 = await randomFile(a.root, 'one.bin', 70000);
    final f2 = await randomFile(a.root, 'two.bin', 0);
    final job = await waitDone(
      await a.engine.send(
        a.engine.trustedDevices.single,
        [FileSendSource(f1), FileSendSource(f2)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.completed, reason: job.message);
    expect(b.inboxNames()..sort(), ['one.bin', 'two.bin']);
  });
}
