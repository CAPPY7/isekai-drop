import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/history_store.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

late Directory _dir;
late IsekaiEngine _engine;
late Identity _peer;
late HistoryStore _history;

Future<SettingsController> _pump(
  WidgetTester tester, {
  Size size = const Size(420, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsController.load();
  await tester.pumpWidget(IsekaiDropApp(engine: _engine, settings: settings));
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
    _history = HistoryStore(
      File(
        p.join(_dir.path, 'hist-${DateTime.now().microsecondsSinceEpoch}.json'),
      ),
    );
    await _history.add(
      HistoryEntry(
        id: 'h1',
        direction: HistoryDirection.received,
        outcome: HistoryOutcome.completed,
        peerName: 'Test Windows PC',
        peerDeviceId: _peer.deviceId,
        fileCount: 1,
        totalBytes: 2048,
        bytesDone: 2048,
        createdAt: DateTime.utc(2026, 10, 16, 10),
        updatedAt: DateTime.utc(2026, 10, 16, 10),
        fileNames: const ['holiday.jpg'],
      ),
    );
    _engine = IsekaiEngine(
      history: _history,
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
    expect(find.text('Verified (code compared)'), findsOneWidget);
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
    expect(find.text('Received from Test Windows PC'), findsOneWidget);
    expect(find.textContaining('DEMO'), findsNothing);
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

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 80 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets('revoke asks first, blocks; remove asks first, deletes', (
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
    expect(_engine.trustedDevices.single.isTrusted, isTrue);

    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await waitFor(
      tester,
      () => find.text('Revoked - blocked').evaluate().isNotEmpty,
    );
    expect(_engine.trustedDevices.single.status, TrustStatus.revoked);
    expect(find.text('Revoked - blocked'), findsOneWidget);
    expect(find.bySemanticsLabel('Revoke Test Windows PC'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Remove Test Windows PC'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from this list?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await waitFor(
      tester,
      () => find.text('Test Windows PC').evaluate().isEmpty,
    );
    expect(find.text('Test Windows PC'), findsNothing);
  });

  testWidgets('check code shows the shared code and marks verified', (
    tester,
  ) async {
    // Make the device "trusted" (as if migrated from schema 1).
    await _pump(tester);
    final d = _engine.trustedDevices.single;
    await tester.runAsync(
      () => _engine.trust.addTrusted(
        deviceId: d.deviceId,
        name: d.name,
        platform: d.platform,
        certPem: d.certPem,
        verified: false,
      ),
    );
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Trusted (code not re-checked)'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Check code with Test Windows PC'));
    await tester.pumpAndSettle();
    expect(find.text(_engine.codeFor(d)), findsOneWidget);
    await tester.tap(find.text('Codes match'));
    await waitFor(tester, () => _engine.trustedDevices.single.isVerified);
    expect(_engine.trustedDevices.single.isVerified, isTrue);
  });

  testWidgets('auto-receive is off and asks before turning on', (tester) async {
    final settings = await _pump(tester);
    expect(settings.autoReceiveVerified, isFalse);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    final sw = find.text('Auto-receive from verified devices');
    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(find.text('Turn on auto-receive?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(settings.autoReceiveVerified, isFalse);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(settings.autoReceiveVerified, isTrue);
  });

  testWidgets('history: names can be hidden; clear asks first', (tester) async {
    final settings = await _pump(tester);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Received from Test Windows PC'));
    await tester.pumpAndSettle();
    expect(find.text('- holiday.jpg'), findsOneWidget);
    await settings.setHistoryFileNames(false);
    await tester.pumpAndSettle();
    expect(find.text('- holiday.jpg'), findsNothing);

    final clear = find.text('Clear history');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_history.entries, hasLength(1));
    await tester.tap(clear);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await waitFor(
      tester,
      () => find.text('No transfers yet').evaluate().isNotEmpty,
    );
    expect(find.text('No transfers yet'), findsOneWidget);
  });
}
