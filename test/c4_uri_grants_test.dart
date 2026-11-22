// C4 (0.11.4): Android keeps read access to picked files across a restart
// (persistable URI permission, taken on the Kotlin side when picking) and
// gives it back when the send no longer needs it. The Kotlin side is a
// mocked channel here; real phones are NOT TESTED.
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/android_uri_grants.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/pending_send_store.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

typedef Released = (List<String>, List<String>);

class Box {
  Box(this.root);
  final Directory root;
  late IsekaiEngine engine;
  late PendingSendStore pending;
  final List<(List<Map<String, dynamic>>, List<Map<String, dynamic>>)>
  released = [];

  static Future<Box> create(String name) async {
    final b = Box(await Directory.systemTemp.createTemp('isekai_c4_$name'));
    final trust = TrustStore(File(p.join(b.root.path, 't.json')));
    await trust.load();
    b.pending = PendingSendStore(File(p.join(b.root.path, 'pending.json')));
    final inbox = Directory(p.join(b.root.path, 'in'));
    b.engine = IsekaiEngine(
      identity: Identity.generate(),
      trust: trust,
      deviceName: () => name,
      platformName: 'linux',
      tempDir: inbox,
      finalizer: directoryFinalizer(inbox),
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      enableDiscovery: false,
      useLanes: false,
      pendingSends: b.pending,
      releaseSourceGrants: (rel, keep) async => b.released.add((rel, keep)),
    );
    b.engine.debugAutoDecide = (_) async => true;
    await b.engine.start();
    return b;
  }

  Future<void> dispose() async {
    await engine.stop();
    await pending.idle;
    await root.delete(recursive: true);
  }
}

Future<TransferJob> settle(TransferJob j) async {
  for (var i = 0; i < 3000 && j.isActive; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return j;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('channel', () {
    const ch = MethodChannel('isekai_drop/grants_test');
    final calls = <MethodCall>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async {
            calls.add(c);
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null),
    );

    test('C4: releases only URIs no other saved send still uses', () async {
      final g = AndroidUriGrants(ch);
      await g.release(
        [
          {'k': 'uri', 'uri': 'content://x/1'},
          {'k': 'uri', 'uri': 'content://x/2'},
          {'k': 'file', 'path': '/tmp/a'},
        ],
        [
          {'k': 'uri', 'uri': 'content://x/2'},
        ],
      );
      expect(calls.map((c) => c.method), ['releaseUris']);
      expect(calls.single.arguments, {
        'release': ['content://x/1'],
        'keep': ['content://x/2'],
      });
    });

    test('C4: at start, access no saved send needs is given back', () async {
      final g = AndroidUriGrants(ch);
      await g.releaseAllExcept([
        {'k': 'uri', 'uri': 'content://x/9'},
        {'k': 'file', 'path': '/tmp/a'},
      ]);
      expect(calls.map((c) => c.method), ['releaseUnusedUris']);
      expect(calls.single.arguments, {
        'keep': ['content://x/9'],
      });
    });

    test('C4: nothing to release: no call', () async {
      final g = AndroidUriGrants(ch);
      await g.release([
        {'k': 'file', 'path': '/tmp/a'},
      ], const []);
      expect(calls, isEmpty);
    });
  });

  group('engine', () {
    late Box a;
    late Box b;
    late Directory src;
    setUp(() async {
      a = await Box.create('a');
      b = await Box.create('b');
      src = await Directory.systemTemp.createTemp('isekai_c4_src');
      final s = await a.engine.beginPairing(
        '127.0.0.1',
        b.engine.listeningPort!,
      );
      await s.confirm();
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
      await src.delete(recursive: true);
    });

    Future<File> file(String name, int size) async {
      final r = Random(5);
      final f = File(p.join(src.path, name));
      await f.writeAsBytes(List<int>.generate(size, (_) => r.nextInt(256)));
      return f;
    }

    test('C4: a finished send gives its files back', () async {
      final f = await file('a.bin', 2000);
      final j = await settle(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(j.state, JobState.completed);
      expect(a.released, hasLength(1));
      expect(a.released.single.$1.single['path'], f.path);
    });

    test('C4: a failed send keeps them; removing it gives them back', () async {
      final f = await file('big.bin', 3 * 1024 * 1024);
      a.engine.debugDropAfterBytes = 512 * 1024;
      final j = await settle(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(j.state, JobState.failed);
      expect(a.released, isEmpty, reason: 'kept for Retry after restart');
      expect(a.engine.interruptedSends, hasLength(1));
      await a.engine.removeSaved(a.engine.interruptedSends.single.id);
      expect(a.released, hasLength(1));
      expect(a.released.single.$1.single['path'], f.path);
      expect(a.released.single.$2, isEmpty);
    });
  });
}
