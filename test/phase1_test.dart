import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/transfer_engine.dart';

void main() {
  testWidgets('shows the Phase 1 headline on a phone-size screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const IsekaiDropApp(engine: Phase1EngineStub()));
    expect(find.text('Isekai Drop - Phase 1 works'), findsOneWidget);
    expect(find.textContaining('not built yet'), findsOneWidget);
  });

  testWidgets('shows the Phase 1 headline on a desktop-size screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const IsekaiDropApp(engine: Phase1EngineStub()));
    expect(find.text('Isekai Drop - Phase 1 works'), findsOneWidget);
  });

  test('Phase 1 engine stub is honest about not being implemented', () {
    const engine = Phase1EngineStub();
    expect(engine.status, EngineStatus.notImplemented);
    expect(engine.version, 'phase1-stub');
  });
}
