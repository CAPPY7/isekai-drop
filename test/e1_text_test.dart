// E1 (0.12.1): send a short text or a link to a paired device. Control
// message {"t":"text","body":...} (max 8 KB UTF-8), protocol version 1.
// The receiver answers Accept/Decline like files; links are never opened
// by themselves. Real TLS over loopback.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/history_store.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/text_message.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/file_actions.dart';
import 'package:isekaidrop/ui/received_text.dart';
import 'package:isekaidrop/ui/screens/files_screen.dart';
import 'package:isekaidrop/ui/ui_env.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phase6_test.dart' show N, pair;

void main() {
  group('rules', () {
    test('E1: 8 KB limit counts UTF-8 bytes, not characters', () {
      expect(kMaxTextBytes, 8 * 1024);
      expect(textBodyProblem(''), 'empty');
      expect(textBodyProblem('   '), 'empty');
      expect(textBodyProblem('a' * 8192), isNull);
      expect(textBodyProblem('a' * 8193), 'too_long');
      // 3 bytes each in UTF-8: 2731 * 3 = 8193 bytes.
      expect(textBodyProblem('ಕ' * 2730), isNull);
      expect(textBodyProblem('ಕ' * 2731), 'too_long');
    });

    test('E1: only plain http/https links get an Open button', () {
      expect(webLinkIn('https://example.com/a?b=1'), isNotNull);
      expect(webLinkIn('  http://192.168.1.5:8080/x  '), isNotNull);
      expect(
        webLinkIn('see https://example.com'),
        isNull,
        reason: 'not only a link',
      );
      expect(webLinkIn('javascript:alert(1)'), isNull);
      expect(webLinkIn('file:///etc/passwd'), isNull);
      expect(webLinkIn('intent://x#Intent;end'), isNull);
      expect(webLinkIn('https://'), isNull);
      expect(webLinkIn('hello'), isNull);
    });

    test('E1: Open link starts the browser with the link as one argument', () {
      final u = Uri.parse('https://example.com/a b');
      final c = openLinkCommand('linux', u)!;
      expect(c.$1, 'xdg-open');
      expect(c.$2, [u.toString()]);
      expect(openLinkCommand('macos', u)!.$1, 'open');
      expect(openLinkCommand('windows', u)!.$2.last, u.toString());
      expect(openLinkCommand('linux', Uri.parse('file:///etc/x')), isNull);
      expect(openLinkCommand('ios', u), isNull);
    });

    test('E1: plain messages for the sender', () {
      expect(
        explainTextError('old_peer'),
        'The other device has an older Isekai Drop that cannot receive text. '
        'Update the other app.',
      );
      expect(
        explainTextError('declined'),
        'The other device declined the text.',
      );
      expect(explainTextError('too_long'), contains('8 KB'));
    });
  });

  group('engine', () {
    late N a;
    late N b;
    setUp(() async {
      a = await N.create('a');
      b = await N.create('b');
      await pair(a, b);
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    test(
      'E1: round trip: asked first, then shown; History has no content',
      () async {
        const body = 'Hello 👋 https://example.com';
        await a.engine.sendText(a.engine.trustedDevices.single, body);
        final r = b.asked.single;
        expect(r.kind, RequestKind.text);
        expect(r.textBody, body);
        final h = b.history.entries.single;
        expect(h.direction, HistoryDirection.received);
        expect(h.message, 'Text received');
        expect(h.fileCount, 0);
        expect(h.fileNames, isEmpty);
        expect(jsonEncode(h.toJson()), isNot(contains('example.com')));
        expect(jsonEncode(h.toJson()), isNot(contains('Hello')));
        // Never in Diagnostics either.
        expect('${b.engine.diagLog.entries}', isNot(contains('Hello')));
      },
    );

    test('E1: decline', () async {
      b.approve = false;
      await expectLater(
        a.engine.sendText(a.engine.trustedDevices.single, 'hi'),
        throwsA(
          isA<TextSendException>().having(
            (e) => e.reason,
            'reason',
            'declined',
          ),
        ),
      );
      expect(b.history.entries, isEmpty);
    });

    test('E1: too long is refused before anything is sent', () async {
      await expectLater(
        a.engine.sendText(a.engine.trustedDevices.single, 'x' * 9000),
        throwsA(
          isA<TextSendException>().having(
            (e) => e.reason,
            'reason',
            'too_long',
          ),
        ),
      );
      expect(b.asked, isEmpty);
    });

    test('E1: the receiver also refuses an oversized text', () async {
      a.engine.debugSkipTextCheck = true;
      await expectLater(
        a.engine.sendText(a.engine.trustedDevices.single, 'x' * 9000),
        throwsA(
          isA<TextSendException>().having(
            (e) => e.reason,
            'reason',
            'too_long',
          ),
        ),
      );
      expect(b.asked, isEmpty, reason: 'never shown');
    });

    test(
      'E1: an older app answers unknown_message: "update the other app"',
      () async {
        b.engine.debugTextUnknown = true; // behaves like 0.12.0 and older
        await expectLater(
          a.engine.sendText(a.engine.trustedDevices.single, 'hi'),
          throwsA(
            isA<TextSendException>().having(
              (e) => e.reason,
              'reason',
              'old_peer',
            ),
          ),
        );
      },
    );
  });

  group('dialog', () {
    testWidgets('E1: Copy, and Open only for a link (never by itself)', (
      t,
    ) async {
      final opened = <Uri>[];
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (c) async {
          if (c.method == 'Clipboard.setData') {
            copied = (c.arguments as Map)['text'] as String?;
          }
          return null;
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
      showReceivedText(
        ctx,
        from: 'Phone',
        body: 'https://example.com/x',
        openLink: (u) async {
          opened.add(u);
          return true;
        },
      );
      await t.pumpAndSettle();
      expect(find.text('Text from Phone'), findsOneWidget);
      expect(opened, isEmpty, reason: 'never opened by itself');
      await t.tap(find.text('Copy'));
      await t.pumpAndSettle();
      expect(copied, 'https://example.com/x');
      await t.tap(find.text('Open link'));
      await t.pumpAndSettle();
      expect(opened.single.host, 'example.com');
      await t.tap(find.text('Close'));
      await t.pumpAndSettle();

      showReceivedText(
        ctx,
        from: 'Phone',
        body: 'just words',
        openLink: (_) async => true,
      );
      await t.pumpAndSettle();
      expect(find.text('Open link'), findsNothing);
    });
  });

  group('send screen', () {
    late N a;
    late N b;
    setUp(() async {
      a = await N.create('a');
      b = await N.create('b');
      await pair(a, b);
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    testWidgets('E1: the Send screen has a Text tab with the 8 KB limit', (
      t,
    ) async {
      t.view.physicalSize = const Size(420, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final s = (await t.runAsync(SettingsController.load))!;
      await t.pumpWidget(
        AppScope(
          engine: a.engine,
          settings: s,
          child: UiEnv(
            animations: false,
            readPlatform: false,
            child: MaterialApp(
              home: Scaffold(body: FilesScreen(isDesktop: false)),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Text'));
      await t.pumpAndSettle();
      expect(find.text('1. Text or link'), findsOneWidget);
      Finder button() => find.byKey(const ValueKey('send-button'));
      bool enabled() =>
          t
              .widget<ButtonStyleButton>(
                find
                    .descendant(
                      of: button(),
                      matching: find.byWidgetPredicate(
                        (w) => w is ButtonStyleButton,
                      ),
                      matchRoot: true,
                    )
                    .first,
              )
              .onPressed !=
          null;
      expect(enabled(), isFalse, reason: 'nothing typed');
      await t.enterText(find.byKey(const ValueKey('send-text-field')), 'hi');
      await t.pumpAndSettle();
      expect(enabled(), isTrue);
      await t.enterText(
        find.byKey(const ValueKey('send-text-field')),
        'x' * 9000,
      );
      await t.pumpAndSettle();
      expect(find.textContaining('8 KB'), findsOneWidget);
      expect(enabled(), isFalse);
    });
  });
}
