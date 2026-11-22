// E3 (0.12.1): Settings > About: version + build, key fingerprint, the
// latest-build link, how to update, and the licences page.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/diag_report.dart';
import 'package:isekaidrop/ui/screens/about_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  late IsekaiEngine engine;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('isekai_e3');
    final store = TrustStore(File(p.join(dir.path, 't.json')));
    await store.load();
    engine = IsekaiEngine(
      identity: Identity.generate(),
      trust: store,
      deviceName: () => 'Phone',
      platformName: 'android',
      tempDir: Directory(p.join(dir.path, 'in')),
      finalizer: directoryFinalizer(Directory(p.join(dir.path, 'in'))),
      enableDiscovery: false,
    );
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> pump(WidgetTester t, Future<String?> Function() build) async {
    t.view.physicalSize = const Size(400, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = (await t.runAsync(SettingsController.load))!;
    await t.pumpWidget(
      AppScope(
        engine: engine,
        settings: s,
        child: MaterialApp(home: AboutScreen(buildNumber: build)),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('E3: version, build, key, link, update steps, licences', (
    t,
  ) async {
    await pump(t, () async => '27');
    expect(find.text('Isekai Drop $kAppVersion'), findsOneWidget);
    expect(find.text('Build 27'), findsOneWidget);
    expect(
      find.textContaining(engine.myFingerprint.substring(0, 8)),
      findsWidgets,
    );
    expect(find.text(kLatestBuildUrl), findsOneWidget);
    expect(
      kLatestBuildUrl,
      'https://github.com/CAPPY7/isekai-drop/releases/tag/latest-build',
    );
    expect(find.text('How to update'), findsOneWidget);
    expect(find.textContaining('NOT TESTED'), findsWidgets);
    final lic = find.text('Licences');
    expect(lic, findsOneWidget);
    final size = t.getSize(
      find.ancestor(
        of: lic,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(size.height, greaterThanOrEqualTo(48));
    await t.tap(lic);
    await t.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('E3: a local build says so', (t) async {
    await pump(t, () async => null);
    expect(find.text('Build: local build (not from GitHub)'), findsOneWidget);
  });
}
