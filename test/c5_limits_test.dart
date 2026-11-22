// C5 (0.11.4): limits on offers (8 TiB per file, 16 TiB in total) and on
// kept resume data (5 per device, at most half the free space).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/resume_store.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:path/path.dart' as p;

import 'loopback_test.dart' show Node, waitDone, pair;

const tib = 1024 * 1024 * 1024 * 1024;

/// Claims a size; never read (the offer is declined first).
class _Huge extends SendSource {
  _Huge(this.name, this.size);
  @override
  final String name;
  @override
  final int size;
  @override
  Stream<List<int>> open() => const Stream.empty();
}

void main() {
  group('offers', () {
    late Node a;
    late Node b;
    setUp(() async {
      a = await Node.create('a', useLanes: false);
      b = await Node.create('b', useLanes: false);
      await pair(a, b);
      b.asked.clear();
    });
    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    test(
      'C5: a file above 8 TiB is declined (bad_offer), nothing asked',
      () async {
        final j = await waitDone(
          await a.engine.send(a.engine.trustedDevices.single, [
            _Huge('big.iso', 8 * tib + 1),
          ]),
        );
        expect(j.state, JobState.failed);
        expect(j.message, contains('too big'));
        expect(b.asked, isEmpty);
      },
    );

    test('C5: a total above 16 TiB is declined', () async {
      final j = await waitDone(
        await a.engine.send(a.engine.trustedDevices.single, [
          _Huge('a.iso', 6 * tib),
          _Huge('b.iso', 6 * tib),
          _Huge('c.iso', 6 * tib),
        ]),
      );
      expect(j.state, JobState.failed);
      expect(b.asked, isEmpty);
    });

    test('C5: size check helper: limits and overflow', () {
      expect(offerSizesOk([8 * tib]), isTrue);
      expect(offerSizesOk([8 * tib, 8 * tib]), isTrue);
      expect(offerSizesOk([8 * tib + 1]), isFalse);
      expect(offerSizesOk([8 * tib, 8 * tib, 1]), isFalse);
      expect(offerSizesOk([-1]), isFalse);
      // Would wrap around in 64 bits if added naively.
      expect(offerSizesOk([0x7fffffffffffffff, 0x7fffffffffffffff]), isFalse);
    });
  });

  group('resume store', () {
    late Directory dir;
    late ResumeStore store;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('isekai_c5');
      store = ResumeStore(Directory(p.join(dir.path, 'r')));
    });
    tearDown(() => dir.delete(recursive: true));

    String tid(int i) => i.toRadixString(16).padLeft(16, '0');

    Future<ResumeState> make(
      String fp,
      int i, {
      int part = 0,
      int? free,
    }) async {
      final s = await store.create(fp, tid(i), [
        ('f$i.bin', 1 << 30),
      ], freeBytes: free);
      if (part > 0) {
        s.partialIndex = 0;
        await store.save(s);
        await store.partFile(s.key).writeAsBytes(List.filled(part, 1));
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return s;
    }

    test('C5: a 6th resume state of one device removes the oldest', () async {
      for (var i = 1; i <= 5; i++) {
        await make('fpA', i);
      }
      await make('fpB', 99); // another device does not count
      expect(await store.load('fpA', tid(1)), isNotNull);
      await make('fpA', 6);
      expect(await store.load('fpA', tid(1)), isNull, reason: 'oldest gone');
      for (var i = 2; i <= 6; i++) {
        expect(await store.load('fpA', tid(i)), isNotNull);
      }
      expect(await store.load('fpB', tid(99)), isNotNull);
    });

    test(
      'C5: partial data above half the free space: oldest go first',
      () async {
        await make('fpA', 1, part: 4000);
        await make('fpB', 2, part: 4000);
        await make('fpC', 3, part: 4000);
        // 12000 bytes kept; half of 18000 free = 9000: drop the oldest one.
        await make('fpD', 4, free: 18000);
        expect(await store.load('fpA', tid(1)), isNull);
        expect(
          store.partFile(ResumeStore.keyFor('fpA', tid(1))).existsSync(),
          isFalse,
        );
        expect(await store.load('fpB', tid(2)), isNotNull);
        expect(await store.load('fpC', tid(3)), isNotNull);
      },
    );
  });
}
