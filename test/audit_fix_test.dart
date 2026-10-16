// Tests for the Phase 7 audit fixes #3-#9 (see docs/AUDIT.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/key_migration.dart';
import 'package:path/path.dart' as p;

class FakeSlot implements SecretSlot {
  String? value;
  bool dropWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    if (!dropWrites) value = v;
  }
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('isekai_fix'));
  tearDown(() => dir.delete(recursive: true));

  group('#3 fallback identity moves into secure storage', () {
    test('migrated: stored, read back, file wiped and deleted', () async {
      final f = File(p.join(dir.path, 'identity_fallback.json'));
      await f.writeAsString('{"secret":"key"}');
      final slot = FakeSlot();
      expect(await migrateFallbackIdentity(f, slot), MigrationResult.migrated);
      expect(slot.value, '{"secret":"key"}');
      expect(f.existsSync(), isFalse);
    });

    test('read-back fails: file kept', () async {
      final f = File(p.join(dir.path, 'identity_fallback.json'));
      await f.writeAsString('{"secret":"key"}');
      final slot = FakeSlot()..dropWrites = true;
      expect(await migrateFallbackIdentity(f, slot), MigrationResult.failed);
      expect(f.readAsStringSync(), '{"secret":"key"}');
    });

    test('different identity already in secure storage: file kept', () async {
      final f = File(p.join(dir.path, 'identity_fallback.json'));
      await f.writeAsString('{"secret":"A"}');
      final slot = FakeSlot()..value = '{"secret":"B"}';
      expect(await migrateFallbackIdentity(f, slot), MigrationResult.conflict);
      expect(f.existsSync(), isTrue);
      expect(slot.value, '{"secret":"B"}');
    });
  });
}
