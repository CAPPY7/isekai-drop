import 'dart:convert';
// Tests for the Phase 7 audit fixes #3-#9 (see docs/AUDIT.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:isekaidrop/engine/android_export.dart';
import 'package:isekaidrop/engine/bonjour.dart';
import 'package:crypto/crypto.dart';
import 'package:isekaidrop/engine/core/bg_hasher.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
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

  test(
    '#5 one damaged trust entry: others kept, backup made, warning set',
    () async {
      final f = File(p.join(dir.path, 'trusted_devices.json'));
      final now = DateTime.now().toUtc().toIso8601String();
      Map<String, dynamic> dev(String fp) => {
        'id': fp,
        'device_id': fp,
        'name': fp,
        'fingerprint': fp,
        'cert_pem': 'x',
        'platform': 'linux',
        'status': 'trusted',
        'created_at': now,
        'updated_at': now,
      };
      await f.writeAsString(
        jsonEncode({
          'schema_version': 2,
          'devices': [
            dev('aa'),
            {'name': 7, 'created_at': 'garbage'},
            dev('bb'),
          ],
        }),
      );
      final t = TrustStore(f);
      await t.load();
      expect(t.devices.map((d) => d.fingerprint), ['aa', 'bb']);
      expect(t.loadWarning, isNotNull);
      expect(t.backupFile!.existsSync(), isTrue);
      expect(t.backupFile!.readAsStringSync(), contains('garbage'));
    },
  );

  test('#5 fully unreadable trust file: backup made, warning set', () async {
    final f = File(p.join(dir.path, 'trusted_devices.json'));
    await f.writeAsString('{not json');
    final t = TrustStore(f);
    await t.load();
    expect(t.devices, isEmpty);
    expect(t.loadWarning, isNotNull);
    expect(t.backupFile!.readAsStringSync(), '{not json');
  });

  test(
    '#6 Android: storage permission asked once, before the first save',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const ch = MethodChannel('test/android');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async {
            calls.add(c.method);
            return switch (c.method) {
              'ensureLegacyStorage' => true,
              'folderExists' => false,
              _ => '/storage/emulated/0/Download/Isekai Drop/a.txt',
            };
          });
      final x = AndroidExporter(ch);
      expect(await x.folderExists('f'), isFalse);
      expect(
        await x.export('/tmp/a', 'a.txt', ''),
        contains('Download/Isekai Drop'),
      );
      await x.export('/tmp/b', 'b.txt', '');
      expect(calls, [
        'ensureLegacyStorage',
        'folderExists',
        'exportToDownloads',
        'exportToDownloads',
      ]);
    },
  );

  for (final plat in ['android', 'ios']) {
    test(
      '#8 Visible off on $plat: advertising stops, browsing continues',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final ch = MethodChannel(
          plat == 'android' ? 'isekai_drop/android' : 'isekai_drop/apple',
        );
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ch, (c) async {
              calls.add(c);
              return null;
            });
        BonjourBridge.debugPlatform = plat;
        addTearDown(() => BonjourBridge.debugPlatform = null);
        final e = await eng(dir, 'v$plat');
        addTearDown(e.stop);
        final b = BonjourBridge(e);
        await b.start();
        await b.setVisible(false);
        final starts = calls.where((c) => c.method.endsWith('Start')).toList();
        expect(
          starts,
          hasLength(2),
          reason: 'browsing must be restarted after Visible off',
        );
        expect((starts.last.arguments as Map)['advertise'], isFalse);
        expect((starts.first.arguments as Map)['advertise'], isTrue);
        await b.setVisible(true);
        expect(
          (calls.lastWhere((c) => c.method.endsWith('Start')).arguments
              as Map)['advertise'],
          isTrue,
        );
      },
    );
  }

  test('#10 background hasher gives the same SHA-256 as inline', () async {
    final data = List<int>.generate(3 * 1024 * 1024 + 5, (i) => i * 31 & 255);
    final bg = await BgHasher.start();
    for (var o = 0; o < data.length; o += 65536) {
      bg.add(data.sublist(o, (o + 65536).clamp(0, data.length)));
    }
    expect(await bg.close(), sha256.convert(data).toString());
    expect(await fileHasher(10), isA<InlineHasher>());
    final big = await fileHasher(kBgHashMinBytes);
    expect(big, isA<BgHasher>());
    big.dispose();
  });

  test('#10 transfer with background hashing: file arrives intact', () async {
    debugForceBgHash = true;
    addTearDown(() => debugForceBgHash = null);
    final a = await eng(dir, 'ha');
    final b = await eng(dir, 'hb');
    addTearDown(a.stop);
    addTearDown(b.stop);
    await (await a.beginPairing('127.0.0.1', b.listeningPort!)).confirm();
    final f = File(p.join(dir.path, 'x.bin'))
      ..writeAsBytesSync(List<int>.generate(200000, (i) => i * 7 & 255));
    final j = await a.send(a.trustedDevices.single, [FileSendSource(f)]);
    for (var i = 0; i < 500 && j.isActive; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(j.state, JobState.completed, reason: j.message);
    expect(
      File(p.join(dir.path, 'hb-in', 'x.bin')).readAsBytesSync(),
      f.readAsBytesSync(),
    );
  });

  test('#12 Bonjour/announced names are cleaned', () {
    expect(cleanDeviceName('Evil\u202Egnp.exe\n\x07PC'), 'Evilgnp.exePC');
    expect(cleanDeviceName('  a \t  b  '), 'a b');
    expect(cleanDeviceName('\x00\x01'), 'Device');
    expect(cleanDeviceName('x' * 99).length, 40);
    expect(cleanDeviceName(null), 'Device');
  });

  test('#12 BonjourBridge stores the cleaned name', () async {
    final e = await eng(dir, 'bn');
    addTearDown(e.stop);
    BonjourBridge(e).debugAdd(
      name: 'Bad\u202E\x1bName',
      host: '127.0.0.2',
      port: 5000,
      txt: {'id': 'did1', 'fp': 'ff' * 32, 'pl': 'ios'},
    );
    expect(e.nearby.single.name, 'BadName');
  });

  test('#13 no leftover demo code in lib/', () {
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (RegExp(r'\bDemo[A-Z]\w*|\bisDemo\b|kDemoLabel').hasMatch(src)) {
        hits.add(f.path);
      }
    }
    expect(hits, isEmpty);
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
