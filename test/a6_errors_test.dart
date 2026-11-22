// A6 (0.11.2): uncaught errors go to Diagnostics (no paths, no names), and
// the start error screen has "Copy details".
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/core/diag_log.dart';
import 'package:isekaidrop/engine/core/identity_loader.dart';
import 'package:isekaidrop/startup_guard.dart';

const _private = '/home/kazuto/Secret Holiday.mp4 from Kazuto-PC 192.168.1.4';

void expectClean(String s) {
  for (final bad in [
    '/home',
    'kazuto',
    'Kazuto',
    'Secret',
    '192.168',
    '.mp4',
  ]) {
    expect(s.contains(bad), isFalse, reason: '"$bad" leaked: $s');
  }
}

void main() {
  test('A6: a thrown async error appears in diagLog (zone guard)', () async {
    final log = DiagLog();
    final done = Completer<void>();
    runGuardedStartup(log, () async {
      Future<void>(() => throw StateError(_private));
      Timer(const Duration(milliseconds: 20), done.complete);
    });
    await done.future;
    final e = log.latest!;
    expect(e.kind, 'uncaught_StateError');
    expectClean(e.message);
    expectClean(e.kind);
  });

  test('A6: FlutterError.onError and PlatformDispatcher.onError log too', () {
    final log = DiagLog();
    final oldFlutter = FlutterError.onError;
    final oldPlatform = PlatformDispatcher.instance.onError;
    addTearDown(() {
      FlutterError.onError = oldFlutter;
      PlatformDispatcher.instance.onError = oldPlatform;
    });
    installErrorHandlers(log, presentFlutterErrors: false);
    FlutterError.onError!(
      FlutterErrorDetails(exception: ArgumentError(_private)),
    );
    expect(log.latest!.kind, 'uncaught_ArgumentError');
    final handled = PlatformDispatcher.instance.onError!(
      FormatException(_private),
      StackTrace.current,
    );
    expect(handled, isTrue);
    expect(log.latest!.kind, 'uncaught_FormatException');
    for (final e in log.entries) {
      expectClean(e.message);
    }
  });

  test('A6: error class names are plain (no private underscore, no '
      'generics)', () {
    expect(plainErrorClass(StateError('x')), 'StateError');
    expect(plainErrorClass(<int>[]), 'List');
    expect(plainErrorClass(_Hidden()), 'Hidden');
  });

  testWidgets('A6: start error screen shows the reason class and Copy '
      'details; report has no names/paths', (t) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await t.pumpWidget(StartupErrorApp(error: StateError(_private)));
    expect(find.textContaining('StateError'), findsOneWidget);
    await t.tap(find.text('Copy details'));
    await t.pump();
    expect(copied, isNotNull);
    expect(copied, contains('StateError'));
    expect(copied, contains('Isekai Drop'));
    expectClean(copied!);

    await t.pumpWidget(
      const StartupErrorApp(error: IdentityUnreadable('key_store_error')),
    );
    expect(find.text('Copy details'), findsOneWidget);
    await t.tap(find.text('Copy details'));
    await t.pump();
    expect(copied, contains('key_store_error'));
  });
}

class _Hidden {}
