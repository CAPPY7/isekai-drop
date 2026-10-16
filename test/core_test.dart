import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/frames.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/safe_files.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

void main() {
  group('identity and verification code', () {
    test('each install gets a different identity', () {
      final a = Identity.generate();
      final b = Identity.generate();
      expect(a.fingerprint, isNot(b.fingerprint));
      expect(a.deviceId, isNot(b.deviceId));
      expect(a.fingerprint, hasLength(64));
      final again = Identity.fromJson(
        jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
      );
      expect(again.fingerprint, a.fingerprint);
    });

    test('code is the same on both sides and changes with any key', () {
      final a = Identity.generate().fingerprint;
      final b = Identity.generate().fingerprint;
      final c = Identity.generate().fingerprint;
      expect(verificationCode(a, b), verificationCode(b, a));
      expect(verificationCode(a, b), isNot(verificationCode(a, c)));
      expect(
        verificationCode(a, b),
        matches(RegExp(r'^\d{4} \d{4} \d{4} \d{4}$')),
      );
    });
  });

  group('file name and path safety', () {
    test('path traversal and unsafe names are neutralised', () {
      expect(sanitizeFileName('../../etc/passwd'), 'passwd');
      expect(sanitizeFileName(r'..\..\Windows\system.ini'), 'system.ini');
      expect(sanitizeFileName('/abs/path/x.txt'), 'x.txt');
      expect(sanitizeFileName('..'), 'file');
      expect(sanitizeFileName('.hidden'), 'hidden');
      expect(sanitizeFileName('a\u0000b<c>.txt'), 'a_b_c_.txt');
      expect(sanitizeFileName('CON.txt'), '_CON.txt');
      expect(sanitizeFileName('name. . '), 'name');
      expect(sanitizeFileName('x' * 300 + '.jpg').length, 180);
      expect(sanitizeFileName('x' * 300 + '.jpg'), endsWith('.jpg'));
    });

    test('existing files are never overwritten', () async {
      final dir = await Directory.systemTemp.createTemp('isekai_safe');
      addTearDown(() => dir.delete(recursive: true));
      await File(p.join(dir.path, 'a.txt')).writeAsString('original');
      final t1 = await reserveTarget(dir, 'a.txt');
      final t2 = await reserveTarget(dir, 'a.txt');
      expect(p.basename(t1.path), 'a (1).txt');
      expect(p.basename(t2.path), 'a (2).txt');
      expect(await File(p.join(dir.path, 'a.txt')).readAsString(), 'original');
      expect(isInsideDirectory(dir, p.join(dir.path, '..', 'x')), isFalse);
    });
  });

  group('trust store database', () {
    test('saves, reloads, renames, revokes, marks identity changes', () async {
      final dir = await Directory.systemTemp.createTemp('isekai_trust');
      addTearDown(() => dir.delete(recursive: true));
      final f = File(p.join(dir.path, 'trusted.json'));
      final store = TrustStore(f);
      await store.load();
      final peer = Identity.generate();
      final d = await store.addTrusted(
        deviceId: peer.deviceId,
        name: 'Phone',
        platform: 'android',
        certPem: peer.certPem,
      );
      expect(d.fingerprint, peer.fingerprint);
      final again = TrustStore(f);
      await again.load();
      expect(again.byFingerprint(peer.fingerprint)?.name, 'Phone');
      await again.rename(d.id, 'My phone');
      await again.markIdentityChanged(d.id);
      final third = TrustStore(f)..file;
      await third.load();
      expect(third.byId(d.id)!.name, 'My phone');
      expect(third.byId(d.id)!.status, TrustStatus.identityChanged);
      expect(
        third.byId(d.id)!.updatedAt.isBefore(third.byId(d.id)!.createdAt),
        isFalse,
      );
      await third.revoke(d.id);
      final fourth = TrustStore(f);
      await fourth.load();
      expect(fourth.byId(d.id)!.status, TrustStatus.revoked);
      expect(fourth.byId(d.id)!.isTrusted, isFalse);
      expect(
        await fourth.markVerified(d.id),
        isFalse,
        reason: 'blocked devices must pair again',
      );
      await fourth.forget(d.id);
      final fifth = TrustStore(f);
      await fifth.load();
      expect(fifth.devices, isEmpty);
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(raw['schema_version'], TrustStore.schemaVersion);
    });

    test('many saves at the same time do not race (audit #17)', () async {
      final dir = await Directory.systemTemp.createTemp('isekai_race');
      addTearDown(() => dir.delete(recursive: true));
      final f = File(p.join(dir.path, 'trusted.json'));
      final s = TrustStore(f);
      await s.load();
      final peer = Identity.generate();
      final d = await s.addTrusted(
        deviceId: peer.deviceId,
        name: 'P',
        platform: 'android',
        certPem: peer.certPem,
      );
      await Future.wait([
        for (var i = 0; i < 50; i++)
          s.rememberAddress(d.id, '10.0.0.$i', i + 1),
        for (var i = 0; i < 20; i++) s.rename(d.id, 'P$i'),
      ]);
      final again = TrustStore(f);
      await again.load();
      expect(again.byId(d.id)!.name, 'P19');
      expect(again.byId(d.id)!.lastPort, 50);
    });

    test('migrates a version 0 file', () async {
      final dir = await Directory.systemTemp.createTemp('isekai_mig');
      addTearDown(() => dir.delete(recursive: true));
      final peer = Identity.generate();
      final f = File(p.join(dir.path, 'trusted.json'));
      await f.writeAsString(
        jsonEncode({
          'devices': [
            {
              'device_id': peer.deviceId,
              'name': 'Old',
              'platform': 'windows',
              'fingerprint': peer.fingerprint,
              'cert_pem': peer.certPem,
            },
          ],
        }),
      );
      final s = TrustStore(f);
      await s.load();
      expect(s.devices.single.status, TrustStatus.trusted);
      expect(s.devices.single.id, isNotEmpty);
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(raw['schema_version'], 2);
    });
  });

  test('frames round-trip and reject oversized frames', () async {
    final bytes = Uint8List.fromList([
      ...jsonFrame({'t': 'hello'}),
      ...encodeFrame(frameData, List.filled(70000, 7)),
    ]);
    final pieces = <Uint8List>[
      for (var i = 0; i < bytes.length; i += 1000)
        Uint8List.sublistView(bytes, i, (i + 1000).clamp(0, bytes.length)),
    ];
    final r = FrameReader(Stream.fromIterable(pieces));
    expect((await r.nextJson())['t'], 'hello');
    final d = await r.next();
    expect(d.type, frameData);
    expect(d.payload.length, 70000);

    final bad = encodeFrame(frameData, const []);
    bad[1] = 0xFF; // claims about 4 GB
    final r2 = FrameReader(Stream.value(bad));
    await expectLater(r2.next(), throwsFormatException);
  });
}
