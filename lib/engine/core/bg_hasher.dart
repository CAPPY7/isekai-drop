import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Audit #10: SHA-256 runs in a background isolate so the UI isolate does
/// not spend its time hashing. Chunks are handed over as
/// [TransferableTypedData] (one copy, no per-message serialisation).
/// Use one [BgHasher] per file: [add] chunks in order, then [close].
abstract class FileHasher {
  void add(List<int> chunk);
  Future<String> close();
  void dispose();
}

/// Files at or above this size are hashed in a background isolate; smaller
/// ones inline (starting an isolate costs a few milliseconds).
const int kBgHashMinBytes = 1024 * 1024;

/// Tests: force one mode. null = by size.
bool? debugForceBgHash;

Future<FileHasher> fileHasher(int size) async =>
    (debugForceBgHash ?? size >= kBgHashMinBytes)
    ? await BgHasher.start()
    : InlineHasher();

class InlineHasher implements FileHasher {
  InlineHasher() {
    _h = sha256.startChunkedConversion(_out);
  }
  final _out = _DigestSink();
  late final ByteConversionSink _h;
  @override
  void add(List<int> chunk) => _h.add(chunk);
  @override
  Future<String> close() async {
    _h.close();
    return _out.value.toString();
  }

  @override
  void dispose() {}
}

class BgHasher implements FileHasher {
  BgHasher._(this._to, this._results, this._isolate);

  final SendPort _to;
  final ReceivePort _results;
  final Isolate _isolate;

  static Future<BgHasher> start() async {
    final rp = ReceivePort();
    final iso = await Isolate.spawn(
      _main,
      rp.sendPort,
      onError: rp.sendPort,
      onExit: rp.sendPort,
      errorsAreFatal: true,
    );
    final it = StreamIterator<Object?>(rp);
    await it.moveNext();
    final to = it.current! as SendPort;
    final h = BgHasher._(to, rp, iso);
    h._it = it;
    return h;
  }

  late final StreamIterator<Object?> _it;

  @override
  void add(List<int> chunk) {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    _to.send(TransferableTypedData.fromList([bytes]));
  }

  /// Returns the hex digest and stops the isolate.
  @override
  Future<String> close() async {
    _to.send(null);
    try {
      if (!await _it.moveNext()) throw StateError('hasher stopped');
      final r = _it.current;
      if (r is! String) throw StateError('hasher failed: $r');
      return r;
    } finally {
      _done = true;
      _results.close(); // the isolate ends by itself after replying
    }
  }

  bool _done = false;

  @override
  void dispose() {
    if (_done) return;
    _done = true;
    _results.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _main(SendPort back) {
    final inbox = ReceivePort();
    back.send(inbox.sendPort);
    final out = _DigestSink();
    final h = sha256.startChunkedConversion(out);
    inbox.listen((m) {
      if (m == null) {
        h.close();
        back.send(out.value.toString());
        inbox.close();
        return;
      }
      h.add((m as TransferableTypedData).materialize().asUint8List());
    });
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
