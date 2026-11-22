// A3 (0.11.2): pairing - no single-person block, no prompt spam, block list.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/blocked_store.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/frames.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/trusted_screen.dart';
import 'package:isekaidrop/ui/shell.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'loopback_test.dart' show Node;

/// A pairing client that says hello from [src] and then waits.
Future<(SecureSocket, FrameReader)> hello(int port, String src) async {
  final raw = await Socket.connect(
    InternetAddress.loopbackIPv4,
    port,
    sourceAddress: InternetAddress(src),
  );
  final s = await SecureSocket.secure(raw, onBadCertificate: (_) => true);
  s.add(jsonFrame({'t': 'pair_hello', 'v': kProtocolVersion}));
  await s.flush();
  return (s, FrameReader(s));
}

/// Null if the server keeps waiting (the hello was accepted).
Future<String?> deniedReason(FrameReader r) async {
  try {
    final m = await r.nextJson(const Duration(milliseconds: 600));
    return m['reason'] as String?;
  } on TimeoutException {
    return null;
  } catch (_) {
    return null;
  }
}

void main() {
  test('A3: pair wait constants', () {
    expect(kPairHelloWait, const Duration(seconds: 45));
    expect(kMaxPairHelloWaits, 2);
    expect(kPairCooldown, const Duration(seconds: 60));
  });

  group('A3 pair_hello waits', () {
    late Node a;
    setUp(() async => a = await Node.create('A'));
    tearDown(() async => a.dispose());

    test('default compare wait is kPairHelloWait', () {
      expect(a.engine.pairCompareTimeout, kPairHelloWait);
    });

    test('second hello from another IP still works; same IP twice is '
        'refused; max 2 overall', () async {
      final (s1, r1) = await hello(a.port, '127.0.0.1');
      addTearDown(s1.destroy);
      expect(await deniedReason(r1), isNull);
      final (s2, r2) = await hello(a.port, '127.0.0.1');
      addTearDown(s2.destroy);
      expect(await deniedReason(r2), 'busy', reason: 'same IP twice');
      final (s3, r3) = await hello(a.port, '127.0.0.2');
      addTearDown(s3.destroy);
      expect(await deniedReason(r3), isNull, reason: 'other IP works');
      final (s4, r4) = await hello(a.port, '127.0.0.3');
      addTearDown(s4.destroy);
      expect(await deniedReason(r4), 'busy', reason: 'max 2 at once');
    });
  });

  group('A3 cooldown and block', () {
    late Node a;
    late Node b;
    setUp(() async {
      a = await Node.create('A');
      b = await Node.create('B');
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    test('decline then retry within 60 s gives no dialog (cooldown)', () async {
      a.approve = false;
      await expectLater(
        b.engine.quickPair('127.0.0.1', a.port),
        throwsA(isA<PairingException>()),
      );
      expect(a.asked.length, 1);
      Object? err;
      try {
        await b.engine.quickPair('127.0.0.1', a.port);
      } catch (e) {
        err = e;
      }
      expect(err, isA<PairingException>());
      expect('$err', contains('a minute'));
      expect(a.asked.length, 1, reason: 'no second dialog');
      // After the cooldown the question comes again.
      a.engine.pairCooldown = Duration.zero;
      a.approve = true;
      await b.engine.quickPair('127.0.0.1', a.port);
      expect(a.asked.length, 2);
    });

    test('blocked fingerprint never asks; unblock works', () async {
      a.engine.debugAutoDecide = (r) async {
        a.asked.add(r);
        r.block();
        return false;
      };
      a.engine.pairCooldown = Duration.zero;
      await expectLater(
        b.engine.quickPair('127.0.0.1', a.port),
        throwsA(isA<PairingException>()),
      );
      expect(
        a.engine.blockedDevices.single.fingerprint,
        b.engine.myFingerprint,
      );
      expect(a.engine.blockedDevices.single.name, 'B');
      await expectLater(
        b.engine.quickPair('127.0.0.1', a.port),
        throwsA(isA<PairingException>()),
      );
      expect(a.asked.length, 1, reason: 'blocked: refused before any dialog');
      await a.engine.unblockDevice(b.engine.myFingerprint);
      expect(a.engine.blockedDevices, isEmpty);
      a.engine.debugAutoDecide = (r) async {
        a.asked.add(r);
        return true;
      };
      await b.engine.quickPair('127.0.0.1', a.port);
      expect(a.asked.length, 2);
    });
  });

  test(
    'A3: blocked list file survives restart (schema_version 1, atomic)',
    () async {
      final dir = await Directory.systemTemp.createTemp('isekai_a3');
      addTearDown(() => dir.delete(recursive: true));
      final f = File(p.join(dir.path, 'blocked_devices.json'));
      final s1 = BlockedStore(f);
      await s1.load();
      await s1.block('d' * 64, name: 'Evil', platform: 'android');
      expect(File('${f.path}.tmp').existsSync(), isFalse);
      expect(f.readAsStringSync(), contains('"schema_version":1'));
      final s2 = BlockedStore(f);
      await s2.load();
      expect(s2.isBlocked('d' * 64), isTrue);
      expect(s2.devices.single.name, 'Evil');
      await s2.unblock('d' * 64);
      final s3 = BlockedStore(f);
      await s3.load();
      expect(s3.devices, isEmpty);
      await f.writeAsString('{damaged');
      final s4 = BlockedStore(f);
      await s4.load();
      expect(s4.devices, isEmpty, reason: 'damaged file does not crash');
    },
  );

  group('A3 UI', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('a3ui'));
    tearDown(() async => dir.delete(recursive: true));

    Future<IsekaiEngine> engine() async {
      final trust = TrustStore(File(p.join(dir.path, 't.json')));
      await trust.load();
      final blocked = BlockedStore(File(p.join(dir.path, 'b.json')));
      await blocked.load();
      return IsekaiEngine(
        identity: Identity.generate(),
        trust: trust,
        blocked: blocked,
        deviceName: () => 'Me',
        platformName: 'android',
        tempDir: Directory(p.join(dir.path, 'in')),
        finalizer: directoryFinalizer(Directory(p.join(dir.path, 'in'))),
        enableDiscovery: false,
      );
    }

    testWidgets('Trusted devices shows Blocked with Unblock (asks first)', (
      t,
    ) async {
      final e = (await t.runAsync(engine))!;
      await t.runAsync(
        () => e.blocked.block('e' * 64, name: 'Spammer', platform: 'android'),
      );
      SharedPreferences.setMockInitialValues({});
      final s = (await t.runAsync(SettingsController.load))!;
      await t.pumpWidget(
        AppScope(
          engine: e,
          settings: s,
          child: const MaterialApp(home: TrustedDevicesScreen()),
        ),
      );
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('Spammer'), findsOneWidget);
      await t.tap(find.text('Unblock'));
      await t.pumpAndSettle();
      expect(find.text('Unblock "Spammer"?'), findsOneWidget);
      expect(e.blockedDevices.length, 1, reason: 'asks first');
      await t.tap(find.widgetWithText(FilledButton, 'Unblock'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pumpAndSettle();
      expect(e.blockedDevices, isEmpty);
    });

    testWidgets('Accept dialog has "Block this device"', (t) async {
      final e = (await t.runAsync(engine))!;
      SharedPreferences.setMockInitialValues({});
      final s = (await t.runAsync(SettingsController.load))!;
      await t.pumpWidget(
        AppScope(
          engine: e,
          settings: s,
          child: const MaterialApp(home: AppShell()),
        ),
      );
      final r = PendingRequest(
        id: 'x',
        kind: RequestKind.pairing,
        peerName: 'Stranger',
        peerPlatform: 'android',
        code: '123 456',
      );
      final answer = e.debugAsk(r);
      await t.pumpAndSettle();
      expect(find.text('Block this device'), findsOneWidget);
      final btn = t.getSize(find.byKey(const ValueKey('request-block')));
      expect(btn.height, greaterThanOrEqualTo(48));
      await t.tap(find.text('Block this device'));
      await t.pumpAndSettle();
      expect(await answer, isFalse);
      expect(r.blockRequested, isTrue);
    });
  });
}
