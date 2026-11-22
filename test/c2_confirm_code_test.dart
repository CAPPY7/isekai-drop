// C2 (0.11.4): sending to a device that is not paired yet waits until the
// sender compared the 16-digit code ("Same code, send"). Real TLS over
// localhost; only the buttons are simulated.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/ui/pairing_flow.dart';
import 'package:isekaidrop/ui/widgets/common.dart';
import 'package:isekaidrop/ui/widgets/device_widgets.dart';

import 'loopback_test.dart' show Node, waitDone, randomFile;
import 'one_tap_test.dart' show nearbyOf;

Future<void> until(bool Function() f) async {
  for (var i = 0; i < 500 && !f(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('engine', () {
    late Node a;
    late Node b;
    late Directory files;
    setUp(() async {
      a = await Node.create('Alice');
      b = await Node.create('Bob');
      files = await Directory.systemTemp.createTemp('isekai_c2');
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
      await files.delete(recursive: true);
    });

    test('C2: unpaired send waits for "Same code, send"; no file names '
        'before that', () async {
      final f = await randomFile(files, 'secret-plan.pdf', 5000);
      final answer = Completer<bool>();
      String? shown;
      final sending = a.engine.sendToNearby(
        nearbyOf(b),
        [FileSendSource(f)],
        confirmCode: (code) {
          shown = code;
          return answer.future;
        },
      );
      await until(() => b.asked.isNotEmpty && shown != null);
      expect(
        shown,
        verificationCode(a.engine.myFingerprint, b.engine.myFingerprint),
      );
      expect(b.asked.single.code, shown, reason: 'both screens: same code');
      expect(b.asked.single.fileNames, isEmpty, reason: 'no names yet');
      expect(b.asked.single.offerCount, 1);
      expect(b.asked.single.totalBytes, 5000);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(b.inboxNames(), isEmpty, reason: 'nothing sent before confirm');
      expect(a.engine.jobs, isEmpty);
      expect(a.engine.trustedDevices, isEmpty);
      answer.complete(true);
      final job = await waitDone(await sending);
      expect(job.state, JobState.completed, reason: job.message);
      expect(b.inboxNames(), ['secret-plan.pdf']);
      expect(
        a.engine.trustedDevices.single.isVerified,
        isTrue,
        reason: 'the user compared the code',
      );
    });

    test('C2: Cancel sends nothing and pairs nothing here', () async {
      final f = await randomFile(files, 'x.bin', 5000);
      await expectLater(
        a.engine.sendToNearby(nearbyOf(b), [
          FileSendSource(f),
        ], confirmCode: (_) async => false),
        throwsA(isA<PairingCancelled>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(a.engine.trustedDevices, isEmpty);
      expect(a.engine.jobs, isEmpty);
      expect(b.inboxNames(), isEmpty);
      expect(b.asked.where((r) => r.kind == RequestKind.transfer), isEmpty);
      expect(b.asked.expand((r) => r.fileNames), isEmpty);
    });

    test('C2: Cancel removes the question on the other device', () async {
      b.engine.debugAutoDecide = null; // a real, open question
      final f = await randomFile(files, 'x.bin', 100);
      final answer = Completer<bool>();
      final sending = a.engine.sendToNearby(nearbyOf(b), [
        FileSendSource(f),
      ], confirmCode: (_) => answer.future);
      await until(() => b.engine.pending.isNotEmpty);
      expect(b.engine.pending.single.fileNames, isEmpty);
      answer.complete(false);
      await expectLater(sending, throwsA(isA<PairingCancelled>()));
      await until(() => b.engine.pending.isEmpty);
      expect(b.engine.pending, isEmpty);
      expect(b.engine.trustedDevices, isEmpty);
    });

    test('C2: without a code check an unpaired send is refused', () async {
      final f = await randomFile(files, 'x.bin', 100);
      await expectLater(
        a.engine.sendToNearby(nearbyOf(b), [FileSendSource(f)]),
        throwsA(isA<PairingException>()),
      );
      expect(b.inboxNames(), isEmpty);
    });

    test(
      'C2: paired devices keep the one-tap send (no code question)',
      () async {
        await a.engine.quickPair('127.0.0.1', b.port);
        final f = await randomFile(files, 'p.bin', 3000);
        final n = nearbyOf(b).withTrust(a.engine.trustedDevices.single);
        final job = await waitDone(
          await a.engine.sendToNearby(n, [
            FileSendSource(f),
          ], confirmCode: (_) => throw StateError('must not ask')),
        );
        expect(job.state, JobState.completed, reason: job.message);
      },
    );

    test('C2: QR pairing keeps one tap and may show the names', () async {
      final f = await randomFile(files, 'qr.bin', 3000);
      final s = await a.engine.beginPairing(
        '127.0.0.1',
        b.port,
        expectFingerprint: b.engine.myFingerprint,
      );
      final dev = await s.confirm(offer: [FileSendSource(f)]);
      expect(dev.isVerified, isTrue);
      expect(b.asked.single.fileNames, ['qr.bin']);
    });
  });

  group('UI', () {
    testWidgets('C2: code dialog asks "Same code, send" / "Cancel"', (t) async {
      bool? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () async => result = await showCodeCheckDialog(
                c,
                'Bob',
                '1234 5678 9012 3456',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(
        find.text('Does the other screen show the same code?'),
        findsOneWidget,
      );
      expect(find.text('1234 5678 9012 3456'), findsOneWidget);
      final send = find.text('Same code, send');
      expect(
        t
            .getSize(
              find.ancestor(of: send, matching: find.byType(FilledButton)),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(result, isFalse);
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      await t.tap(send);
      await t.pumpAndSettle();
      expect(result, isTrue);
    });

    test('C2: never-paired nearby devices say "New device"', () {
      final n = NearbyDevice(
        deviceId: 'x',
        name: 'Bob',
        platform: 'linux',
        host: '127.0.0.1',
        port: 1,
        seenAt: DateTime.now(),
      );
      expect(trustOfNearby(n), DisplayTrust.unknown);
      expect(DisplayTrust.unknown.label, 'New device');
    });
  });
}
