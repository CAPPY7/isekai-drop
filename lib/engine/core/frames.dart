import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Wire framing inside the TLS connection:
/// [1 byte type][4 bytes big-endian length][payload].
/// TLS 1.3 provides encryption and tamper protection; framing only splits
/// messages. Control messages are JSON, file bytes are DATA frames.
const int frameJson = 1;
const int frameData = 2;
const int maxFrameLength = 2 * 1024 * 1024;

Uint8List encodeFrame(int type, List<int> payload) {
  final out = Uint8List(5 + payload.length);
  out[0] = type;
  ByteData.sublistView(out).setUint32(1, payload.length);
  out.setRange(5, out.length, payload);
  return out;
}

Uint8List jsonFrame(Map<String, Object?> message) =>
    encodeFrame(frameJson, utf8.encode(jsonEncode(message)));

class Frame {
  Frame(this.type, this.payload);

  final int type;
  final Uint8List payload;

  bool get isJson => type == frameJson;

  Map<String, dynamic> get json {
    if (!isJson) throw const FormatException('Expected a control message');
    final v = jsonDecode(utf8.decode(payload));
    if (v is! Map<String, dynamic>) throw const FormatException('Bad message');
    return v;
  }

  String get messageType => (json['t'] as String?) ?? '';
}

/// Reads frames one at a time. Reading pauses the socket between frames,
/// which gives natural back-pressure (the sender cannot flood memory).
class FrameReader {
  FrameReader(Stream<Uint8List> stream) : _it = StreamIterator(stream);

  final StreamIterator<Uint8List> _it;
  Uint8List _carry = Uint8List(0);

  Future<Uint8List> _read(int n) async {
    if (_carry.length >= n) {
      final out = Uint8List.sublistView(_carry, 0, n);
      _carry = Uint8List.sublistView(_carry, n);
      return out;
    }
    final b = BytesBuilder(copy: false)..add(_carry);
    var have = _carry.length;
    while (have < n) {
      if (!await _it.moveNext()) {
        throw const SocketException('Connection closed');
      }
      b.add(_it.current);
      have += _it.current.length;
    }
    final all = b.takeBytes();
    _carry = Uint8List.sublistView(all, n);
    return Uint8List.sublistView(all, 0, n);
  }

  Future<Frame> next([Duration timeout = const Duration(seconds: 60)]) async {
    Future<Frame> read() async {
      final h = await _read(5);
      final type = h[0];
      final len = ByteData.sublistView(h).getUint32(1);
      if (type != frameJson && type != frameData) {
        throw const FormatException('Unknown frame type');
      }
      if (len > maxFrameLength) throw const FormatException('Frame too large');
      final p = len == 0 ? Uint8List(0) : await _read(len);
      return Frame(type, p);
    }

    return read().timeout(timeout);
  }

  /// Next frame, which must be a JSON control message.
  Future<Map<String, dynamic>> nextJson([
    Duration timeout = const Duration(seconds: 60),
  ]) async => (await next(timeout)).json;

  Future<void> cancel() => _it.cancel();
}
