// A1 (0.11.2): a key store that fails must never replace this device's key.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/app.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/identity_loader.dart';
import 'package:isekaidrop/engine/core/key_migration.dart';
import 'package:path/path.dart' as p;

class FakeSlot implements SecretSlot {
  FakeSlot({this.value, this.throwReads = 0});
  String? value;
  int throwReads;
  int reads = 0;
  int writes = 0;
  @override
  Future<String?> read() async {
    reads++;
    if (throwReads > 0) {
      throwReads--;
      throw const FileSystemException('key store busy');
    }
    return value;
  }

  @override
  Future<void> write(String v) async {
    writes++;
    value = v;
  }
}

Future<Identity> gen() async => Identity.generate();

void main() {
  const fast = Duration(milliseconds: 10);

  test('A1: key store throws once -> retried, nothing new written', () async {
    final saved = Identity.generate();
    final slot = FakeSlot(value: jsonEncode(saved.toJson()), throwReads: 1);
    final (id, created) = await loadOrCreateFromSlot(
      slot,
      generate: gen,
      retryDelay: fast,
    );
    expect(created, isFalse);
    expect(id.fingerprint, saved.fingerprint);
    expect(slot.writes, 0);
    expect(slot.reads, 2);
  });

  test(
    'A1: key store throws twice -> IdentityUnreadable, nothing written',
    () async {
      final slot = FakeSlot(throwReads: 2);
      await expectLater(
        loadOrCreateFromSlot(slot, generate: gen, retryDelay: fast),
        throwsA(isA<IdentityUnreadable>()),
      );
      expect(slot.writes, 0);
      expect(slot.value, isNull);
    },
  );

  test('A1: default retry delay is 2 seconds', () {
    expect(kIdentityRetryDelay, const Duration(seconds: 2));
  });

  test(
    'A1: key store returns null -> a new identity is created once',
    () async {
      final slot = FakeSlot();
      final (id, created) = await loadOrCreateFromSlot(
        slot,
        generate: gen,
        retryDelay: fast,
      );
      expect(created, isTrue);
      expect(slot.writes, 1);
      expect(
        Identity.fromJson(jsonDecode(slot.value!) as Map<String, dynamic>)
            .fingerprint,
        id.fingerprint,
      );
    },
  );

  test(
    'A1: damaged saved identity -> IdentityUnreadable, not replaced',
    () async {
      final slot = FakeSlot(value: '{broken');
      await expectLater(
        loadOrCreateFromSlot(slot, generate: gen, retryDelay: fast),
        throwsA(isA<IdentityUnreadable>()),
      );
      expect(slot.writes, 0);
      expect(slot.value, '{broken');
    },
  );

  test(
    'A1: corrupted fallback file -> IdentityUnreadable, file kept',
    () async {
      final dir = await Directory.systemTemp.createTemp('isekai_a1');
      addTearDown(() => dir.delete(recursive: true));
      final f = File(p.join(dir.path, 'identity_fallback.json'));
      await f.writeAsString('not json');
      await expectLater(
        readFallbackIdentity(f),
        throwsA(isA<IdentityUnreadable>()),
      );
      expect(await f.readAsString(), 'not json');
    },
  );

  testWidgets('A1: IdentityUnreadable shows the key error screen; '
      'Create a new key asks first', (t) async {
    var retried = 0;
    var created = 0;
    await t.pumpWidget(
      StartupErrorApp(
        error: const IdentityUnreadable('corrupted_fallback'),
        onRetry: () async => retried++,
        onNewKey: () async => created++,
      ),
    );
    expect(
      find.textContaining('Your device key could not be read'),
      findsOneWidget,
    );
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(retried, 1);
    await t.tap(find.text('Create a new key'));
    await t.pumpAndSettle();
    expect(created, 0, reason: 'asks first');
    expect(find.textContaining('block this one'), findsOneWidget);
    await t.tap(find.text('Create new key'));
    await t.pumpAndSettle();
    expect(created, 1);
  });

  test('A1: manifest turns Android backup off with exclude-all rules', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(m, contains('android:allowBackup="false"'));
    expect(m, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      m,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    final dir = 'android/app/src/main/res/xml';
    final backup = File('$dir/backup_rules.xml').readAsStringSync();
    final extract = File('$dir/data_extraction_rules.xml').readAsStringSync();
    for (final d in ['root', 'file', 'database', 'sharedpref', 'external']) {
      expect(backup, contains('domain="$d"'));
      expect(
        RegExp('domain="$d"').allMatches(extract).length,
        2,
        reason: 'cloud-backup and device-transfer',
      );
    }
  });
}
