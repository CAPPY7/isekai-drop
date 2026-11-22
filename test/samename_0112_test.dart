// 0.11.2 root cause of "phone to phone fails": every certificate had the
// same subject, and a receiver that trusts two devices found only the first
// one by subject, refusing the other ("refused this device's key").
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/platform_engine.dart' show keyUpgradedNote;

import 'loopback_test.dart' show Node, waitDone, randomFile;

Future<List<JobState>> sendFromBoth({required bool legacy}) async {
  Identity? id() => legacy ? Identity.generate(legacySubject: true) : null;
  final a = await Node.create('A', identity: id());
  final c = await Node.create('C', identity: id());
  final b = await Node.create('B', identity: id());
  final files = await Directory.systemTemp.createTemp('sn');
  try {
    await a.engine.quickPair('127.0.0.1', b.port);
    await c.engine.quickPair('127.0.0.1', b.port);
    final f = await randomFile(files, 'f.bin', 1000);
    final out = <JobState>[];
    for (final n in [a, c]) {
      final j = await waitDone(
        await n.engine.send(
          n.engine.trustedDevices.single,
          [FileSendSource(f)],
          host: '127.0.0.1',
          port: b.port,
        ),
      );
      out.add(j.state);
    }
    return out;
  } finally {
    await a.dispose();
    await b.dispose();
    await c.dispose();
    await files.delete(recursive: true);
  }
}

void main() {
  test('reproduces 0.11.1: a receiver trusting two pre-0.11.2 devices '
      'refuses one of them', () async {
    final r = await sendFromBoth(legacy: true);
    expect(r, contains(JobState.failed));
    expect(r, contains(JobState.completed));
  });

  test('0.11.2 keys: a receiver trusting two devices accepts both', () async {
    expect(await sendFromBoth(legacy: false), [
      JobState.completed,
      JobState.completed,
    ]);
  });

  test('subjects are unique; old ones are detected and renewed with the '
      'same device id', () {
    final a = Identity.generate();
    final b = Identity.generate();
    expect(a.hasSharedSubject, isFalse);
    expect(certSubjectIsUnique(a.certPem), isTrue);
    expect(a.certPem == b.certPem, isFalse);
    final old = Identity.generate(legacySubject: true);
    expect(old.hasSharedSubject, isTrue);
    final n = old.renewed();
    expect(n.deviceId, old.deviceId);
    expect(n.hasSharedSubject, isFalse);
    expect(n.fingerprint == old.fingerprint, isFalse);
  });

  test('upgrade note only when paired devices exist', () {
    expect(keyUpgradedNote(upgraded: true, pairedCount: 0), isNull);
    expect(keyUpgradedNote(upgraded: false, pairedCount: 3), isNull);
    expect(
      keyUpgradedNote(upgraded: true, pairedCount: 1),
      contains('NEW key'),
    );
  });
}
