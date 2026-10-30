// 0.11.0 UI spec tests: onboarding (A8), empty states (A1), Send steps
// (A2), Home network status (B10), 200% text (D17), TalkBack labels
// (D18), contrast in both themes (D16).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/history_store.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:isekaidrop/engine/platform_engine.dart' show ConnectionInfo;
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:isekaidrop/ui/app_scope.dart';
import 'package:isekaidrop/ui/screens/files_screen.dart';
import 'package:isekaidrop/ui/screens/home_screen.dart';
import 'package:isekaidrop/ui/theme/app_theme.dart';
import 'package:isekaidrop/ui/theme/design_tokens.dart';
import 'package:isekaidrop/ui/widgets/common.dart' show EmptyLine;
import 'package:isekaidrop/ui/widgets/wifi_band.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

late Directory _dir;
late IsekaiEngine _empty;
late IsekaiEngine _paired;
var _n = 0;

Future<IsekaiEngine> _engine({required bool paired}) async {
  _n++;
  final store = TrustStore(File(p.join(_dir.path, 'trust$_n.json')));
  await store.load();
  if (paired) {
    final peer = Identity.generate();
    await store.addTrusted(
      deviceId: peer.deviceId,
      name: 'Test Windows PC',
      platform: 'windows',
      certPem: peer.certPem,
    );
  }
  return IsekaiEngine(
    history: HistoryStore(File(p.join(_dir.path, 'hist$_n.json'))),
    identity: Identity.generate(),
    trust: store,
    deviceName: () => 'Test phone',
    platformName: 'android',
    tempDir: Directory(p.join(_dir.path, 'in$_n')),
    finalizer: directoryFinalizer(Directory(p.join(_dir.path, 'in$_n'))),
    enableDiscovery: false,
  );
}

void _size(WidgetTester t, Size s, {double text = 1}) {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<SettingsController> _app(
  WidgetTester t,
  IsekaiEngine e, {
  bool onboarding = false,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final s = await SettingsController.load();
  await t.pumpWidget(
    IsekaiDropApp(engine: e, settings: s, showOnboarding: onboarding),
  );
  await t.pumpAndSettle();
  return s;
}

Future<void> _scrollAll(WidgetTester t) async {
  // Drag the visible page from the middle of the screen down to its end.
  for (var i = 0; i < 10; i++) {
    await t.dragFrom(const Offset(160, 300), const Offset(0, -400));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  setUpAll(() async {
    _dir = await Directory.systemTemp.createTemp('isekai_ui0110');
  });
  tearDownAll(() => _dir.delete(recursive: true));
  setUp(() async {
    _empty = await _engine(paired: false);
    _paired = await _engine(paired: true);
  });

  group('onboarding (A8)', () {
    testWidgets('3 slides, Next, Get started, shown once', (t) async {
      _size(t, const Size(420, 900));
      final s = await _app(t, _empty, onboarding: true);
      expect(find.text('Send files to nearby devices'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('onboarding-next')));
      await t.pumpAndSettle();
      expect(find.text('Connect once with a QR code'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('onboarding-next')));
      await t.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
      await t.tap(find.text('Get started'));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(s.onboardingDone, isTrue);
    });

    testWidgets('Skip goes straight to the app; not shown again', (t) async {
      _size(t, const Size(420, 900));
      await _app(t, _empty, onboarding: true);
      await t.tap(find.byKey(const ValueKey('onboarding-skip')));
      await t.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await _app(t, _empty, onboarding: true, prefs: {'onboarding_done': true});
      expect(find.text('Send files to nearby devices'), findsNothing);
    });
  });

  group('empty states are one line (A1)', () {
    Future<void> openTab(WidgetTester t, String label) async {
      await t.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('Home and Send: "Looking for devices..." is one row', (
      t,
    ) async {
      _size(t, const Size(420, 2400));
      await _app(t, _empty);
      final home = find.ancestor(
        of: find.text('Looking for devices...'),
        matching: find.byType(EmptyLine),
      );
      expect(home, findsOneWidget);
      // One row (radar + text), not a whole card with title and message.
      expect(t.getSize(home).height, lessThan(80));
      // No empty trusted-devices card on Home.
      expect(find.text('Saved trusted devices'), findsNothing);
      await openTab(t, 'Send');
      final send = find.ancestor(
        of: find.text('Looking for devices...'),
        matching: find.byType(EmptyLine),
      );
      expect(send, findsOneWidget);
      expect(t.getSize(send).height, lessThan(80));
    });

    testWidgets('History empty is one line', (t) async {
      _size(t, const Size(420, 2400));
      await _app(t, _empty);
      await openTab(t, 'History');
      await t.pumpAndSettle();
      final f = find.ancestor(
        of: find.text('No transfers yet'),
        matching: find.byType(EmptyLine),
      );
      expect(f, findsOneWidget);
      expect(t.getSize(f).height, lessThan(80));
      expect(find.byTooltip('More about: No transfers yet'), findsOneWidget);
    });
  });

  group('Send steps (A2)', () {
    Future<void> pumpSend(WidgetTester t, List<SendSource> files) async {
      SharedPreferences.setMockInitialValues({});
      final s = await SettingsController.load();
      await t.pumpWidget(
        AppScope(
          engine: _paired,
          settings: s,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: FilesScreen(isDesktop: false, initialFiles: files),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('Send disabled until files and a device are chosen', (t) async {
      _size(t, const Size(420, 900));
      await pumpSend(t, const []);
      expect(find.text('1. Pick files'), findsOneWidget);
      expect(find.text('2. Pick a device'), findsOneWidget);
      final b = t.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('send-button')),
      );
      expect(b.onPressed, isNull);
    });

    testWidgets('with files and a device Send is enabled and named', (t) async {
      _size(t, const Size(420, 900));
      final f = File(p.join(_dir.path, 'holiday.jpg'))
        ..writeAsBytesSync(List.filled(10, 1));
      await pumpSend(t, [FileSendSource(f, size: 10)]);
      final btn = find.byKey(const ValueKey('send-button'));
      expect(t.widget<ButtonStyleButton>(btn).onPressed, isNotNull);
      expect(
        find.descendant(
          of: btn,
          matching: find.text('Send 1 file(s) to Test Windows PC'),
        ),
        findsOneWidget,
      );
      // Step 3 sits right under the list, inside the screen.
      expect(t.getRect(btn).bottom, lessThanOrEqualTo(900));
    });
  });

  testWidgets('Home network status line and its TalkBack label (B10)', (
    t,
  ) async {
    _size(t, const Size(420, 1600));
    SharedPreferences.setMockInitialValues({});
    final s = await SettingsController.load();
    await t.pumpWidget(
      AppScope(
        engine: _paired,
        settings: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: HomeScreen(
              onSend: () {},
              onConnect: () {},
              onTrusted: () {},
              networkLoad: () async =>
                  ConnectionInfo(method: 'Wi-Fi network', frequencyMhz: 5180),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Wi-Fi · 5 GHz'), findsOneWidget);
    final h = t.ensureSemantics();
    await t.pump();
    expect(find.bySemanticsLabel('Network: Wi-Fi · 5 GHz'), findsOneWidget);
    h.dispose();
  });

  test('network status texts', () {
    expect(networkStatus(ConnectionInfo(method: 'No network')).$2, isTrue);
    expect(
      networkStatus(ConnectionInfo(method: 'Cable network', ethernet: true)).$1,
      'Ethernet',
    );
    final slow = networkStatus(
      ConnectionInfo(method: 'Wi-Fi network', frequencyMhz: 2437),
    );
    expect(slow.$1, contains('2.4 GHz'));
    expect(slow.$2, isTrue);
  });

  testWidgets('TalkBack: bottom bar and switches have labels (D18)', (t) async {
    _size(t, const Size(420, 2400));
    await _app(t, _paired);
    final h = t.ensureSemantics();
    await t.pump();
    for (final l in ['Home', 'Send', 'Connect', 'History', 'Settings']) {
      expect(find.bySemanticsLabel(RegExp('^$l')), findsWidgets);
    }
    await t.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Receive files')), findsWidgets);
    h.dispose();
  });

  for (final light in [false, true]) {
    testWidgets('200% text at 320dp: every tab, no overflow (light $light)', (
      t,
    ) async {
      _size(t, const Size(320, 640), text: 2);
      await _app(t, _paired, prefs: {'theme_mode': light ? 'light' : 'dark'});
      expect(t.takeException(), isNull);
      for (final l in ['Send', 'Connect', 'History', 'Settings', 'Home']) {
        await t.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(l),
          ),
        );
        await t.pumpAndSettle();
        await _scrollAll(t);
        expect(t.takeException(), isNull, reason: 'tab $l');
      }
    });
  }

  testWidgets('theme choice "System" never wraps (D17)', (t) async {
    _size(t, const Size(320, 2400), text: 2);
    await _app(t, _paired);
    await t.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await t.pumpAndSettle();
    final sys = find.text('System');
    expect(sys, findsOneWidget);
    final line = t.getSize(sys).height;
    expect(line, lessThan(2 * 14 * 2 * 1.2), reason: 'one line only');
  });

  group('contrast (D16)', () {
    for (final light in [false, true]) {
      test('text and status colours >= 4.5:1 (light $light)', () {
        final th = light ? AppTheme.light() : AppTheme.dark();
        final cs = th.colorScheme;
        final st = th.extension<IdStatusColors>()!;
        for (final bg in [cs.surface, th.scaffoldBackgroundColor]) {
          expect(contrast(cs.onSurface, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(cs.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(cs.primary, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(st.success, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(st.warning, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(st.danger, bg), greaterThanOrEqualTo(4.5));
        }
        expect(contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(cs.onError, cs.error), greaterThanOrEqualTo(4.5));
      });
    }
  });
}
