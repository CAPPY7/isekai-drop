// D4 (0.12.0): "Open" and "Show in folder" after receiving. Only the
// commands are checked here (no real process is started): Windows
// explorer /select, macOS open -R, Linux xdg-open on the folder; Android
// goes through the channel (simulated).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/history_store.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/file_actions.dart';
import 'package:isekaidrop/ui/screens/history_screen.dart';
import 'package:isekaidrop/ui/screens/transfer_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class FakeActions extends SavedFileActions {
  final List<String> done = [];
  @override
  bool get canOpen => true;
  @override
  Future<bool> open(String path) async {
    done.add('open $path');
    return true;
  }

  @override
  Future<bool> showInFolder(String path) async {
    done.add('show $path');
    return true;
  }

  @override
  Future<bool> openFolder(String dir) async {
    done.add('folder $dir');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('commands', () {
    List<String>? flat(OpenCommand? c) => c == null ? null : [c.$1, ...c.$2];
    const win = r'C:\Users\me\Downloads\Isekai Drop\a b.txt';
    test('D4: Windows', () {
      expect(flat(openFileCommand('windows', win)), ['explorer.exe', win]);
      expect(flat(showInFolderCommand('windows', win)), [
        'explorer.exe',
        '/select,',
        win,
      ]);
      expect(flat(openFolderCommand('windows', r'C:\x')), [
        'explorer.exe',
        r'C:\x',
      ]);
    });
    test('D4: macOS', () {
      expect(flat(openFileCommand('macos', '/Users/me/a.txt')), [
        'open',
        '/Users/me/a.txt',
      ]);
      expect(flat(showInFolderCommand('macos', '/Users/me/a.txt')), [
        'open',
        '-R',
        '/Users/me/a.txt',
      ]);
      expect(flat(openFolderCommand('macos', '/Users/me')), [
        'open',
        '/Users/me',
      ]);
    });
    test('D4: Linux opens the folder (no portable "select")', () {
      expect(flat(openFileCommand('linux', '/home/me/in/a.txt')), [
        'xdg-open',
        '/home/me/in/a.txt',
      ]);
      expect(flat(showInFolderCommand('linux', '/home/me/in/a.txt')), [
        'xdg-open',
        '/home/me/in',
      ]);
      expect(flat(openFolderCommand('linux', '/home/me/in')), [
        'xdg-open',
        '/home/me/in',
      ]);
    });
    test('D4: odd paths and other systems: nothing is started', () {
      expect(openFileCommand('linux', 'a.txt'), isNull, reason: 'relative');
      expect(openFileCommand('linux', '-n'), isNull, reason: 'option-like');
      expect(openFileCommand('windows', 'a.txt'), isNull);
      expect(openFileCommand('android', '/x/a'), isNull);
      expect(openFileCommand('ios', '/x/a'), isNull);
      expect(showInFolderCommand('linux', ''), isNull);
    });
  });

  group('android', () {
    const ch = MethodChannel('isekai_drop/android');
    final calls = <MethodCall>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, (c) async {
            calls.add(c);
            return true;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ch, null),
    );

    test('D4: open a received file and the Downloads folder', () async {
      final a = AndroidFileOpener(ch);
      expect(await a.open('Downloads/Isekai Drop/Album/a.jpg'), isTrue);
      expect(await a.openFolder(), isTrue);
      expect(calls.map((c) => c.method), ['openReceived', 'openReceiveFolder']);
      expect(calls.first.arguments, {
        'path': 'Downloads/Isekai Drop/Album/a.jpg',
      });
    });

    test('D4: only files this app saved can be opened', () async {
      final a = AndroidFileOpener(ch);
      expect(await a.open('Downloads/Other/a.jpg'), isFalse);
      expect(await a.open('Downloads/Isekai Drop/../x.jpg'), isFalse);
      expect(await a.open('/data/data/x/key'), isFalse);
      expect(calls, isEmpty);
      // Android 9 and older: an absolute path inside an "Isekai Drop"
      // folder (checked again on the Android side).
      expect(
        await a.open('/storage/emulated/0/Download/Isekai Drop/a.jpg'),
        isTrue,
      );
    });
  });

  group('screens', () {
    late Directory dir;
    late IsekaiEngine engine;
    late HistoryStore history;
    late FakeActions fake;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('isekai_d4');
      final store = TrustStore(File(p.join(dir.path, 't.json')));
      await store.load();
      history = HistoryStore(File(p.join(dir.path, 'h.json')));
      engine = IsekaiEngine(
        identity: Identity.generate(),
        trust: store,
        history: history,
        deviceName: () => 'Phone',
        platformName: 'linux',
        tempDir: Directory(p.join(dir.path, 'in')),
        finalizer: directoryFinalizer(Directory(p.join(dir.path, 'in'))),
        enableDiscovery: false,
      );
      fake = FakeActions();
      savedFileActions = fake;
    });
    tearDown(() async {
      savedFileActions = SavedFileActions();
      await dir.delete(recursive: true);
    });

    Future<void> pump(WidgetTester t, Widget w) async {
      t.view.physicalSize = const Size(420, 2000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = (await t.runAsync(SettingsController.load))!;
      await t.pumpWidget(
        AppScope(
          engine: engine,
          settings: s,
          child: MaterialApp(home: Scaffold(body: w)),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('D4: finished receive: Open and Show in folder', (t) async {
      final job = TransferJob(
        id: 'j',
        direction: JobDirection.receiving,
        peerName: 'Phone',
        fileCount: 1,
        totalBytes: 3,
        fileNames: const ['a.txt'],
      )..start();
      job.savedTo.add('/home/me/in/a.txt');
      job.finish(JobState.completed);
      await pump(t, TransferScreen(job: job, localLink: () async => null));
      await t.tap(find.text('Open'));
      await t.tap(find.text('Show in folder'));
      await t.pumpAndSettle();
      expect(fake.done, ['open /home/me/in/a.txt', 'show /home/me/in/a.txt']);
      final h = t.getSize(
        find.ancestor(
          of: find.text('Open'),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        ),
      );
      expect(h.height, greaterThanOrEqualTo(48));
    });

    testWidgets('D4: History: Show folder for received files', (t) async {
      final now = DateTime.now().toUtc();
      await t.runAsync(
        () => history.add(
          HistoryEntry(
            id: 'h1',
            direction: HistoryDirection.received,
            outcome: HistoryOutcome.completed,
            peerName: 'Phone',
            peerDeviceId: null,
            fileCount: 1,
            totalBytes: 3,
            bytesDone: 3,
            createdAt: now,
            updatedAt: now,
            destination: '/home/me/in',
          ),
        ),
      );
      await pump(t, const HistoryScreen());
      await t.tap(find.text('Received from Phone'));
      await t.pumpAndSettle();
      await t.tap(find.text('Show folder'));
      await t.pumpAndSettle();
      expect(fake.done, ['folder /home/me/in']);
    });
  });
}
