// E2 (0.12.1): English, Hindi and Kannada screens. Hindi and Kannada are
// assistant translations: every one is marked as needing a native-speaker
// check. Missing keys fall back to English.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/history_store.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/screens/about_screen.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

/// Screens whose texts all come from the .arb files.
const localized = [
  'lib/ui/shell.dart',
  'lib/ui/screens/home_screen.dart',
  'lib/ui/screens/files_screen.dart',
  'lib/ui/screens/history_screen.dart',
  'lib/ui/screens/settings_screen.dart',
  'lib/ui/screens/about_screen.dart',
  'lib/ui/screens/onboarding_screen.dart',
  'lib/ui/notification_ask.dart',
  'lib/ui/received_text.dart',
];

final vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  group('settings', () {
    test('E2: schema 4 adds the language (System); choice is saved', () async {
      SharedPreferences.setMockInitialValues({'settings_schema_version': 3});
      final s = await SettingsController.load();
      expect(SettingsController.schemaVersion, 4);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('settings_schema_version'), 4);
      expect(s.language, 'system');
      expect(s.locale, isNull);
      await s.setLanguage('kn');
      expect(s.language, 'kn');
      expect(s.locale, const Locale('kn'));
      await s.setLanguage('fr'); // not offered: ignored
      expect(s.language, 'kn');
      final again = await SettingsController.load();
      expect(again.language, 'kn');
    });
  });

  group('arb files', () {
    final en = arb('en');
    final keys = en.keys.where((k) => !k.startsWith('@')).toSet();
    test('E2: a real set of texts', () {
      expect(keys.length, greaterThan(150));
    });
    for (final code in ['hi', 'kn']) {
      test('E2: $code: every text is marked for a native-speaker check', () {
        final m = arb(code);
        expect(m['@@locale'], code);
        expect(
          '${m['@@x-review']}',
          contains('NOT reviewed by a native speaker'),
        );
        final own = m.keys.where((k) => !k.startsWith('@')).toList();
        expect(own, isNotEmpty);
        for (final k in own) {
          expect(keys, contains(k), reason: '$code has unknown key $k');
          expect(
            '${(m['@$k'] as Map?)?['description']}',
            contains('NEEDS NATIVE-SPEAKER REVIEW'),
            reason: '$code $k',
          );
        }
      });
      test('E2: $code: same placeholders as English', () {
        final m = arb(code);
        final ph = RegExp(r'\{(\w+)\}');
        for (final k in m.keys.where((k) => !k.startsWith('@'))) {
          final want = ph.allMatches(en[k] as String).map((x) => x[1]).toSet();
          final got = ph.allMatches(m[k] as String).map((x) => x[1]).toSet();
          expect(got, want, reason: '$code $k');
        }
      });
    }
  });

  test('E2: localized screens have no hard-coded English text', () {
    final bad = RegExp(
      r"""(Text\(\s*'[A-Za-z]|(title|label|message|text|info|summary|hintText|labelText|tooltip|subtitle|semanticLabel|content):\s*'[A-Za-z])""",
    );
    for (final f in localized) {
      final lines = File(f).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        expect(
          bad.hasMatch(lines[i]),
          isFalse,
          reason: '$f:${i + 1}: ${lines[i].trim()}',
        );
      }
    }
  });

  group('screens', () {
    late Directory dir;
    late IsekaiEngine engine;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('isekai_e2');
      final store = TrustStore(File(p.join(dir.path, 't.json')));
      await store.load();
      engine = IsekaiEngine(
        identity: Identity.generate(),
        trust: store,
        history: HistoryStore(File(p.join(dir.path, 'h.json'))),
        deviceName: () => 'Phone',
        platformName: 'android',
        tempDir: Directory(p.join(dir.path, 'in')),
        finalizer: directoryFinalizer(Directory(p.join(dir.path, 'in'))),
        enableDiscovery: false,
      );
    });
    tearDown(() => dir.delete(recursive: true));

    testWidgets(
      'E2: picking Hindi in Settings saves it and changes the screens',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final s = (await t.runAsync(SettingsController.load))!;
        await t.runAsync(() => s.setLanguage('en'));
        await t.pumpWidget(
          IsekaiDropApp(
            engine: engine,
            settings: s,
            showOnboarding: false,
            animations: false,
            readPlatform: false,
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Settings').last);
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('settings-language')));
        await t.pumpAndSettle();
        await t.tap(find.text('हिन्दी (Hindi)').last);
        await t.pumpAndSettle();
        expect(s.language, 'hi');
        final prefs = (await t.runAsync(SharedPreferences.getInstance))!;
        expect(prefs.getString('language'), 'hi');
        expect(find.text('सेटिंग्स'), findsWidgets);
        expect(find.text('Settings'), findsNothing);
      },
    );

    const expectNav = {'en': 'Send', 'hi': 'भेजें', 'kn': 'ಕಳುಹಿಸಿ'};

    for (final code in ['en', 'hi', 'kn']) {
      testWidgets('E2: $code: every tab and About at 320 dp, 200% text', (
        t,
      ) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final s = (await t.runAsync(SettingsController.load))!;
        await t.runAsync(() => s.setLanguage(code));
        await t.pumpWidget(
          IsekaiDropApp(
            engine: engine,
            settings: s,
            showOnboarding: false,
            animations: false,
            readPlatform: false,
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        expect(find.text(expectNav[code]!), findsWidgets);
        for (final tab in [1, 2, 3, 4, 0]) {
          await t.tap(find.byType(NavigationDestination).at(tab));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$code tab $tab');
        }
        await t.tap(find.byType(NavigationDestination).at(4));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.byKey(const Key('settings-version')),
          200,
          scrollable: vertical.first,
        );
        await t.ensureVisible(find.byKey(const Key('settings-version')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const Key('settings-version')));
        await t.pumpAndSettle();
        expect(find.byType(AboutScreen), findsOneWidget);
        expect(t.takeException(), isNull, reason: '$code About');
        await t.scrollUntilVisible(
          find.byKey(const ValueKey('about-licences')),
          300,
          scrollable: find
              .descendant(of: find.byType(AboutScreen), matching: vertical)
              .first,
        );
        expect(t.takeException(), isNull, reason: '$code About end');
      });

      testWidgets('E2: $code: first-run intro at 320 dp, 200% text', (t) async {
        t.view.physicalSize = const Size(320, 640);
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        SharedPreferences.setMockInitialValues({});
        final s = (await t.runAsync(SettingsController.load))!;
        await t.runAsync(() => s.setLanguage(code));
        await t.pumpWidget(
          IsekaiDropApp(
            engine: engine,
            settings: s,
            animations: false,
            readPlatform: false,
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  });
}
