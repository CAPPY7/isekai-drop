// 0.11.4 (C1): write received files straight into their final place.
//
// On Android 10 and newer the received bytes go straight into a hidden
// ("pending") Downloads item, so a big file is not written twice (once into
// the app's own folder, then copied into Downloads). The item only becomes
// visible after the SHA-256 check passed; a failed check, a storage problem
// or a cancel deletes it. Android 9 and older, and every other platform,
// keep the old path (write into the app folder, then move/copy).
import 'dart:typed_data';

import 'safe_files.dart';

/// Creates [DirectSaveTarget]s. One per platform (Android 10+ only today).
abstract class DirectSaver {
  /// False: use the old path (temp file, then the finalizer).
  bool get available;

  /// Creates a hidden item for the file at [rel] (a cleaned relative path)
  /// of [batch]. Throws when that is not possible; the caller then uses the
  /// old path for this file.
  Future<DirectSaveTarget> create(String rel, ReceiveBatch batch);

  /// Opens the hidden item [id] again (resume after a lost connection).
  /// Null if it is gone.
  Future<DirectSaveTarget?> reopen(String id);

  /// Deletes the hidden item [id] (it may be gone already).
  Future<void> delete(String id);
}

/// One file being written straight into its final place.
abstract class DirectSaveTarget {
  /// Stable id, kept in the resume state (an Android content URI).
  String get id;

  /// Bytes written so far.
  Future<int> length();

  /// Appends [block].
  Future<void> write(Uint8List block);

  /// SHA-256 (hex) of everything written, from byte 0 (native code).
  Future<String> sha256();

  /// Makes the verified file visible. Returns where it was saved.
  Future<String> publish();

  /// Keeps the hidden item for a later resume, but closes it here.
  Future<void> close();

  /// Deletes the item.
  Future<void> discard();

  /// For the background data lane: writes from that isolate, or null when
  /// this target can only be written from the main isolate.
  DirectWriterSpec? get laneWriter;
}

/// Sent to the lane isolate: opens a writer there.
abstract class DirectWriterSpec {
  Future<DirectBlockWriter> open();
}

abstract class DirectBlockWriter {
  Future<void> write(Uint8List block);
}
