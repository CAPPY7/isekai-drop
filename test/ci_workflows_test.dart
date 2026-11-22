// Phase B (0.11.3): checks on the GitHub Actions setup. Plain text checks
// (no YAML package needed); the real proof is the green runs on GitHub.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String wf(String name) => File('.github/workflows/$name').readAsStringSync();

void main() {
  group('B1 ci.yml', () {
    test('exists with push main, pull_request, workflow_dispatch and '
        'workflow_call triggers', () {
      final s = wf('ci.yml');
      expect(s, contains('\non:\n'));
      expect(s, contains('  push:\n    branches: [main]'));
      expect(s, contains('\n  pull_request:'));
      expect(s, contains('\n  workflow_dispatch:'));
      expect(s, contains('\n  workflow_call:'));
    });

    test('no permissions by default; the job reads contents only', () {
      final s = wf('ci.yml');
      expect(s, contains('\npermissions: {}\n'));
      expect(s, contains('    permissions:\n      contents: read\n'));
      expect(s.contains('write'), isFalse);
    });

    test('ubuntu, Flutter 3.47.7, pub get, analyze, test', () {
      final s = wf('ci.yml');
      expect(s, contains('runs-on: ubuntu-latest'));
      expect(s, contains('actions/checkout@'));
      expect(s, contains('subosito/flutter-action@'));
      expect(s, contains('3.47.7'));
      for (final step in [
        'flutter pub get',
        'flutter analyze',
        'flutter test',
      ]) {
        expect(s, contains('run: $step'), reason: step);
      }
    });
  });
}
