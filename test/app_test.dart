import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/demo_engine.dart';
import 'package:isekaidrop/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(SettingsController, DemoTransferEngine)> _pump(
  WidgetTester tester, {
  Size size = const Size(420, 2400),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final settings = await SettingsController.load();
  final engine = DemoTransferEngine(latency: const Duration(milliseconds: 10));
  await tester.pumpWidget(IsekaiDropApp(engine: engine, settings: settings));
  await tester.pumpAndSettle();
  return (settings, engine);
}

ThemeMode _mode(WidgetTester t) =>
    t.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

void main() {
  testWidgets('home shows DEMO label and phone bottom bar', (tester) async {
    await _pump(tester);
    expect(find.text('DEMO - not a real transfer'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('DEMO Pixel phone'), findsWidgets);
  });

  testWidgets('desktop size uses side rail layout', (tester) async {
    await _pump(tester, size: const Size(1400, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('theme switch changes theme and is saved', (tester) async {
    final (settings, _) = await _pump(tester);
    expect(_mode(tester), ThemeMode.dark);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(_mode(tester), ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
    // A fresh load reads the saved choice.
    expect(SettingsController(prefs).themeMode, ThemeMode.light);
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(settings.themeMode, ThemeMode.system);
  });

  testWidgets('navigation between tabs and Back returns Home', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Received from DEMO Pixel phone'),
      findsOneWidget,
    );
    await tester.tap(find.text('Send').last);
    await tester.pumpAndSettle();
    expect(find.text('Pick files'), findsOneWidget);
    // Android Back button.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Isekai Drop'), findsOneWidget);
  });

  testWidgets('revoke asks first: cancel keeps, confirm removes', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Trusted devices'), findsOneWidget);
    expect(find.text('DEMO Windows desktop'), findsOneWidget);

    final revoke = find.bySemanticsLabel('Revoke DEMO Windows desktop');
    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    expect(find.text('Revoke trust?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO Windows desktop'), findsOneWidget);

    await tester.ensureVisible(revoke);
    await tester.tap(revoke);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revoke'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO Windows desktop'), findsNothing);
  });

  testWidgets('error state shows Retry and recovers', (tester) async {
    final (_, engine) = await _pump(tester);
    engine.failNextCall = true;
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    // History was preloaded by IndexedStack, so force a reload via Trusted.
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load this'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO Windows desktop'), findsOneWidget);
  });

  testWidgets('clear history asks first and shows empty state', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('History').last);
    await tester.pumpAndSettle();
    final clear = find.text('Clear history');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(find.text('Clear history?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(find.text('No transfers yet'), findsOneWidget);
  });
}
