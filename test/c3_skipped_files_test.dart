// C3 (0.11.4): files the pickers cannot add are counted and shown
// ("N files were not added" + reason), never dropped silently.
// The Android picker is simulated with its channel results.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/ui/ui_env.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/engine/pick_result.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/files_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('C3: Android picked files with unknown size are counted', () {
    final r = parseAndroidPicked([
      {'uri': 'content://a/1', 'name': 'a.jpg', 'size': 10},
      {'uri': 'content://a/2', 'name': 'b.jpg', 'size': -1},
      {'uri': 'content://a/3', 'name': 'c.jpg', 'size': null},
    ]);
    expect(r.files.map((f) => f.name), ['a.jpg']);
    expect(r.skipped.unknownSize, 2);
    expect(r.skipped.messages, [
      '2 files were not added: their size could not be read.',
    ]);
  });

  test('C3: Android folder: unknown size, too deep and too many', () {
    final r = parseAndroidFolder({
      'name': 'Album',
      'files': [
        {
          'uri': 'content://a/1',
          'name': 'a.jpg',
          'rel': 'Album/a.jpg',
          'size': 5,
        },
        {
          'uri': 'content://a/2',
          'name': 'b.jpg',
          'rel': 'Album/b.jpg',
          'size': -1,
        },
      ],
      'skippedDeep': 3,
      'skippedMany': 120,
    });
    expect(r.files, hasLength(1));
    expect(r.skipped.total, 124);
    expect(r.skipped.messages, [
      '1 file was not added: its size could not be read.',
      '3 folders were not added: they are more than 32 folders deep.',
      '120 files were not added: a folder can add at most 20000 files.',
    ]);
  });

  test('C3: nothing skipped: no message', () {
    final r = parseAndroidPicked([
      {'uri': 'content://a/1', 'name': 'a.jpg', 'size': 10},
    ]);
    expect(r.skipped.total, 0);
    expect(r.skipped.messages, isEmpty);
  });

  test('C3: desktop folder: unreadable files are counted', () async {
    final dir = await Directory.systemTemp.createTemp('isekai_c3');
    addTearDown(() => dir.delete(recursive: true));
    final album = Directory(p.join(dir.path, 'Album'))..createSync();
    File(p.join(album.path, 'ok.txt')).writeAsStringSync('hi');
    final r = await folderPick(
      album,
      canRead: (f) => !f.path.endsWith('ok.txt'),
    );
    expect(r.files, isEmpty);
    expect(r.skipped.unreadable, 1);
    expect(r.skipped.messages, ['1 file was not added: it could not be read.']);
  });

  group('screen', () {
    late Directory dir;
    late IsekaiEngine engine;
    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('isekai_c3_ui');
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

    testWidgets('C3: the Send screen shows "N files were not added"', (
      t,
    ) async {
      t.view.physicalSize = const Size(420, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsController.load();
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
                  pickFiles: () async => parseAndroidPicked([
                    {'uri': 'content://a/1', 'name': 'a.jpg', 'size': 10},
                    {'uri': 'content://a/2', 'name': 'b.jpg', 'size': -1},
                    {'uri': 'content://a/3', 'name': 'c.jpg', 'size': -1},
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Pick files'));
      await t.pumpAndSettle();
      expect(find.text('1. Files: 1, 10 B'), findsOneWidget);
      expect(
        find.text('2 files were not added: their size could not be read.'),
        findsOneWidget,
      );
    });
  });
}
