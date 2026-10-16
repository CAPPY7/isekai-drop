// Tests for the Phase 7 audit fixes #3-#9 (see docs/AUDIT.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/key_migration.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

class FakeSlot implements SecretSlot {
  String? value;
  bool dropWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    if (!dropWrites) value = v;
  }
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

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('isekai_fix'));
  tearDown(() => dir.delete(recursive: true));

  test('#4 connection flood: extra sockets refused at once, limit holds, '
      'real pairing works after', () async {
    final b = await eng(dir, 'b');
    addTearDown(b.stop);
    final flood = <Socket>[];
    final closed = <int>[];
    for (var i = 0; i < 40; i++) {
      final s = await Socket.connect('127.0.0.1', b.listeningPort!);
      flood.add(s);
      final idx = i;
      s.listen((_) {}, onDone: () => closed.add(idx), onError: (_) {});
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(b.debugOpenSessions, lessThanOrEqualTo(kMaxHandshakes));
    expect(
      closed.length,
      greaterThanOrEqualTo(40 - kMaxHandshakes),
      reason: 'sockets over the limit must be closed immediately',
    );
    for (final s in flood) {
      s.destroy();
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final a = await eng(dir, 'a');
    addTearDown(a.stop);
    await (await a.beginPairing('127.0.0.1', b.listeningPort!)).confirm();
    expect(b.trustedDevices, hasLength(1));
  });

  group('#3 fallback identity moves into secure storage', () {
    test('migrated: stored, read back, file wiped and deleted', () async {
      final f = File(p.join(dir.path, 'identity_fallback.json'));
      await f.writeAsString('{"secret":"key"}');
      final slot = FakeSlot();
      expect(await migrateFallbackIdentity(f, slot), MigrationResult.migrated);
      expect(slot.value, '{"secret":"key"}');
      expect(f.existsSync(), isFalse);
    });

    test('read-back fails: file kept', () async {
      final f = File(p.join(dir.path, 'identity_fallback.json'));
      await f.writeAsString('{"secret":"key"}');
      final slot = FakeSlot()..dropWrites = true;
      expect(await migrateFallbackIdentity(f, slot), MigrationResult.failed);
      expect(f.readAsStringSync(), '{"secret":"key"}');
    });

    test('different identity already in secure storage: file kept', () async {
      final f = File(p.join(dir.path, 'identity_fallback.json'));
      await f.writeAsString('{"secret":"A"}');
      final slot = FakeSlot()..value = '{"secret":"B"}';
      expect(await migrateFallbackIdentity(f, slot), MigrationResult.conflict);
      expect(f.existsSync(), isTrue);
      expect(slot.value, '{"secret":"B"}');
    });
  });
}
