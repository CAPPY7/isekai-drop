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

  group('B3 actions pinned to commit SHAs', () {
    final files = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml'))
        .toList();
    final pinned = RegExp(
      r'^\s*(?:- )?uses: [\w.-]+/[\w./-]+@[0-9a-f]{40} # v\d+(\.\d+)*\s*$',
    );
    test('every remote action uses a full SHA with the version comment', () {
      var count = 0;
      for (final f in files) {
        for (final line in f.readAsLinesSync()) {
          if (!line.contains('uses:')) continue;
          if (line.contains('uses: ./')) continue; // our own ci.yml
          count++;
          expect(pinned.hasMatch(line), isTrue, reason: '${f.path}: $line');
        }
      }
      expect(count, greaterThan(20));
    });

    test('the pins are the SHAs looked up from each action\'s own tag', () {
      const want = {
        'actions/checkout': (
          '3d3c42e5aac5ba805825da76410c181273ba90b1',
          'v7.0.1',
        ),
        'subosito/flutter-action': (
          '1a449444c387b1966244ae4d4f8c696479add0b2',
          'v2.23.0',
        ),
        'actions/upload-artifact': (
          'cf430e030ddbb5b0abf93d22962f4752f3646cd9',
          'v7.0.2',
        ),
        'actions/download-artifact': (
          '9000827ccba6bdab643e8b6fd33ac0654aef8333',
          'v8.0.2',
        ),
        'actions/setup-java': (
          'b843ebf9b913146b38da2eaa7aeddf76074ae1ad',
          'v6.1.0',
        ),
        'softprops/action-gh-release': (
          'efb35369e0ad2afab669f228072c1b0d510eae64',
          'v3.0.3',
        ),
      };
      final use = RegExp(r'uses: ([\w.-]+/[\w.-]+)@([0-9a-f]{40}) # (v[\d.]+)');
      for (final f in files) {
        for (final m in use.allMatches(f.readAsStringSync())) {
          final w = want[m.group(1)];
          expect(w, isNotNull, reason: 'unknown action ${m.group(1)}');
          expect(
            (m.group(2), m.group(3)),
            w,
            reason: '${f.path} ${m.group(1)}',
          );
        }
      }
    });
  });

  test('B4 dependabot: github-actions and pub weekly, minor+patch grouped', () {
    final s = File('.github/dependabot.yml').readAsStringSync();
    expect(s, contains('version: 2'));
    for (final eco in ['github-actions', 'pub']) {
      final i = s.indexOf('package-ecosystem: "$eco"');
      expect(i, greaterThan(0), reason: eco);
      final next = s.indexOf('package-ecosystem:', i + 1);
      final block = s.substring(i, next < 0 ? s.length : next);
      expect(block, contains('directory: "/"'));
      expect(block, contains('interval: "weekly"'));
      expect(block, contains('groups:'));
      expect(block, contains('update-types: ["minor", "patch"]'));
    }
  });

  test('B5 docs/BRANCH_PROTECTION.md: step by step for the owner', () {
    final s = File('docs/BRANCH_PROTECTION.md').readAsStringSync();
    for (final want in [
      'Settings',
      'Rulesets',
      'Require a pull request before merging',
      'Require status checks to pass',
      'flutter analyze + flutter test',
      'Bypass list',
    ]) {
      expect(s, contains(want), reason: want);
    }
    // The check name in the doc must be the real job name in ci.yml.
    expect(wf('ci.yml'), contains('name: flutter analyze + flutter test'));
  });

  test('B6 CONNECTION_TEST.txt is gone', () {
    expect(File('CONNECTION_TEST.txt').existsSync(), isFalse);
  });
}
