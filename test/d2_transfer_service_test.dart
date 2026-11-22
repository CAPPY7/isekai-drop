// D2 (0.12.0): Android foreground service + notifications. The Dart side
// decides when the service runs and what the notification shows (counts
// and measured bytes only, never names); the Android side is simulated
// with its channel.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/transfer_service.dart';
import 'package:isekaidrop/ui/notification_ask.dart';

TransferJob job(String id, JobDirection d, int total) => TransferJob(
  id: id,
  direction: d,
  peerName: 'Secret Phone',
  fileCount: 1,
  totalBytes: total,
  fileNames: const ['secret-name.jpg'],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('isekai_drop/service');
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

  group('bridge', () {
    late ChangeNotifier engine;
    late List<TransferJob> jobs;
    late List<PendingRequest> pending;
    late TransferServiceBridge bridge;
    var t = DateTime(2026);
    setUp(() {
      engine = ChangeNotifier();
      jobs = [];
      pending = [];
      t = DateTime(2026);
      bridge = TransferServiceBridge(
        listenable: engine,
        jobs: () => jobs,
        pending: () => pending,
        channel: ch,
        now: () => t,
        tick: null,
      )..attach();
    });
    tearDown(() => bridge.detach());

    test('D2: starts with a transfer, stops when no job is active', () async {
      await bridge.sync();
      expect(calls, isEmpty, reason: 'nothing to do: no service');
      final a = job('a', JobDirection.sending, 1000)..start();
      jobs.add(a);
      await bridge.sync();
      expect(calls.single.method, 'update');
      expect(calls.single.arguments, {
        'sending': 1,
        'receiving': 0,
        'requests': 0,
        'done': 0,
        'total': 1000,
      });
      a.finish(JobState.completed);
      await bridge.sync();
      expect(calls.last.method, 'stop');
      calls.clear();
      await bridge.sync();
      expect(calls, isEmpty, reason: 'stopped once');
    });

    test('D2: no names in what goes to the notification', () async {
      jobs.add(job('a', JobDirection.receiving, 50)..start());
      await bridge.sync();
      final text = calls.map((c) => '${c.arguments}').join();
      expect(text, isNot(contains('Secret')));
      expect(text, isNot(contains('secret-name')));
    });

    test('D2: progress is measured bytes, at most once a second', () async {
      final a = job('a', JobDirection.sending, 1000)..start();
      jobs.add(a);
      await bridge.sync();
      a.addBytes(100);
      await bridge.sync();
      expect(calls, hasLength(1), reason: 'too soon');
      t = t.add(const Duration(seconds: 1));
      await bridge.sync();
      expect(calls, hasLength(2));
      expect((calls.last.arguments as Map)['done'], 100);
      // A new job (count change) is sent at once.
      jobs.add(job('b', JobDirection.receiving, 10)..start());
      await bridge.sync();
      expect(calls, hasLength(3));
      expect((calls.last.arguments as Map)['receiving'], 1);
    });

    test('D2: an incoming request starts it too', () async {
      pending.add(
        PendingRequest(
          id: 'r',
          kind: RequestKind.transfer,
          peerName: 'Secret Phone',
          peerPlatform: 'android',
        ),
      );
      await bridge.sync();
      expect(calls.single.method, 'update');
      expect((calls.single.arguments as Map)['requests'], 1);
      pending.single.decline();
      await bridge.sync();
      expect(calls.last.method, 'stop');
    });

    test('D2: Cancel in the notification cancels the active jobs', () async {
      final a = job('a', JobDirection.sending, 1000)..start();
      final b = job('b', JobDirection.receiving, 1000)..start();
      final done = job('c', JobDirection.sending, 1)
        ..start()
        ..finish(JobState.completed);
      jobs.addAll([a, b, done]);
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            ch.name,
            ch.codec.encodeMethodCall(const MethodCall('cancel')),
            (_) {},
          );
      expect(a.state, JobState.cancelled);
      expect(b.state, JobState.cancelled);
      expect(done.state, JobState.completed);
    });
  });

  group('permission', () {
    testWidgets('D2: explains first, asks once', (t) async {
      var asked = false;
      var systemAsked = 0;
      Future<void> run(BuildContext c) => maybeAskNotifications(
        c,
        alreadyAsked: () => asked,
        markAsked: () async => asked = true,
        askSystem: () async {
          systemAsked++;
          return true;
        },
      );
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final f = run(ctx);
      await t.pumpAndSettle();
      expect(find.text('Show transfer notifications?'), findsOneWidget);
      expect(systemAsked, 0, reason: 'our explanation comes first');
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await f;
      expect(systemAsked, 1);
      expect(asked, isTrue);
      await run(ctx);
      await t.pumpAndSettle();
      expect(find.text('Show transfer notifications?'), findsNothing);
      expect(systemAsked, 1);
    });

    testWidgets('D2: "Not now" does not ask the system', (t) async {
      var asked = false;
      var systemAsked = 0;
      late BuildContext ctx;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final f = maybeAskNotifications(
        ctx,
        alreadyAsked: () => asked,
        markAsked: () async => asked = true,
        askSystem: () async {
          systemAsked++;
          return true;
        },
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Not now'));
      await t.pumpAndSettle();
      await f;
      expect(systemAsked, 0);
      expect(asked, isTrue, reason: 'not asked again at every transfer');
    });
  });
}
