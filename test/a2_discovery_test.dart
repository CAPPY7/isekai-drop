// A2 (0.11.2): discovery input is untrusted - validate and limit it.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/discovery.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/settings/device_name.dart';

import 'loopback_test.dart' show Node;

Map<String, Object?> pkt({
  Object? id = 'abc123',
  Object? fp,
  Object? port = 53317,
  Object? name = 'Phone',
  Object? platform = 'android',
}) => {
  'app': 'isekai-drop',
  'v': 1,
  'device_id': id,
  'fp': fp ?? 'a' * 64,
  'port': port,
  'name': name,
  'platform': platform,
};

Announcement ann(String id, String host, {String? fp}) => Announcement(
  deviceId: id,
  name: 'D $id',
  platform: 'android',
  port: 4000,
  fingerprint: fp ?? 'b' * 64,
  host: host,
  seenAt: DateTime.now(),
);

void main() {
  group('A2 parseAnnouncement', () {
    final now = DateTime(2026);
    Announcement? parse(Map<String, Object?> j) =>
        parseAnnouncement(j, '10.0.0.2', now: now);

    test('a good packet is accepted', () {
      final a = parse(pkt())!;
      expect(a.deviceId, 'abc123');
      expect(a.port, 53317);
      expect(a.host, '10.0.0.2');
    });

    test('bad fp is rejected', () {
      expect(parse(pkt(fp: 'A' * 64)), isNull, reason: 'upper case');
      expect(parse(pkt(fp: 'a' * 63)), isNull);
      expect(parse(pkt(fp: 'g' * 64)), isNull);
      expect(parse(pkt(fp: 5)), isNull);
    });

    test('bad port is rejected', () {
      for (final p in [0, -1, 65536, '80', 1.5, null]) {
        expect(parse(pkt(port: p)), isNull, reason: '$p');
      }
      expect(parse(pkt(port: 1)), isNotNull);
      expect(parse(pkt(port: 65535)), isNotNull);
    });

    test('bad device id is rejected', () {
      for (final id in ['', 'x' * 65, 'a b', 'a/b', '\u202Eab', 7, null]) {
        expect(parse(pkt(id: id)), isNull, reason: '$id');
      }
      expect(parse(pkt(id: 'x' * 64)), isNotNull);
    });

    test('name and platform must be strings', () {
      expect(parse(pkt(name: 5)), isNull);
      expect(parse(pkt(platform: ['x'])), isNull);
    });

    test('bidi and control characters are removed from UDP names; cut by '
        'runes', () {
      final a = parse(pkt(name: 'Evil\u202Egnp.exe\n\x07PC'))!;
      expect(a.name, 'Evilgnp.exePC');
      final emoji = parse(pkt(name: '\u{1F600}' * 50))!;
      expect(emoji.name.runes.length, 40);
      expect(emoji.name, '\u{1F600}' * 40, reason: 'no broken surrogate');
      final pl = parse(pkt(platform: 'and\u202Eroid'))!;
      expect(pl.platform, 'android');
    });
  });

  group('A2 engine limits', () {
    late Node a;
    setUp(() async => a = await Node.create('A'));
    tearDown(() async => a.dispose());

    test('10,000 random announcements: list stays <= 64, notifications '
        'limited', () async {
      var notes = 0;
      a.engine.addListener(() => notes++);
      final r = Random(1);
      for (var i = 0; i < 10000; i++) {
        a.engine.debugFound(
          ann(
            randomHex(8),
            '10.${r.nextInt(250)}.${r.nextInt(250)}.${r.nextInt(250)}',
          ),
        );
      }
      expect(a.engine.nearby.length, lessThanOrEqualTo(kMaxNearby));
      expect(kMaxNearby, 64);
      expect(notes, lessThanOrEqualTo(2), reason: 'batched, max 4 per s');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(notes, lessThanOrEqualTo(3));
      expect(a.engine.diagCounters.discoveryDropped, greaterThan(9000));
    });

    test('max 5 new ids per source address per 10 s', () {
      for (var i = 0; i < 20; i++) {
        a.engine.debugFound(ann('id$i', '10.0.0.9'));
      }
      expect(a.engine.nearby.length, 5);
      a.engine.debugFound(ann('other', '10.0.0.10'));
      expect(a.engine.nearby.length, 6);
      // A device already listed is still updated.
      a.engine.debugFound(ann('id0', '10.0.0.9'));
      expect(a.engine.nearby.length, 6);
    });

    test('a trusted device is still shown when the list is full', () async {
      final b = await Node.create('B');
      addTearDown(b.dispose);
      await a.engine.quickPair('127.0.0.1', b.port);
      for (var i = 0; i < 200; i++) {
        a.engine.debugFound(ann('n$i', '10.1.${i ~/ 4}.1'));
      }
      expect(a.engine.nearby.length, kMaxNearby);
      a.engine.debugFound(
        Announcement(
          deviceId: b.engine.identity.deviceId,
          name: 'B',
          platform: 'linux',
          port: b.port,
          fingerprint: b.engine.myFingerprint,
          host: '127.0.0.1',
          seenAt: DateTime.now(),
        ),
      );
      expect(
        a.engine.nearby.any((n) => n.deviceId == b.engine.identity.deviceId),
        isTrue,
      );
    });

    test('engine drops invalid announcements from any source', () {
      a.engine.debugFound(ann('ok', '10.0.0.1', fp: 'zz'));
      a.engine.debugFound(
        Announcement(
          deviceId: 'bad id',
          name: 'x',
          platform: 'android',
          port: 4000,
          fingerprint: 'c' * 64,
          host: '10.0.0.1',
          seenAt: DateTime.now(),
        ),
      );
      expect(a.engine.nearby, isEmpty);
    });
  });

  test('A2: settings name helper is cleanSystemName (no clash)', () {
    expect(cleanSystemName('  OnePlus 9 '), 'OnePlus 9');
  });

  test('A2: the UDP listener uses parseAnnouncement', () {
    final src = File('lib/engine/core/discovery.dart').readAsStringSync();
    expect(src, contains('parseAnnouncement(j, d.address.address)'));
    expect(src.contains('characters40'), isFalse);
  });
}
