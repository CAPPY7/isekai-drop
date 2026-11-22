// C1 (0.11.4): Android 10+ writes received files straight into a hidden
// MediaStore Downloads item (IS_PENDING=1). The Kotlin side owns the file
// descriptor and does all writes on its own single background queue
// (Dart never reopens the descriptor: that fails on Android 11+).

import 'package:flutter/services.dart';

import 'core/direct_save.dart';
import 'core/safe_files.dart';

/// Android folder under Downloads/Isekai Drop for [rel] (without the file
/// name). A new top folder gets " (1)", " (2)" ... when it already exists.
Future<String> androidSubFolder(
  String rel,
  ReceiveBatch batch,
  Future<bool> Function(String name) folderExists,
) async {
  final parts = rel.split('/');
  if (parts.length <= 1) return '';
  final top = parts.first;
  var topName = batch.topFolders[top];
  if (topName == null) {
    topName = top;
    for (var i = 1; i < 10000; i++) {
      if (!await folderExists(topName!)) break;
      topName = '$top ($i)';
    }
    batch.topFolders[top] = topName!;
  }
  return [topName, ...parts.sublist(1, parts.length - 1)].join('/');
}

class AndroidMediaSaver implements DirectSaver {
  AndroidMediaSaver(
    this.channel, {
    required this.available,
    required this.folderExists,
  });

  final MethodChannel channel;
  @override
  final bool available;
  final Future<bool> Function(String name) folderExists;

  @override
  Future<DirectSaveTarget> create(String rel, ReceiveBatch batch) async {
    final sub = await androidSubFolder(rel, batch, folderExists);
    final m = (await channel.invokeMapMethod<String, Object?>('mediaCreate', {
      'name': rel.split('/').last,
      'sub': sub,
    }))!;
    return _MediaTarget(channel, m['h'] as int, m['id'] as String);
  }

  @override
  Future<DirectSaveTarget?> reopen(String id) async {
    try {
      final m = await channel.invokeMapMethod<String, Object?>('mediaOpen', {
        'id': id,
      });
      if (m == null) return null;
      return _MediaTarget(channel, m['h'] as int, id);
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> delete(String id) async {
    await channel.invokeMethod<void>('mediaDelete', {'id': id});
  }
}

class _MediaTarget implements DirectSaveTarget {
  _MediaTarget(this.channel, this.handle, this.id);
  final MethodChannel channel;
  final int handle;
  @override
  final String id;

  @override
  Future<int> length() async =>
      (await channel.invokeMethod<int>('mediaSize', {'h': handle}))!;

  @override
  Future<void> write(Uint8List block) =>
      channel.invokeMethod<void>('mediaWrite', {'h': handle, 'b': block});

  @override
  Future<String> sha256() async =>
      (await channel.invokeMethod<String>('mediaHash', {'h': handle}))!;

  @override
  Future<String> publish() async =>
      (await channel.invokeMethod<String>('mediaPublish', {'h': handle}))!;

  @override
  Future<void> close() =>
      channel.invokeMethod<void>('mediaClose', {'h': handle});

  @override
  Future<void> discard() =>
      channel.invokeMethod<void>('mediaDelete', {'id': id, 'h': handle});

  @override
  DirectWriterSpec? get laneWriter {
    final token = RootIsolateToken.instance;
    if (token == null) return null;
    return _LaneSpec(channel.name, handle, token);
  }
}

/// Sent to the lane isolate; writes through the same Kotlin queue.
class _LaneSpec implements DirectWriterSpec {
  _LaneSpec(this.channelName, this.handle, this.token);
  final String channelName;
  final int handle;
  final RootIsolateToken token;

  @override
  Future<DirectBlockWriter> open() async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);
    return _LaneWriter(MethodChannel(channelName), handle);
  }
}

class _LaneWriter implements DirectBlockWriter {
  _LaneWriter(this.channel, this.handle);
  final MethodChannel channel;
  final int handle;
  @override
  Future<void> write(Uint8List block) =>
      channel.invokeMethod<void>('mediaWrite', {'h': handle, 'b': block});
}
