// A4 (0.11.2): the old key file is overwritten with zeros BEFORE it is
// truncated and deleted.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/key_migration.dart';
import 'package:path/path.dart' as p;

void main() {
  test('A4: file content is zeros (same length) after the overwrite, before truncate and delete', () async {
    final dir = await Directory.systemTemp.createTemp('isekai_a4');
    addTearDown(() => dir.delete(recursive: true));
    final f = File(p.join(dir.path, 'identity_fallback.json'));
    const secret = '{"key":"PRIVATE KEY DATA 1234567890"}';
    await f.writeAsString(secret);
    List<int>? seen;
    await secureDelete(
      f,
      afterOverwrite: (file) async => seen = await file.readAsBytes(),
    );
    expect(seen, isNotNull);
    expect(seen!.length, secret.length, reason: 'overwritten, not truncated');
    expect(seen!.every((b) => b == 0), isTrue);
    expect(await f.exists(), isFalse);
  });

  test('A4: keeps the best-effort-on-flash comment', () {
    final src = File('lib/engine/core/key_migration.dart').readAsStringSync();
    expect(src, contains('best effort'));
  });
}
