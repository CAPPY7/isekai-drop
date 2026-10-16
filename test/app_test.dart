import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/engine/demo_engine.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

late Directory _dir;
late IsekaiEngine _engine;
late Identity _peer;

Future<SettingsController> _pump(
  WidgetTester tester, {
  Size size = const Size(420, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsController.load();
  await tester.pumpWidget(
    IsekaiDropApp(
      engine: _engine,
      settings: settings,
      demoHistory: DemoHistory(latency: const Duration(milliseconds: 10)),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

ThemeMode _mode(WidgetTester t) =>
    t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  setUpAll(() async {
    _dir = await Directory.systemTemp.createTemp('isekai_ui');
    _peer = Identity.generate();
  });
  tearDownAll(() => _dir.delete(recursive: true));

  setUp(() async {
    final store = TrustStore(
      File(
        p.join(
          _dir.path,
          'trust-${DateTime.now().microsecondsSinceEpoch}.json',
        ),
      ),
    );
    await store.load();
    await store.addTrusted(
      deviceId: _peer.deviceId,
      name: 'Test Windows PC',
      platform: 'windows',
      certPem: _peer.certPem,
    );
    // Engine is NOT started in widget tests (no sockets needed for UI tests).
    _engine = IsekaiEngine(
      identity: Identity.generate(),
      trust: store,
      deviceName: () => 'Test phone',
      platformName: 'android',
      tempDir: Directory(p.join(_dir.path, 'in')),
      finalizer: directoryFinalizer(Directory(p.join(_dir.path, 'in'))),
      enableDiscovery: false,
    );
  });

  testWidgets('home shows real engine data and phone bottom bar', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Test Windows PC'), findsOneWidget);
    expect(find.text('Trusted (key verified)'), findsOneWidget);
    expect(
      find.textContaining('DEMO'),
      findsNothing,
      reason: 'Home has no demo data now',
    );
  });

  testWidgets('desktop size uses side rail layout', (tester) async {
    await _pump(tester, size: const Size(1400, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('theme switch changes theme and is saved', (tester) async {
    final settings = await _pump(tester);
    expect(_mode(tester), ThemeMode.dark);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(_mode(tester), ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
    expect(SettingsController(prefs).themeMode, ThemeMode.light);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.system);
  });

  testWidgets('navigation between tabs and Back returns Home', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(find.text('DEMO - not a real transfer'), findsOneWidget);
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(find.text('Pick files'), findsOneWidget);
    expect(
      find.text('Test Windows PC'),
      findsOneWidget,
      reason: 'trusted device offered as target',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Isekai Drop'), findsOneWidget);
  });

  testWidgets('connect screen validates a typed address', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Connect').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'IP address of the other device'),
      'abc',
    );
    await tester.tap(find.text('Connect and pair'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not a valid IP address'), findsOneWidget);
  });

  testWidgets('revoke asks first: cancel keeps, confirm removes', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Test Windows PC'), findsOneWidget);
    final revoke = find.bySemanticsLabel('Revoke Test Windows PC');
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(find.text('Revoke trust?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Test Windows PC'), findsOneWidget);

    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    // Let the real file write of the trust database finish.
    for (
      var i = 0;
      i < 40 && find.text('Test Windows PC').evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Test Windows PC'), findsNothing);
    expect(_engine.trustedDevices, isEmpty);
  });

  testWidgets('DEMO history: clear asks first and shows empty state', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    final clear = find.text('Clear history');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No transfers yet'), findsOneWidget);
  });
}
