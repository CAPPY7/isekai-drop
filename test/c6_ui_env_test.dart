// C6 (0.11.4): no hidden "am I under flutter test?" checks in the app.
// Animations, platform reads and the first-run intro are constructor
// parameters (UiEnv / IsekaiDropApp); tests pass them.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/platform_engine.dart' show ConnectionInfo;
import 'package:isekaidrop/ui/ui_env.dart';
import 'package:isekaidrop/ui/widgets/radar.dart';
import 'package:isekaidrop/ui/widgets/wifi_band.dart';

void main() {
  test('C6: lib/ never reads FLUTTER_TEST', () {
    final hits = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            f.readAsStringSync().contains('FLUTTER_TEST'))
          f.path,
    ];
    expect(hits, isEmpty);
  });

  testWidgets('C6: the radar moves by default (the app)', (t) async {
    await t.pumpWidget(const MaterialApp(home: SearchingRadar()));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(AnimatedBuilder), findsWidgets);
    expect(t.hasRunningAnimations, isTrue);
  });

  testWidgets('C6: UiEnv(animations: false) keeps it still', (t) async {
    await t.pumpWidget(
      const UiEnv(
        animations: false,
        readPlatform: false,
        child: MaterialApp(home: SearchingRadar()),
      ),
    );
    await t.pumpAndSettle();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('C6: network line reads the platform only when allowed', (
    t,
  ) async {
    var calls = 0;
    Future<ConnectionInfo> load() async {
      calls++;
      return ConnectionInfo(method: 'Wi-Fi network', frequencyMhz: 5180);
    }

    await t.pumpWidget(
      UiEnv(
        animations: false,
        readPlatform: false,
        child: MaterialApp(home: NetworkStatusLine(platformLoad: load)),
      ),
    );
    await t.pumpAndSettle();
    expect(calls, 0);
    await t.pumpWidget(
      UiEnv(
        animations: false,
        readPlatform: true,
        child: MaterialApp(
          home: NetworkStatusLine(key: UniqueKey(), platformLoad: load),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(calls, 1);
  });
}
