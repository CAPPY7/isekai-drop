// 0.11.0 (spec C11/C13/C14/D15/D17/D18): transfer screen states.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/direct/direct_link.dart' show LinkRoute;
import 'package:isekaidrop/engine/core/history_store.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/transfer_screen.dart';
import 'package:isekaidrop/ui/theme/app_theme.dart';
import 'package:isekaidrop/ui/widgets/transfer_parts.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

late Directory _dir;
late IsekaiEngine _eng;

Future<IsekaiEngine> _engine() async {
  final store = TrustStore(File(p.join(_dir.path, 'trust.json')));
  await store.load();
  return IsekaiEngine(
    history: HistoryStore(File(p.join(_dir.path, 'hist.json'))),
    identity: Identity.generate(),
    trust: store,
    deviceName: () => 'Test phone',
    platformName: 'android',
    tempDir: Directory(p.join(_dir.path, 'in')),
    finalizer: directoryFinalizer(Directory(p.join(_dir.path, 'in'))),
    enableDiscovery: false,
  );
}

TransferJob _job({List<SendSource> sources = const []}) => TransferJob(
  id: 'j1',
  direction: JobDirection.sending,
  peerName: 'OnePlus 9',
  fileCount: 2,
  totalBytes: 2000000,
  fileNames: const ['holiday.jpg', 'notes.txt'],
  sources: sources,
);

Future<void> _pump(
  WidgetTester tester,
  TransferJob job, {
  Size size = const Size(420, 2400),
  double textScale = 1,
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsController.load();
  await tester.pumpWidget(
    AppScope(
      engine: _eng,
      settings: settings,
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: TransferScreen(job: job, localLink: () async => '5 GHz'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUpAll(() async {
    _dir = await Directory.systemTemp.createTemp('isekai_transfer_ui');
  });
  tearDownAll(() => _dir.delete(recursive: true));
  setUp(() async => _eng = await _engine());

  test('route chip, title and problem split', () {
    expect(routeChipText(LinkRoute.router, null, '5 GHz'), 'Router · 5 GHz');
    expect(
      routeChipText(LinkRoute.router, null, 'Ethernet'),
      'Router · Ethernet',
    );
    expect(routeChipText(LinkRoute.router, null, null), 'Router');
    expect(
      routeChipText(LinkRoute.wifiDirect, '5 GHz (5180 MHz), 866 Mbps', null),
      'Fast direct · 5 GHz',
    );
    expect(routeChipText(null, null, '5 GHz'), isNull);
    expect(jobTitle(const ['a/b/holiday.jpg', 'x'], 2), 'holiday.jpg + 1 more');
    expect(jobTitle(const ['holiday.jpg'], 1), 'holiday.jpg');
    expect(jobTitle(const [], 3), '3 files');
    final (a, b) = splitProblem(
      'The connection was lost. Nothing unverified was saved.',
    );
    expect(a, 'The connection was lost.');
    expect(b, 'Nothing unverified was saved.');
    expect(splitProblem('The other device declined.').$2, isNull);
  });

  testWidgets(
    'running: name, big percent, speed, route chip, big Pause/Cancel',
    (tester) async {
      final job = _job()
        ..start()
        ..addBytes(1000000)
        ..setRoute(LinkRoute.router);
      await _pump(tester, job);
      expect(find.text('holiday.jpg + 1 more'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.byKey(const ValueKey('transfer-speed')), findsOneWidget);
      expect(find.text('Router · 5 GHz'), findsOneWidget);
      final pause = tester.getRect(
        find.byKey(const ValueKey('transfer-pause')),
      );
      final cancel = tester.getRect(
        find.byKey(const ValueKey('transfer-cancel')),
      );
      expect(pause.height, greaterThanOrEqualTo(48));
      expect(cancel.height, greaterThanOrEqualTo(48));
      expect(cancel.left - pause.right, greaterThanOrEqualTo(8));
      // TalkBack labels.
      final h = tester.ensureSemantics();
      await tester.pump();
      expect(find.bySemanticsLabel('Progress 50 percent'), findsOneWidget);
      expect(find.bySemanticsLabel('Route: Router · 5 GHz'), findsOneWidget);
      h.dispose();
      // Cancel asks first.
      await tester.tap(find.byKey(const ValueKey('transfer-cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this transfer?'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(job.isActive, isTrue);
      await _end(tester);
    },
  );

  testWidgets('finished: check, names, average speed, Send more', (
    tester,
  ) async {
    final job = _job()
      ..start()
      ..addBytes(2000000);
    job.finish(JobState.completed, 'Sent and verified by the other device.');
    await _pump(tester, job);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('holiday.jpg'), findsOneWidget);
    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.byKey(const ValueKey('transfer-average')), findsOneWidget);
    expect(find.text('Send more'), findsOneWidget);
    await _end(tester);
  });

  testWidgets('error: plain problem, fix, Retry and Details with codes', (
    tester,
  ) async {
    final job = _job(
      sources: [
        FileSendSource(File(p.join(_dir.path, 'holiday.jpg')), size: 3),
      ],
    )..start();
    job.finish(
      JobState.failed,
      'The connection was lost. When the sender taps Retry, it continues where it stopped.',
    );
    await _pump(tester, job);
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.text('The connection was lost.'), findsOneWidget);
    expect(find.byKey(const ValueKey('error-fix')), findsOneWidget);
    expect(find.byKey(const ValueKey('transfer-retry')), findsOneWidget);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Codes: none recorded'), findsOneWidget);
    await _end(tester);
  });

  for (final light in [false, true]) {
    testWidgets('200% text at 320dp: no overflow (light: $light)', (
      tester,
    ) async {
      final job = _job()
        ..start()
        ..addBytes(500000)
        ..setRoute(LinkRoute.router);
      await _pump(
        tester,
        job,
        size: const Size(320, 2400),
        textScale: 2,
        theme: light ? AppTheme.light() : AppTheme.dark(),
      );
      expect(tester.takeException(), isNull);
      job.finish(JobState.completed, 'done');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Send more'), findsOneWidget);
      await _end(tester);
    });
  }
}
