// Phase B (0.11.3): checks on the GitHub Actions setup. Plain text checks
// (no YAML package needed); the real proof is the green runs on GitHub.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  group('B2 publishing waits for CI', () {
    const ciCall =
        '  ci:\n'
        '    name: CI (analyze + test)\n'
        '    uses: ./.github/workflows/ci.yml\n'
        '    permissions:\n'
        '      contents: read\n';
    for (final f in ['android.yml', 'windows.yml', 'macos.yml', 'ios.yml']) {
      test('$f calls ci.yml and its publish job needs it', () {
        final s = wf(f);
        expect(s, contains(ciCall));
        final pub = s.substring(s.indexOf('\n  publish:\n'));
        expect(pub, contains('    needs: [build, ci]\n'));
      });
    }

    test('linux.yml (no publish job): the build waits for CI', () {
      final s = wf('linux.yml');
      expect(s, contains(ciCall));
      expect(s, contains('  build:\n    needs: ci\n'));
    });

    test('android.yml runs the tests once (in ci.yml), not again in build', () {
      final s = wf('android.yml');
      expect(s.contains('run: flutter analyze'), isFalse);
      expect(s.contains('run: flutter test'), isFalse);
    });

    test('android.yml signing steps are unchanged', () {
      final s = wf('android.yml');
      final a = s.indexOf('      # RELEASE KEY (0.11.1)');
      const end = '        run: rm -f "\$RUNNER_TEMP/release.p12"\n';
      final b = s.indexOf(end) + end.length;
      expect(a, greaterThan(0));
      expect(
        sha256.convert(utf8.encode(s.substring(a, b))).toString(),
        '6a6b725e215577f5e53701a7e23c7964307aa89f6f8aa4625b0252f99de18eb0',
      );
    });
  });
}
