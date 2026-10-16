// Phase 6: trust states, history, settings migrations, retry, auto-receive
// and RESUME (after a network drop and after a simulated process kill).
// Real TLS over loopback; only the approval buttons are automated.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/discovery.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/history_store.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/resume_store.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class N {
  N(this.root, this.identity);
  final Directory root;
  final Identity identity;
  late IsekaiEngine engine;
  late TrustStore trust;
  late HistoryStore history;
  final List<PendingRequest> asked = [];
  bool approve = true;
  bool accepting = true;
  bool auto = false;

  Directory get inbox => Directory(p.join(root.path, 'inbox'));
  Directory get resumeDir => Directory(p.join(inbox.path, '.isekai-resume'));
  int get port => engine.listeningPort!;

  /// Starts (or RE-starts, like after the app was killed) with the same
  /// identity and the same files on disk.
  Future<void> boot({int port = 0}) async {
    trust = TrustStore(File(p.join(root.path, 'trusted.json')));
    await trust.load();
    history = HistoryStore(File(p.join(root.path, 'history.json')));
    await history.load();
    engine = IsekaiEngine(
      identity: identity,
      trust: trust,
      deviceName: () => p.basename(root.path),
      platformName: 'linux',
      tempDir: inbox,
      finalizer: directoryFinalizer(inbox),
      port: port,
      bindAddress: InternetAddress.loopbackIPv4,
      enableDiscovery: false,
      history: history,
      resume: ResumeStore(resumeDir),
      acceptingFiles: () => accepting,
      autoAccept: (_) => auto,
    );
    engine.debugAutoDecide = (r) async {
      asked.add(r);
      return approve;
    };
    await engine.start();
  }

  static Future<N> create(String name) async {
    final n = N(
      await Directory.systemTemp.createTemp('isekai6_$name'),
      Identity.generate(),
    );
    await n.boot();
    return n;
  }

  Future<void> dispose() async {
    await engine.stop();
    await root.delete(recursive: true);
  }

  List<String> received() => inbox.existsSync()
      ? inbox
            .listSync()
            .whereType<File>()
            .map((f) => p.basename(f.path))
            .toList()
      : <String>[];
}

Future<void> pair(N a, N b) async {
  final s = await a.engine.beginPairing('127.0.0.1', b.port);
  await s.confirm();
  a.asked.clear();
  b.asked.clear();
}

Future<TransferJob> done(TransferJob j) async {
  for (var i = 0; i < 3000 && j.isActive; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return j;
}

Future<File> rnd(Directory d, String name, int size, [int seed = 7]) async {
  await d.create(recursive: true);
  final r = Random(seed);
  final f = File(p.join(d.path, name));
  await f.writeAsBytes(List<int>.generate(size, (_) => r.nextInt(256)));
  return f;
}

String sha(File f) => sha256.convert(f.readAsBytesSync()).toString();

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  late N a;
  late N b;
  late Directory src;
  setUp(() async {
    a = await N.create('a');
    b = await N.create('b');
    src = await Directory.systemTemp.createTemp('isekai6_src');
  });
  tearDown(() async {
    await a.dispose();
    await b.dispose();
    await src.delete(recursive: true);
  });

  group('trust states', () {
    test('pairing makes both sides VERIFIED', () async {
      await pair(a, b);
      expect(a.engine.trustedDevices.single.status, TrustStatus.verified);
      expect(b.engine.trustedDevices.single.status, TrustStatus.verified);
      expect(
        a.engine.codeFor(a.engine.trustedDevices.single),
        b.engine.codeFor(b.engine.trustedDevices.single),
        reason: 'both screens show the same code for Check code',
      );
    });

    test('revoked device cannot send; record stays revoked', () async {
      await pair(a, b);
      await b.engine.revokeTrustedDevice(b.engine.trustedDevices.single.id);
      final f = await rnd(src, 'x.bin', 1000);
      final j = await done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(j.state, JobState.failed);
      expect(b.received(), isEmpty);
      expect(b.asked, isEmpty, reason: 'never even asked');
      expect(b.engine.trustedDevices.single.status, TrustStatus.revoked);
    });

    test('identity change blocks until paired again', () async {
      await pair(a, b);
      final port = b.port;
      // B is reinstalled: new key, same address.
      await b.engine.stop();
      // Same device id, new key.
      final b2 = N(
        b.root,
        Identity.fromJson({
          ...Identity.generate().toJson(),
          'device_id': b.identity.deviceId,
        }),
      );
      await b2.boot(port: port);
      expect(b2.port, port, reason: 'same address as before');
      final dev = a.engine.trustedDevices.single;
      final f = await rnd(src, 'y.bin', 1000);
      final j = await done(
        await a.engine.send(
          dev,
          [FileSendSource(f)],
          host: '127.0.0.1',
          port: b2.port,
        ),
      );
      expect(port, isNot(0));
      expect(j.state, JobState.failed);
      expect(j.message, contains('identity changed'));
      expect(
        a.engine.trustedDevices.single.status,
        TrustStatus.identityChanged,
      );
      // Still blocked: sending again fails without connecting.
      final j2 = await done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(j2.state, JobState.failed);
      expect(await a.engine.markDeviceVerified(dev.id), isFalse);
      // Re-pair (user compares the code) = reverified.
      final ps = await b2.engine.beginPairing('127.0.0.1', a.port);
      await ps.confirm();
      expect(
        a.asked.last.keyChanged,
        isTrue,
        reason: 'warned before approving',
      );
      expect(a.engine.trustedDevices, hasLength(1), reason: 'old key replaced');
      expect(a.engine.trustedDevices.single.status, TrustStatus.verified);
      expect(
        a.engine.trustedDevices.single.fingerprint,
        b2.identity.fingerprint,
      );
      final j3 = await done(
        await a.engine.send(
          a.engine.trustedDevices.single,
          [FileSendSource(f)],
          host: '127.0.0.1',
          port: b2.port,
        ),
      );
      expect(j3.state, JobState.completed, reason: j3.message);
      b = b2;
    });

    test('pair request from a known id with a NEW key is flagged', () async {
      await pair(a, b);
      // Same device id, new key (e.g. app data restored, key lost).
      final fake = IsekaiEngine(
        identity: Identity.fromJson({
          ...Identity.generate().toJson(),
          'device_id': b.identity.deviceId,
        }),
        trust: TrustStore(File(p.join(b.root.path, 'fake.json'))),
        deviceName: () => 'b',
        platformName: 'linux',
        tempDir: b.inbox,
        finalizer: directoryFinalizer(b.inbox),
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
        enableDiscovery: false,
      );
      await fake.start();
      a.approve = false;
      final s = await fake.beginPairing('127.0.0.1', a.port);
      await expectLater(s.confirm(), throwsA(isA<PairingException>()));
      expect(a.asked.last.kind, RequestKind.pairing);
      expect(a.asked.last.keyChanged, isTrue);
      expect(
        a.engine.trustedDevices.single.fingerprint,
        b.identity.fingerprint,
        reason: 'declined: old key kept',
      );
      await fake.stop();
    });
  });

  test(
    'spoofed announcement neither blocks nor redirects (audit #1)',
    () async {
      await pair(a, b);
      final real = a.engine.trustedDevices.single;
      // An attacker on the network announces B's id and B's key, but at its
      // own address. It cannot prove the key.
      final attacker = await N.create('evil');
      addTearDown(attacker.dispose);
      a.engine.addAnnouncement(
        Announcement(
          deviceId: real.deviceId,
          name: 'b',
          platform: 'linux',
          port: attacker.port,
          fingerprint: real.fingerprint,
          host: '127.0.0.1',
          seenAt: DateTime.now(),
        ),
      );
      await settle();
      expect(
        a.engine.trustedDevices.single.lastPort,
        b.port,
        reason: 'unauthenticated announcement must not change saved address',
      );
      final f = await rnd(src, 's.bin', 1000);
      final j = await done(
        await a.engine.send(
          real,
          [FileSendSource(f)],
          host: '127.0.0.1',
          port: attacker.port,
        ),
      );
      expect(j.state, JobState.failed);
      expect(j.message, contains('different key'));
      expect(
        a.engine.trustedDevices.single.status,
        TrustStatus.verified,
        reason: 'the real device must NOT be blocked by a spoofer',
      );
      expect(attacker.received(), isEmpty);
      final ok = await done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(ok.state, JobState.completed, reason: ok.message);
    },
  );

  test(
    'a second pairing request while one is open is refused (audit #2)',
    () async {
      final gate = Completer<bool>();
      b.engine.debugAutoDecide = (r) => gate.future;
      final first = await a.engine.beginPairing('127.0.0.1', b.port);
      final firstDone = first.confirm();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final c = await N.create('c');
      addTearDown(c.dispose);
      final second = await c.engine.beginPairing('127.0.0.1', b.port);
      await expectLater(
        second.confirm(),
        throwsA(
          isA<PairingException>().having(
            (e) => e.message,
            'message',
            contains('another pairing request'),
          ),
        ),
      );
      gate.complete(true);
      await firstDone;
      expect(b.engine.trustedDevices, hasLength(1));
    },
  );

  group('receive settings', () {
    test('auto-receive only for VERIFIED devices', () async {
      await pair(a, b);
      b.auto = true;
      final f = await rnd(src, 'v.bin', 2000);
      final dev = a.engine.trustedDevices.single;
      var j = await done(await a.engine.send(dev, [FileSendSource(f)]));
      expect(j.state, JobState.completed);
      expect(b.asked, isEmpty, reason: 'verified + auto: not asked');
      // Make A only "trusted" on B (as if migrated): must be asked.
      final onB = b.engine.trustedDevices.single;
      await b.trust.addTrusted(
        deviceId: onB.deviceId,
        name: onB.name,
        platform: onB.platform,
        certPem: onB.certPem,
        host: onB.lastHost,
        port: onB.lastPort,
        verified: false,
      );
      j = await done(await a.engine.send(dev, [FileSendSource(f)]));
      expect(j.state, JobState.completed);
      expect(b.asked, hasLength(1));
    });

    test('receiving switched off declines with a clear message', () async {
      await pair(a, b);
      b.accepting = false;
      final f = await rnd(src, 'off.bin', 10);
      final j = await done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(j.state, JobState.failed);
      expect(j.message, contains('not accepting'));
      expect(b.asked, isEmpty);
    });
  });

  group('history', () {
    test('records both sides, persists, no contents, names optional', () async {
      await pair(a, b);
      final f = await rnd(src, 'secret-name.bin', 5000);
      await done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      await settle();
      expect(a.history.entries.single.direction, HistoryDirection.sent);
      expect(a.history.entries.single.outcome, HistoryOutcome.completed);
      expect(b.history.entries.single.direction, HistoryDirection.received);
      expect(b.history.entries.single.fileNames, ['secret-name.bin']);
      final raw = await File(p.join(b.root.path, 'history.json'))
          .readAsString();
      final content = await f.readAsBytes();
      expect(raw.contains(base64Encode(content.sublist(0, 30))), isFalse);
      final again = HistoryStore(File(p.join(b.root.path, 'history.json')));
      await again.load();
      expect(again.entries.single.id, b.history.entries.single.id);
      expect(again.entries.single.createdAt, isNotNull);
      await again.forgetFileNames();
      expect(again.entries.single.fileNames, isEmpty);
      await again.clear();
      final third = HistoryStore(File(p.join(b.root.path, 'history.json')));
      await third.load();
      expect(third.entries, isEmpty);
    });

    test('migrates schema 0 (plain list) and skips a damaged entry', () async {
      final f = File(p.join(src.path, 'h.json'));
      await f.writeAsString(
        jsonEncode([
          {'device': 'Old PC', 'files': 3, 'bytes': 99, 'direction': 'sent'},
          {'id': 'x', 'direction': 'nonsense'},
        ]),
      );
      final h = HistoryStore(f);
      await h.load();
      expect(h.entries, hasLength(1));
      expect(h.entries.single.peerName, 'Old PC');
      expect(h.entries.single.fileCount, 3);
      expect(h.entries.single.totalBytes, 99);
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(raw['schema_version'], HistoryStore.schemaVersion);
    });
  });

  group('migrations', () {
    test(
      'trust store schema 1 -> 2 keeps states, nothing becomes verified',
      () async {
        final peer = Identity.generate();
        final peer2 = Identity.generate();
        final f = File(p.join(src.path, 't.json'));
        final now = DateTime.now().toUtc().toIso8601String();
        Map<String, Object?> dev(Identity i, String status) => {
          'id': randomHex(16),
          'device_id': i.deviceId,
          'name': 'n',
          'platform': 'android',
          'fingerprint': i.fingerprint,
          'cert_pem': i.certPem,
          'status': status,
          'created_at': now,
          'updated_at': now,
        };
        await f.writeAsString(
          jsonEncode({
            'schema_version': 1,
            'devices': [dev(peer, 'trusted'), dev(peer2, 'identityChanged')],
          }),
        );
        final s = TrustStore(f);
        await s.load();
        expect(s.byDeviceId(peer.deviceId)!.status, TrustStatus.trusted);
        expect(
          s.byDeviceId(peer2.deviceId)!.status,
          TrustStatus.identityChanged,
        );
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        expect(raw['schema_version'], 2);
      },
    );

    test(
      'settings schema 0 and 1 -> 2: auto-receive OFF, old values kept',
      () async {
        SharedPreferences.setMockInitialValues({});
        var prefs = await SharedPreferences.getInstance();
        await SettingsController.migrate(prefs);
        var c = SettingsController(prefs);
        expect(prefs.getInt('settings_schema_version'), 2);
        expect(c.autoReceiveVerified, isFalse);
        expect(c.acceptFiles, isTrue);
        expect(c.visibleOnNetwork, isTrue);

        SharedPreferences.setMockInitialValues({
          'settings_schema_version': 1,
          'theme_mode': 'light',
          'device_name': 'Kazuto PC',
        });
        prefs = await SharedPreferences.getInstance();
        await SettingsController.migrate(prefs);
        c = SettingsController(prefs);
        expect(c.deviceName, 'Kazuto PC');
        expect(c.themeMode.name, 'light');
        expect(c.autoReceiveVerified, isFalse);
        expect(prefs.getInt('settings_schema_version'), 2);
      },
    );
  });

  group('resume', () {
    test('after a network drop: Retry continues, whole file re-hashed', () async {
      await pair(a, b);
      final f = await rnd(src, 'big.bin', 3 * 1024 * 1024 + 123);
      a.engine.debugDropAfterBytes = 1024 * 1024;
      final first = await done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(first.state, JobState.failed);
      await settle();
      expect(b.received(), isEmpty, reason: 'nothing unverified is saved');
      final parts = b.resumeDir.listSync().whereType<File>().toList();
      expect(parts.where((x) => x.path.endsWith('.part')), hasLength(1));
      a.engine.debugDropAfterBytes = null;
      expect(first.canRetry, isTrue);
      final second = await done((await a.engine.retry(first))!);
      expect(second.state, JobState.completed, reason: second.message);
      expect(first.canRetry, isFalse, reason: 'retried once');
      expect(second.resumedBytes, greaterThan(0));
      expect(second.resumedBytes, lessThan(f.lengthSync()));
      expect(b.received(), ['big.bin']);
      expect(sha(File(p.join(b.inbox.path, 'big.bin'))), sha(f));
      await settle();
      expect(
        b.resumeDir.listSync(),
        isEmpty,
        reason: 'state removed after success',
      );
      expect(a.history.entries.map((e) => e.outcome), [
        HistoryOutcome.completed,
        HistoryOutcome.failed,
      ]);
      // ignore: avoid_print
      print(
        'MEASURED resume: ${second.resumedBytes} of ${f.lengthSync()} bytes were not sent again',
      );
    });

    test(
      'after the receiver app is killed and restarted (state on disk)',
      () async {
        await pair(a, b);
        final files = [
          await rnd(src, 'one.bin', 600 * 1024, 1),
          await rnd(src, 'two.bin', 2 * 1024 * 1024, 2),
          await rnd(src, 'three.bin', 300 * 1024, 3),
        ];
        final sources = [for (final f in files) FileSendSource(f)];
        a.engine.debugDropAfterBytes = 1200 * 1024; // inside file two
        final first = await done(
          await a.engine.send(a.engine.trustedDevices.single, sources),
        );
        expect(first.state, JobState.failed);
        await settle();
        expect(b.received(), ['one.bin']);
        // "Kill" B: stop the engine, drop every object, boot again from disk.
        await b.engine.stop();
        await b.boot();
        a.engine.debugDropAfterBytes = null;
        // Sender also restarted: the same selection gives the same transfer id.
        final again = await done(
          await a.engine.send(
            a.engine.trustedDevices.single,
            [for (final f in files) FileSendSource(f)],
            host: '127.0.0.1',
            port: b.port,
          ),
        );
        expect(again.state, JobState.completed, reason: again.message);
        expect(again.resumedBytes, greaterThan(600 * 1024));
        expect(b.received()..sort(), ['one.bin', 'three.bin', 'two.bin']);
        for (final f in files) {
          expect(sha(File(p.join(b.inbox.path, p.basename(f.path)))), sha(f));
        }
        expect(b.asked.last.resumeBytes, again.resumedBytes);
      },
    );

    test(
      'damaged partial data is caught by the full hash, then sent fresh',
      () async {
        await pair(a, b);
        final f = await rnd(src, 'c.bin', 2 * 1024 * 1024);
        a.engine.debugDropAfterBytes = 512 * 1024;
        final first = await done(
          await a.engine.send(a.engine.trustedDevices.single, [
            FileSendSource(f),
          ]),
        );
        expect(first.state, JobState.failed);
        await settle();
        final part = b.resumeDir.listSync().whereType<File>().firstWhere(
          (x) => x.path.endsWith('.part'),
        );
        final raf = part.openSync(mode: FileMode.append)..setPositionSync(10);
        raf.writeByteSync(0xAA ^ part.readAsBytesSync()[10]);
        raf.closeSync();
        a.engine.debugDropAfterBytes = null;
        final second = await done((await a.engine.retry(first))!);
        expect(second.state, JobState.failed);
        expect(second.message, contains('integrity'));
        expect(b.received(), isEmpty);
        await settle();
        final third = await done((await a.engine.retry(second))!);
        expect(third.state, JobState.completed);
        expect(third.resumedBytes, 0);
        expect(sha(File(p.join(b.inbox.path, 'c.bin'))), sha(f));
      },
    );

    test(
      'a different sender cannot use another sender\'s partial state',
      () async {
        final store = ResumeStore(Directory(p.join(src.path, 'r')));
        final s = await store.create('fpA', 'a' * 32, [('x', 10)]);
        expect(await store.load('fpB', 'a' * 32), isNull);
        expect((await store.load('fpA', 'a' * 32))!.key, s.key);
      },
    );

    test('cancel discards partial state', () async {
      await pair(a, b);
      final f = await rnd(src, 'k.bin', 2 * 1024 * 1024);
      a.engine.debugDropAfterBytes = 512 * 1024;
      final first = await done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(first.state, JobState.failed);
      a.engine.debugDropAfterBytes = null;
      b.approve = true;
      final j = await a.engine.retry(first);
      // Cancel right away from the receiver side once it runs.
      for (
        var i = 0;
        i < 300 && b.engine.jobs.where((x) => x.isActive).isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final r = b.engine.jobs.firstWhere(
        (x) => x.isActive,
        orElse: () => b.engine.jobs.first,
      );
      r.cancel();
      await done(j!);
      await settle();
      expect(
        b.resumeDir.existsSync() ? b.resumeDir.listSync() : const [],
        isEmpty,
      );
    });
  });

  test('no file names in logs: the app never prints or logs', () {
    final hits = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final lines = e.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (RegExp(r'\b(print|debugPrint|log)\(|developer\.log|stdout\.')
                .hasMatch(l) ||
            (l.contains('stderr') && !e.path.endsWith('main.dart'))) {
          hits.add('${e.path}:${i + 1}');
        }
      }
    }
    expect(hits, isEmpty);
  });
}
