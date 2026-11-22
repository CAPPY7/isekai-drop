// 0.11.2: "phone to phone not working" after a reinstall. One device gets a
// new key while the other still pins the old one. Real TLS over localhost.
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/discovery.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/platform_engine.dart' show ownKeyChangedNote;
import 'package:path/path.dart' as p;

import 'loopback_test.dart' show Node, waitDone, randomFile, hashOf;

Announcement annOf(Node n, String name) => Announcement(
  deviceId: n.engine.identity.deviceId,
  name: name,
  platform: 'linux',
  port: n.port,
  fingerprint: n.engine.myFingerprint,
  host: '127.0.0.1',
  seenAt: DateTime.now(),
);

void main() {
  late Node a;
  late Node b;
  late Node a2;
  late Directory files;
  setUp(() async {
    a = await Node.create('Alice');
    b = await Node.create('Bob');
    files = await Directory.systemTemp.createTemp('isekai_repair');
    await a.engine.quickPair('127.0.0.1', b.port);
    b.asked.clear();
    // Alice "reinstalled": new key and id, but her old list still has Bob
    // (as after a restored Android backup).
    a2 = await Node.create('Alice');
    final bobOnA = a.engine.trustedDevices.single;
    await a2.engine.trust.addTrusted(
      deviceId: bobOnA.deviceId,
      name: bobOnA.name,
      platform: bobOnA.platform,
      certPem: bobOnA.certPem,
      host: '127.0.0.1',
      port: b.port,
      verified: false,
    );
  });
  tearDown(() async {
    await a.dispose();
    await a2.dispose();
    await b.dispose();
    await files.delete(recursive: true);
  });

  test('new key on the sender: send fails at the answer stage with a '
      'clear text and needsRepair; the receiver shows "pair again"', () async {
    b.engine.debugFound(annOf(a2, 'Alice'));
    final near = b.engine.nearby.single;
    expect(near.trusted, isNull);
    expect(near.looksLikePaired, 'Alice');
    expect(near.needsRepair, isTrue);

    final f = await randomFile(files, 'x.bin', 300 * 1024);
    final job = await waitDone(
      await a2.engine.send(
        a2.engine.trustedDevices.single,
        [FileSendSource(f)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(job.state, JobState.failed);
    expect(job.needsRepair, isTrue);
    expect(job.message, contains('reinstalled or reset'));
    expect(b.asked, isEmpty, reason: 'never asks or re-trusts silently');
    for (var i = 0; i < 50 && b.engine.rejectedPeer == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(b.engine.rejectedPeer?.pairedName, 'Alice');
    // Old key still the only one trusted on Bob.
    expect(b.engine.trustedDevices.single.fingerprint, a.engine.myFingerprint);
  });

  test('Forget and pair again: one question on the receiver saying it '
      'replaces the old pairing; then the file arrives', () async {
    a2.engine.debugFound(annOf(b, 'Bob'));
    final f = await randomFile(files, 'y.bin', 2 * 1024 * 1024 + 5);
    final failed = await waitDone(
      await a2.engine.send(
        a2.engine.trustedDevices.single,
        [FileSendSource(f)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    expect(failed.needsRepair, isTrue);
    final job = await waitDone(
      await a2.engine.forgetAndPairAgain(
        failed,
        confirmCode: (_) async => true,
      ),
    );
    expect(job.state, JobState.completed, reason: job.message);
    expect(b.asked.length, 1);
    expect(b.asked.single.kind, RequestKind.pairing);
    expect(b.asked.single.replacesName, 'Alice');
    expect(await hashOf(File(p.join(b.inbox.path, 'y.bin'))), await hashOf(f));
    // Old Alice pairing replaced, not kept next to the new one.
    expect(b.engine.trustedDevices.length, 1);
    expect(b.engine.trustedDevices.single.fingerprint, a2.engine.myFingerprint);
  });

  test('declined re-pair keeps the receiver unchanged', () async {
    a2.engine.debugFound(annOf(b, 'Bob'));
    b.approve = false;
    final f = await randomFile(files, 'z.bin', 1000);
    final failed = await waitDone(
      await a2.engine.send(
        a2.engine.trustedDevices.single,
        [FileSendSource(f)],
        host: '127.0.0.1',
        port: b.port,
      ),
    );
    await expectLater(
      a2.engine.forgetAndPairAgain(failed, confirmCode: (_) async => true),
      throwsA(isA<PairingException>()),
    );
    expect(b.engine.trustedDevices.single.fingerprint, a.engine.myFingerprint);
  });

  test('a paired device id showing another key: Needs pairing again', () {
    final other = Identity.generate(deviceId: a.engine.identity.deviceId);
    b.engine.debugFound(
      Announcement(
        deviceId: other.deviceId,
        name: 'Alice',
        platform: 'linux',
        port: 1,
        fingerprint: other.fingerprint,
        host: '127.0.0.9',
        seenAt: DateTime.now(),
      ),
    );
    final n = b.engine.nearby.single;
    expect(n.fingerprintMismatch, isTrue);
    expect(n.needsRepair, isTrue);
  });

  test('keyRefusalLikely and ownKeyChangedNote', () {
    expect(keyRefusalLikely('answer', 'connection_closed'), isTrue);
    expect(keyRefusalLikely('answer', 'timeout'), isFalse);
    expect(keyRefusalLikely('connect', 'tls_handshake_failed'), isTrue);
    expect(keyRefusalLikely('connect', 'connect_refused'), isFalse);
    expect(keyRefusalLikely('transfer', 'connection_closed'), isFalse);
    expect(
      ownKeyChangedNote(lastFingerprint: '', fingerprint: 'x', pairedCount: 2),
      isNull,
    );
    expect(
      ownKeyChangedNote(lastFingerprint: 'x', fingerprint: 'x', pairedCount: 2),
      isNull,
    );
    expect(
      ownKeyChangedNote(lastFingerprint: 'y', fingerprint: 'x', pairedCount: 0),
      isNull,
    );
    expect(
      ownKeyChangedNote(lastFingerprint: 'y', fingerprint: 'x', pairedCount: 1),
      contains('NEW key'),
    );
  });

  test('certificates are valid from 2 days back (clock skew)', () {
    final id = Identity.generate();
    final c = X509Utils.x509CertificateFromPem(id.certPem);
    final from = c.tbsCertificate!.validity.notBefore;
    expect(
      from.isBefore(DateTime.now().subtract(const Duration(days: 1))),
      isTrue,
    );
  });
}
