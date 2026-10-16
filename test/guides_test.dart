import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/ui/guides/guides.dart';

void main() {
  testWidgets('every guide opens and shows numbered steps', (t) async {
    for (final g in allGuides) {
      await t.pumpWidget(MaterialApp(home: GuideScreen(guide: g)));
      expect(find.text(g.title), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(t.takeException(), isNull);
    }
  });

  test('guides A and B exist with the agreed content', () {
    expect(guidePhoneHotspot.sections.length, greaterThanOrEqualTo(3));
    expect(
      guideWindowsHotspot.sections.first.steps.first,
      contains('Mobile hotspot'),
    );
  });
}
