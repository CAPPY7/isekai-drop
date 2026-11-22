import 'dart:io';

/// A5 (0.11.2): writes a secret (the key fallback file) so it is never
/// readable by others, not even for a moment: create the file EMPTY, set
/// mode 600 (not on Windows, where the app folder is per-user), and only
/// then write [content]. An existing file is made private before it is
/// overwritten. [afterCreate] is a test hook called after the mode is set
/// and before anything is written.
Future<void> writePrivateFile(
  File f,
  String content, {
  Future<void> Function(File f)? afterCreate,
}) async {
  await f.parent.create(recursive: true);
  if (!await f.exists()) await f.create();
  if (!Platform.isWindows) {
    // Best effort, as before: iOS apps cannot start processes, and the
    // file is inside the app's private folder anyway.
    try {
      await Process.run('chmod', ['600', f.path]);
    } catch (_) {}
  }
  await afterCreate?.call(f);
  await f.writeAsString(content, flush: true);
}
