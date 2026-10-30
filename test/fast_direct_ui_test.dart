import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/engine/direct/direct_link.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/fast_direct_screen.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'direct_test.dart' show FakeDirect;

late Directory _dir;

Finder _qr(String prefix) => find.byWidgetPredicate(
  (w) =>
      w is QrImageView &&
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('qr:$prefix'),
);

Future<IsekaiEngine> _engine(FakeDirect? fake) async {
  final store = TrustStore(
    File(p.join(_dir.path, 't-${DateTime.now().microsecondsSinceEpoch}.json')),
  );
  await store.load();
  return IsekaiEngine(
    identity: Identity.generate(),
    trust: store,
    deviceName: () => 'My phone',
    platformName: 'android',
    tempDir: Directory(p.join(_dir.path, 'in')),
    finalizer: directoryFinalizer(Directory(p.join(_dir.path, 'in'))),
    enableDiscovery: false,
    directLinks: fake,
  );
}

Future<SettingsController> _pump(
  WidgetTester t,
  IsekaiEngine e,
  Widget child,
) async {
  t.view.physicalSize = const Size(500, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await t.runAsync(SettingsController.load);
  await t.pumpWidget(
    AppScope(
      engine: e,
      settings: settings!,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await t.pumpAndSettle();
  return settings;
}

void main() {
  setUpAll(() async {
    _dir = await Directory.systemTemp.createTemp('isekai_fd_ui');
  });
  tearDownAll(() => _dir.delete(recursive: true));

  testWidgets('Android: start shows both QR codes, Wi-Fi details; stop ends', (
    t,
  ) async {
    final fake = FakeDirect(hostIp: '192.168.49.1');
    final e = (await t.runAsync(() => _engine(fake)))!;
    await _pump(t, e, const FastDirectScreen());
    expect(find.text('Share my fast link'), findsOneWidget);
    await t.tap(find.text('Start fast link'));
    await t.pumpAndSettle();
    expect(fake.hosts, 1);
    expect(find.textContaining('Wi-Fi Direct'), findsWidgets);
    expect(find.textContaining('5 GHz'), findsWidgets);
    expect(find.text('DIRECT-AB-IsekaiDrop'), findsOneWidget);
    expect(find.text('abcdefgh23'), findsOneWidget);
    expect(find.textContaining('192.168.49.1:'), findsOneWidget);
    expect(_qr('isekaidrop:direct?'), findsOneWidget);
    await t.tap(find.text('PC / iPhone camera'));
    await t.pumpAndSettle();
    expect(_qr('WIFI:S:DIRECT-AB-IsekaiDrop;T:WPA;P:abcdefgh23;;'), findsOne);
    await t.tap(find.text('Stop fast link'));
    await t.pumpAndSettle();
    expect(fake.stops, greaterThanOrEqualTo(1));
    expect(e.hostedDirectLink, isNull);
    expect(find.text('Start fast link'), findsOneWidget);
  });

  testWidgets('Android: permission explained first; still denied -> how', (
    t,
  ) async {
    final fake = FakeDirect()..perm = 'denied';
    final e = (await t.runAsync(() => _engine(fake)))!;
    await _pump(t, e, const FastDirectScreen());
    expect(find.textContaining('Nearby devices'), findsOneWidget);
    await t.tap(find.text('Start fast link'));
    await t.pumpAndSettle();
    expect(find.text('Allow Fast direct?'), findsOneWidget);
    expect(find.textContaining('never reads your location'), findsWidgets);
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle();
    expect(find.textContaining('Android Settings > Apps'), findsOneWidget);
    expect(fake.hosts, 0);
  });

  testWidgets('Settings switch: shown on Android, Allow asks again', (t) async {
    final fake = FakeDirect()..perm = 'denied';
    final e = (await t.runAsync(() => _engine(fake)))!;
    final s = await _pump(t, e, const FastDirectSetting());
    expect(find.text('Fast direct'), findsOneWidget);
    expect(s.routeMode, SettingsController.routeAuto);
    expect(find.text('Auto (fastest)'), findsOneWidget);
    expect(s.fastDirect, isTrue);
    await t.tap(find.text('Allow'));
    await t.pumpAndSettle();
    expect(find.textContaining('Still not allowed'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('route-mode')));
    await t.pumpAndSettle();
    await t.tap(find.text('Router only').last);
    await t.pumpAndSettle();
    expect(s.routeMode, SettingsController.routeRouter);
    expect(s.fastDirect, isFalse);
    expect(find.text('Allow'), findsNothing);
  });

  testWidgets('Settings switch hidden where the phone cannot make links', (
    t,
  ) async {
    final e = (await t.runAsync(() => _engine(null)))!;
    await _pump(t, e, const FastDirectSetting());
    expect(find.text('Fast direct'), findsNothing);
  });

  testWidgets(
    'PC: paste a Fast direct code fills the join form; checks input',
    (t) async {
      if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) return;
      final e = (await t.runAsync(() => _engine(null)))!;
      await _pump(t, e, const FastDirectScreen());
      expect(find.text('Join a phone\'s fast link'), findsOneWidget);
      await t.tap(find.text('Join'));
      await t.pumpAndSettle();
      expect(find.textContaining('8 to 63 characters'), findsOneWidget);
      final code = DirectQr(
        link: const DirectLinkInfo(
          kind: DirectKind.wifiDirect,
          ssid: 'DIRECT-Q7-IsekaiDrop',
          passphrase: 'secretpass9',
          hostIp: '192.168.49.1',
        ),
        port: 47321,
        fingerprint: 'a' * 64,
        name: 'Pixel',
      ).encode();
      await t.enterText(find.byType(TextField).first, code);
      await t.tap(find.byTooltip('Use pasted text'));
      await t.pumpAndSettle();
      expect(find.text('DIRECT-Q7-IsekaiDrop'), findsOneWidget);
      expect(find.textContaining('Read the link of Pixel'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'hello');
      await t.tap(find.byTooltip('Use pasted text'));
      await t.pumpAndSettle();
      expect(find.textContaining('not a Wi-Fi code'), findsOneWidget);
    },
  );
}
