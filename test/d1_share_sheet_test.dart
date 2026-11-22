// D1 (0.12.0): files shared from another Android app ("Share" > Isekai
// Drop) open the Send screen with those files selected. The Android side
// is simulated with its channel results.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/engine/pick_result.dart';
import 'package:isekaidrop/engine/share_intake.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/files_screen.dart';
import 'package:isekaidrop/ui/shell_nav.dart';
import 'package:isekaidrop/ui/ui_env.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('isekai_drop/android');
  final calls = <MethodCall>[];
  Object? reply;
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (c) async {
          calls.add(c);
          return reply;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null),
  );

  test('D1: shared files are taken from the Android side', () async {
    reply = {
      'files': [
        {'uri': 'content://media/1', 'name': 'a.jpg', 'size': 10},
        {'uri': 'content://media/2', 'name': 'b.jpg', 'size': -1},
      ],
      'unreadable': 1,
    };
    final r = await ShareIntake(ch).take();
    expect(calls.single.method, 'takeShared');
    expect(r.files.map((f) => f.name), ['a.jpg']);
    expect(r.skipped.unknownSize, 1);
    expect(r.skipped.unreadable, 1);
  });

  test('D1: nothing shared: empty', () async {
    reply = null;
    final r = await ShareIntake(ch).take();
    expect(r.files, isEmpty);
    expect(r.skipped.total, 0);
  });

  test('D1: only content links from other apps are accepted', () {
    final r = parseSharedFiles({
      'files': [
        // A file link could point into this app's private folder.
        {'uri': 'file:///data/data/x/key', 'name': 'k', 'size': 5},
        // This app's own links (FileProvider) are never sent on.
        {
          'uri': 'content://com.isujaykumar.isekaidrop.files/r/a',
          'name': 'a',
          'size': 5,
        },
        {'uri': 'content://media/3', 'name': 'ok.png', 'size': 7},
      ],
    });
    expect(r.files.map((f) => f.name), ['ok.png']);
    expect(r.skipped.unreadable, 2);
  });

  group('screen', () {
    late Directory dir;
    late IsekaiEngine engine;
    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('isekai_d1_ui');
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

    testWidgets('D1: the Send screen shows the shared files', (t) async {
      t.view.physicalSize = const Size(420, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsController.load();
      final inbox = ValueNotifier<PickResult?>(null);
      await t.pumpWidget(
        AppScope(
          engine: engine,
          settings: s,
          child: UiEnv(
            animations: false,
            readPlatform: false,
            child: MaterialApp(
              home: Scaffold(
                body: FilesScreen(isDesktop: false, sharedInbox: inbox),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Shared from another app'), findsNothing);
      inbox.value = parseSharedFiles({
        'files': [
          {'uri': 'content://media/1', 'name': 'a.jpg', 'size': 10},
          {'uri': 'content://media/2', 'name': 'b.jpg', 'size': -1},
        ],
      });
      await t.pumpAndSettle();
      expect(find.text('Shared from another app'), findsOneWidget);
      expect(find.text('1. Files: 1, 10 B'), findsOneWidget);
      expect(
        find.text('1 file was not added: its size could not be read.'),
        findsOneWidget,
      );
      expect(inbox.value, isNull, reason: 'taken once');
    });

    test('D1: delivering shared files opens the Send tab', () {
      final inbox = ValueNotifier<PickResult?>(null);
      final r = parseSharedFiles({
        'files': [
          {'uri': 'content://media/1', 'name': 'a.jpg', 'size': 10},
        ],
      });
      deliverShared(r, inbox: inbox);
      expect(inbox.value, same(r));
      expect(shellTabRequest.value, ShellTab.send);
      shellTabRequest.value = null;
      // Nothing shared: nothing happens.
      deliverShared(PickResult.empty, inbox: inbox);
      expect(shellTabRequest.value, isNull);
    });
  });
}
