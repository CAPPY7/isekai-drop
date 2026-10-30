// 0.10.1: the Diagnostics Speed test card renders. The full run is covered
// at engine level by speed_engine_test.dart (real sockets do not mix well
// with the widget test fake clock).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/ui/widgets/speed_test_card.dart';

import 'loopback_test.dart' show Node;

void main() {
  testWidgets('no paired device: asks to pair first', (tester) async {
    final a = (await tester.runAsync(() => Node.create('CardA')))!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SpeedTestCard(engine: a.engine)),
        ),
      ),
    );
    expect(find.text('Speed test'), findsOneWidget);
    expect(find.text('Pair a device first.'), findsOneWidget);
    await tester.runAsync(a.dispose);
  });
}
