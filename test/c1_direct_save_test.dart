// C1 (0.11.4): Android 10+ receive writes straight into a hidden Downloads
// item (no second copy). The Android side is a mocked method channel here;
// real phones are NOT TESTED.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/android_media.dart';
import 'package:isekaidrop/engine/core/direct_save.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/resume_store.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

/// Fake of the Kotlin 'isekai_drop/media' channel (MediaStore in memory).
class FakeMedia {
  FakeMedia(this.channel) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _handle);
  }
  final MethodChannel channel;
  final List<String> calls = [];
  final Map<String, BytesBuilder> items = {}; // id -> data
  final Map<String, String> where = {};
  final Set<String> visible = {};
  final Map<int, String> open = {}; // handle -> id
  var _next = 1;
  bool failCreate = false;
  bool failWrite = false;
  bool badHash = false;

  void dispose() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);

  Future<Object?> _handle(MethodCall c) async {
    calls.add(c.method);
    final a = (c.arguments as Map?) ?? const {};
    switch (c.method) {
      case 'mediaCreate':
        if (failCreate) throw PlatformException(code: 'media_failed');
        final id = 'content://media/external/downloads/${_next++}';
        items[id] = BytesBuilder();
        final sub = a['sub'] as String;
        where[id] = [
          'Downloads/Isekai Drop',
          if (sub.isNotEmpty) sub,
          a['name'] as String,
        ].join('/');
        final h = _next++;
        open[h] = id;
        return {'h': h, 'id': id};
      case 'mediaOpen':
        final id = a['id'] as String;
        if (!items.containsKey(id)) {
          throw PlatformException(code: 'not_found');
        }
        final h = _next++;
        open[h] = id;
        return {'h': h, 'size': items[id]!.length};
      case 'mediaWrite':
        if (failWrite) throw PlatformException(code: 'media_failed');
        items[open[a['h']]!]!.add(a['b'] as Uint8List);
        return null;
      case 'mediaSize':
        return items[open[a['h']]!]!.length;
      case 'mediaHash':
        if (badHash) return '00' * 32;
        return sha256.convert(items[open[a['h']]!]!.toBytes()).toString();
      case 'mediaPublish':
        final id = open.remove(a['h'])!;
        visible.add(id);
        return where[id];
      case 'mediaClose':
        open.remove(a['h']);
        return null;
      case 'mediaDelete':
        final id = a['id'] as String;
        open.removeWhere((_, v) => v == id);
        items.remove(id);
        visible.remove(id);
        return null;
    }
    throw MissingPluginException();
  }
}

class Peer {
  Peer(this.root);
  final Directory root;
  late IsekaiEngine engine;
  final List<String> finalized = [];
  int? freeBytes;
  Directory get inbox => Directory(p.join(root.path, 'inbox'));
  Directory get resumeDir => Directory(p.join(inbox.path, '.isekai-resume'));

  static Future<Peer> create(
    String name, {
    DirectSaver? saver,
    bool finalizeCopies = false,
  }) async {
    final n = Peer(await Directory.systemTemp.createTemp('isekai_c1_$name'));
    final trust = TrustStore(File(p.join(n.root.path, 'trusted.json')));
    await trust.load();
    final fin = directoryFinalizer(n.inbox);
    n.engine = IsekaiEngine(
      identity: Identity.generate(),
      trust: trust,
      deviceName: () => name,
      platformName: 'android',
      tempDir: n.inbox,
      finalizer: (t, rel, b) async {
        n.finalized.add(rel);
        return fin(t, rel, b);
      },
      port: 0,
      bindAddress: InternetAddress.loopbackIPv4,
      enableDiscovery: false,
      useLanes: false,
      resume: ResumeStore(n.resumeDir, deleteDirect: saver?.delete),
      freeSpace: (_) async => n.freeBytes,
      directSaver: saver,
      finalizeCopies: finalizeCopies,
    );
    n.engine.debugAutoDecide = (_) async => true;
    await n.engine.start();
    return n;
  }

  Future<void> dispose() async {
    await engine.stop();
    for (var i = 0; ; i++) {
      try {
        await root.delete(recursive: true);
        return;
      } on FileSystemException {
        if (i >= 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }
}

Future<TransferJob> waitJob(TransferJob j) async {
  for (var i = 0; i < 3000 && j.isActive; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return j;
}

Future<void> receiverIdle(Peer n) async {
  for (var i = 0; i < 1500 && n.engine.jobs.any((j) => j.isActive); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

Future<File> rnd(Directory d, String name, int size) async {
  await d.create(recursive: true);
  final r = Random(3);
  final f = File(p.join(d.path, name));
  await f.writeAsBytes(List<int>.generate(size, (_) => r.nextInt(256)));
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('isekai_drop/media_test');
  late FakeMedia media;
  late Peer a;
  late Peer b;
  late Directory src;

  Future<void> setUpPeers({bool saver = true, bool copies = true}) async {
    media = FakeMedia(channel);
    a = await Peer.create('a');
    b = await Peer.create(
      'b',
      saver: saver
          ? AndroidMediaSaver(
              channel,
              available: true,
              folderExists: (_) async => false,
            )
          : null,
      finalizeCopies: copies,
    );
    src = await Directory.systemTemp.createTemp('isekai_c1_src');
    final s = await a.engine.beginPairing('127.0.0.1', b.engine.listeningPort!);
    await s.confirm();
  }

  tearDown(() async {
    media.dispose();
    await a.dispose();
    await b.dispose();
    await src.delete(recursive: true);
  });

  test(
    'C1: bytes go straight into the hidden item, then it is published',
    () async {
      await setUpPeers();
      final f = await rnd(src, 'photo.jpg', 700 * 1024 + 5);
      final job = await waitJob(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(job.state, JobState.completed, reason: job.message);
      await receiverIdle(b);
      final rj = b.engine.jobs.single;
      expect(rj.state, JobState.completed, reason: rj.message);
      expect(rj.savedTo, ['Downloads/Isekai Drop/photo.jpg']);
      expect(b.finalized, isEmpty, reason: 'no second copy');
      final order = media.calls.toSet().toList();
      expect(order, ['mediaCreate', 'mediaWrite', 'mediaHash', 'mediaPublish']);
      final id = media.visible.single;
      expect(media.items[id]!.toBytes(), f.readAsBytesSync());
      expect(
        b.inbox.existsSync()
            ? b.inbox.listSync().whereType<File>().toList()
            : const [],
        isEmpty,
        reason: 'nothing written into the app folder',
      );
    },
  );

  test('C1: a storage problem deletes the hidden item', () async {
    await setUpPeers();
    media.failWrite = true;
    final f = await rnd(src, 'a.bin', 300 * 1024);
    final job = await waitJob(
      await a.engine.send(a.engine.trustedDevices.single, [FileSendSource(f)]),
    );
    expect(job.state, JobState.failed);
    await receiverIdle(b);
    expect(media.calls, contains('mediaDelete'));
    expect(media.calls, isNot(contains('mediaPublish')));
    expect(media.items, isEmpty);
  });

  test('C1: a failed checksum deletes the hidden item', () async {
    await setUpPeers();
    media.badHash = true;
    final f = await rnd(src, 'a.bin', 300 * 1024);
    final job = await waitJob(
      await a.engine.send(a.engine.trustedDevices.single, [FileSendSource(f)]),
    );
    expect(job.state, JobState.failed);
    await receiverIdle(b);
    expect(media.calls.last, 'mediaDelete');
    expect(media.items, isEmpty);
    expect(media.visible, isEmpty);
  });

  test('C1: if the item cannot be created, the old path is used', () async {
    await setUpPeers();
    media.failCreate = true;
    final f = await rnd(src, 'a.bin', 300 * 1024);
    final job = await waitJob(
      await a.engine.send(a.engine.trustedDevices.single, [FileSendSource(f)]),
    );
    expect(job.state, JobState.completed, reason: job.message);
    await receiverIdle(b);
    expect(b.finalized, ['a.bin']);
    expect(
      File(p.join(b.inbox.path, 'a.bin')).readAsBytesSync(),
      f.readAsBytesSync(),
    );
  });

  test(
    'C1: after a lost connection Retry continues in the same item',
    () async {
      await setUpPeers();
      final f = await rnd(src, 'big.bin', 3 * 1024 * 1024 + 7);
      a.engine.debugDropAfterBytes = 1024 * 1024;
      final first = await waitJob(
        await a.engine.send(a.engine.trustedDevices.single, [
          FileSendSource(f),
        ]),
      );
      expect(first.state, JobState.failed);
      await receiverIdle(b);
      expect(media.items, hasLength(1), reason: 'kept hidden for resume');
      expect(media.visible, isEmpty);
      a.engine.debugDropAfterBytes = null;
      final second = await waitJob((await a.engine.retry(first))!);
      expect(second.state, JobState.completed, reason: second.message);
      expect(second.resumedBytes, greaterThan(0));
      await receiverIdle(b);
      expect(media.calls, contains('mediaOpen'));
      final id = media.visible.single;
      expect(media.items[id]!.toBytes(), f.readAsBytesSync());
      expect(b.finalized, isEmpty);
    },
  );

  test('C1: cancel after a lost connection deletes the kept item', () async {
    await setUpPeers();
    final f = await rnd(src, 'big.bin', 3 * 1024 * 1024);
    a.engine.debugDropAfterBytes = 1024 * 1024;
    final first = await waitJob(
      await a.engine.send(a.engine.trustedDevices.single, [FileSendSource(f)]),
    );
    expect(first.state, JobState.failed);
    await receiverIdle(b);
    expect(media.items, hasLength(1));
    final store = ResumeStore(
      b.resumeDir,
      deleteDirect: (id) async {
        media.items.remove(id);
      },
    );
    final key = b.resumeDir
        .listSync()
        .map((e) => p.basename(e.path))
        .firstWhere((n) => n.endsWith('.json'));
    await store.discard(key.substring(0, key.length - 5));
    expect(media.items, isEmpty);
  });

  test('C1: the copy fallback needs 2x the remaining bytes free', () async {
    await setUpPeers(saver: false);
    const size = 400 * 1024;
    b.freeBytes = 2 * size + kFreeSpaceMargin - 1;
    final f = await rnd(src, 'a.bin', size);
    final job = await waitJob(
      await a.engine.send(a.engine.trustedDevices.single, [FileSendSource(f)]),
    );
    expect(job.state, JobState.failed);
    expect(job.message, contains('space'));
    b.freeBytes = 2 * size + kFreeSpaceMargin;
    final ok = await waitJob(
      await a.engine.send(a.engine.trustedDevices.single, [FileSendSource(f)]),
    );
    expect(ok.state, JobState.completed, reason: ok.message);
  });

  test('C1: direct writing needs only 1x free space', () async {
    await setUpPeers();
    const size = 400 * 1024;
    b.freeBytes = size + kFreeSpaceMargin;
    final f = await rnd(src, 'a.bin', size);
    final job = await waitJob(
      await a.engine.send(a.engine.trustedDevices.single, [FileSendSource(f)]),
    );
    expect(job.state, JobState.completed, reason: job.message);
  });
}
