import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/platform_engine.dart' show ConnectionInfo;
import 'package:isekaidrop/ui/widgets/wifi_band.dart';

void main() {
  test('band from frequency', () {
    expect(wifiBandLabel(2437), '2.4 GHz');
    expect(wifiBandLabel(5180), '5 GHz');
    expect(wifiBandLabel(5955), '6 GHz');
    expect(wifiBandLabel(null), isNull);
    expect(wifiBandLabel(-1), isNull);
    expect(isSlowWifiBand(2412), isTrue);
    expect(isSlowWifiBand(5745), isFalse);
    expect(isSlowWifiBand(null), isFalse);
  });

  testWidgets('2.4 GHz shows band, link speed and the 5 GHz hint', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WifiBandLine(
            load: () async => ConnectionInfo(
              method: 'Wi-Fi',
              linkMbps: 72,
              frequencyMhz: 2437,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.textContaining('Wi-Fi: 2.4 GHz, link 72 Mbps'), findsOneWidget);
    expect(find.textContaining('Use 5 GHz for best speed'), findsOneWidget);
  });

  testWidgets('5 GHz: no hint', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WifiBandLine(
            load: () async => ConnectionInfo(
              method: 'Wi-Fi',
              linkMbps: 1201,
              frequencyMhz: 5180,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.textContaining('Wi-Fi: 5 GHz, link 1201 Mbps'), findsOneWidget);
    expect(find.textContaining('Use 5 GHz'), findsNothing);
  });
}
