// C6 (0.11.4): Android may recreate the app while its file picker is open.
// The picked files are then kept on the Kotlin side (Activity Result API)
// and the Send screen takes them when it opens. Kotlin side: NOT TESTED
// on a phone; here the platform result is simulated.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/engine/pick_result.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/files_screen.dart';
import 'package:isekaidrop/ui/ui_env.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('C6: a kept folder result is read like a fresh one', () {
    final r = parseLostPick({
      'folder': {
        'name': 'Album',
        'files': [
          {
            'uri': 'content://t/1',
            'name': 'a.jpg',
            'rel': 'Album/a.jpg',
            'size': 3,
          },
        ],
      },
    });
    expect(r.files.single.relativePath, 'Album/a.jpg');
    expect(parseLostPick(null).files, isEmpty);
    final f = parseLostPick({
      'files': [
        {'uri': 'content://t/2', 'name': 'b.jpg', 'size': -1},
      ],
    });
    expect(f.skipped.unknownSize, 1);
  });

  late Directory dir;
  late IsekaiEngine engine;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('isekai_c6_lost');
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
  tearDownAll(() => dir.delete(recursive: true));

  testWidgets('C6: the Send screen adds files picked before a restart', (
    t,
  ) async {
    t.view.physicalSize = const Size(420, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final s = await SettingsController.load();
    var asked = 0;
    await t.pumpWidget(
      AppScope(
        engine: engine,
        settings: s,
        child: UiEnv(
          animations: false,
          readPlatform: false,
          child: MaterialApp(
            home: Scaffold(
              body: FilesScreen(
                isDesktop: false,
                takeLostPick: () async {
                  asked++;
                  return parseLostPick({
                    'files': [
                      {'uri': 'content://t/1', 'name': 'kept.jpg', 'size': 7},
                    ],
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(asked, 1);
    expect(find.text('1. Files: 1, 7 B'), findsOneWidget);
    expect(find.text('kept.jpg'), findsOneWidget);
  });
}
