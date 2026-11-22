// D3 (0.12.0): "Always allow this device" on the receive question. Only for
// VERIFIED devices; stored per device in trusted_devices.json (schema 3);
// Settings > Trusted devices can turn it off. Real TLS over loopback.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/pick_result.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/trusted_screen.dart';
import 'package:isekaidrop/ui/shell.dart';
import 'package:isekaidrop/ui/ui_env.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'phase6_test.dart' show N, done, pair, rnd;

void main() {
  group('trust file', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('isekai_d3'));
    tearDown(() => dir.delete(recursive: true));

    Map<String, Object?> dev(String status, {bool? allow}) => {
      'id': 'r1',
      'device_id': 'dev1',
      'name': 'Phone',
      'platform': 'android',
      'fingerprint': 'a' * 64,
      'cert_pem': 'x',
      'status': status,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
      'always_allow': ?allow,
    };

    test('D3: schema 2 file still loads; saved as schema 3', () async {
      final f = File(p.join(dir.path, 'trusted.json'))
        ..writeAsStringSync(
          jsonEncode({
            'schema_version': 2,
            'devices': [dev('verified')],
          }),
        );
      final s = TrustStore(f);
      await s.load();
      expect(s.devices.single.isVerified, isTrue);
      expect(s.devices.single.alwaysAllow, isFalse);
      final saved = jsonDecode(f.readAsStringSync()) as Map;
      expect(saved['schema_version'], 3);
      expect((saved['devices'] as List).single['always_allow'], isFalse);
      expect(TrustStore.schemaVersion, 3);
    });

    test('D3: the flag is kept, and only for verified devices', () async {
      final f = File(p.join(dir.path, 'trusted.json'))
        ..writeAsStringSync(
          jsonEncode({
            'schema_version': 3,
            'devices': [dev('trusted', allow: true)],
          }),
        );
      final s = TrustStore(f);
      await s.load();
      expect(
        s.devices.single.alwaysAllow,
        isFalse,
        reason: 'a not-verified device never has it',
      );
      expect(await s.setAlwaysAllow('r1', true), isFalse);
      expect(await s.markVerified('r1'), isTrue);
      expect(await s.setAlwaysAllow('r1', true), isTrue);
      final again = TrustStore(f);
      await again.load();
      expect(again.devices.single.alwaysAllow, isTrue);
      // Leaving "verified" drops it.
      await again.revoke('r1');
      expect(again.devices.single.alwaysAllow, isFalse);
    });
  });

  group('engine', () {
    late N a;
    late N b;
    late Directory src;
    setUp(() async {
      a = await N.create('a');
      b = await N.create('b');
      src = await Directory.systemTemp.createTemp('isekai_d3_src');
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
      await src.delete(recursive: true);
    });

    Future<TransferJob> sendOne(String name) async {
      final f = await rnd(src, name, 2000);
      return done(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
    }

    test(
      'D3: "Always allow" receives without asking; off asks again',
      () async {
        await pair(a, b);
        final id = b.engine.trustedDevices.single.id;
        expect(await b.engine.markDeviceVerified(id), isTrue);
        var tick = true;
        b.engine.debugAutoDecide = (r) async {
          b.asked.add(r);
          r.alwaysAllow = tick;
          return true;
        };
        expect((await sendOne('1.bin')).state, JobState.completed);
        expect(b.asked, hasLength(1));
        expect(b.asked.single.peerVerified, isTrue);
        expect(
          b.asked.single.deviceId,
          b.engine.trustedDevices.single.deviceId,
        );
        expect(b.engine.trustedDevices.single.alwaysAllow, isTrue);

        tick = false;
        expect((await sendOne('2.bin')).state, JobState.completed);
        expect(b.asked, hasLength(1), reason: 'not asked again');
        expect(b.received(), containsAll(['1.bin', '2.bin']));

        expect(await b.engine.setAlwaysAllow(id, false), isTrue);
        expect((await sendOne('3.bin')).state, JobState.completed);
        expect(b.asked, hasLength(2), reason: 'turned off: asks again');
      },
    );

    test('D3: a device that is not verified is always asked', () async {
      await pair(a, b);
      b.engine.debugAutoDecide = (r) async {
        b.asked.add(r);
        r.alwaysAllow = true; // even if the dialog sent it
        return true;
      };
      await sendOne('1.bin');
      expect(b.asked.single.peerVerified, isFalse);
      expect(b.engine.trustedDevices.single.alwaysAllow, isFalse);
      await sendOne('2.bin');
      expect(b.asked, hasLength(2));
    });
  });

  group('UI', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('d3ui'));
    tearDown(() async => dir.delete(recursive: true));

    Future<IsekaiEngine> engine({bool allow = false}) async {
      final f = File(p.join(dir.path, 't.json'));
      if (allow) {
        f.writeAsStringSync(
          jsonEncode({
            'schema_version': 3,
            'devices': [
              {
                'id': 'r1',
                'device_id': 'dev1',
                'name': 'Tablet',
                'platform': 'android',
                'fingerprint': 'a' * 64,
                'cert_pem': 'x',
                'status': 'verified',
                'created_at': '2026-01-01T00:00:00.000Z',
                'updated_at': '2026-01-01T00:00:00.000Z',
                'always_allow': true,
              },
            ],
          }),
        );
      }
      final trust = TrustStore(f);
      await trust.load();
      return IsekaiEngine(
        identity: Identity.generate(),
        trust: trust,
        deviceName: () => 'Me',
        platformName: 'android',
        tempDir: Directory(p.join(dir.path, 'in')),
        finalizer: directoryFinalizer(Directory(p.join(dir.path, 'in'))),
        enableDiscovery: false,
      );
    }

    Future<void> shell(WidgetTester t, IsekaiEngine e) async {
      SharedPreferences.setMockInitialValues({});
      final s = (await t.runAsync(SettingsController.load))!;
      await t.pumpWidget(
        AppScope(
          engine: e,
          settings: s,
          child: UiEnv(
            animations: false,
            readPlatform: false,
            child: MaterialApp(
              home: AppShell(takeShared: () async => PickResult.empty),
            ),
          ),
        ),
      );
    }

    PendingRequest req(bool verified) => PendingRequest(
      id: 'x',
      kind: RequestKind.transfer,
      peerName: 'Tablet',
      peerPlatform: 'android',
      fileNames: const ['a.txt'],
      totalBytes: 3,
      deviceId: 'dev1',
      peerVerified: verified,
    );

    testWidgets('D3: the question offers "Always allow" for verified only', (
      t,
    ) async {
      final e = (await t.runAsync(engine))!;
      await shell(t, e);
      final plain = req(false);
      final a1 = e.debugAsk(plain);
      await t.pumpAndSettle();
      expect(find.text('Always allow this device'), findsNothing);
      await t.tap(find.byKey(const ValueKey('request-decline')));
      await t.pumpAndSettle();
      expect(await a1, isFalse);

      final r = req(true);
      final a2 = e.debugAsk(r);
      await t.pumpAndSettle();
      expect(find.text('Always allow this device'), findsOneWidget);
      final box = t.getSize(find.byKey(const ValueKey('request-always')));
      expect(box.height, greaterThanOrEqualTo(48));
      await t.tap(find.text('Always allow this device'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('request-accept')));
      await t.pumpAndSettle();
      expect(await a2, isTrue);
      expect(r.alwaysAllow, isTrue);
    });

    testWidgets('D3: Trusted devices can turn "Always allow" off', (t) async {
      final e = (await t.runAsync(() => engine(allow: true)))!;
      expect(e.trustedDevices.single.alwaysAllow, isTrue);
      SharedPreferences.setMockInitialValues({});
      final s = (await t.runAsync(SettingsController.load))!;
      await t.pumpWidget(
        AppScope(
          engine: e,
          settings: s,
          child: const MaterialApp(home: TrustedDevicesScreen()),
        ),
      );
      final sw = find.byKey(const ValueKey('always-allow-r1'));
      expect(sw, findsOneWidget);
      await t.tap(sw);
      for (var i = 0; i < 20 && e.trustedDevices.single.alwaysAllow; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump();
      }
      // The save finishes, then the screen is told.
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pumpAndSettle();
      }
      expect(e.trustedDevices.single.alwaysAllow, isFalse);
      expect(find.byKey(const ValueKey('always-allow-r1')), findsNothing);
    });
  });
}
