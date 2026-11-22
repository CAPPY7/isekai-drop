import 'dart:io';

/// Minimal key-store interface (secure storage), so the migration can be
/// tested without a real keychain.
abstract class SecretSlot {
  Future<String?> read();
  Future<void> write(String value);
}

enum MigrationResult { migrated, noFallback, conflict, failed }

/// Moves the identity from the plain fallback file into secure storage once
/// secure storage works (audit #3). Order: write, read back and compare, and
/// only then overwrite the file with zeros and delete it. If anything fails,
/// the file stays and remains the identity (so the key never changes).
Future<MigrationResult> migrateFallbackIdentity(
  File fallback,
  SecretSlot slot, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  if (!await fallback.exists()) return MigrationResult.noFallback;
  try {
    final content = await fallback.readAsString();
    final existing = await slot.read().timeout(timeout);
    if (existing != null && existing != content) {
      // Secure storage already holds a DIFFERENT identity. Don't guess;
      // keep using the file (sticky) so the device key does not change.
      return MigrationResult.conflict;
    }
    if (existing == null) await slot.write(content).timeout(timeout);
    final check = await slot.read().timeout(timeout);
    if (check != content) return MigrationResult.failed;
    await secureDelete(fallback);
    return MigrationResult.migrated;
  } catch (_) {
    return MigrationResult.failed;
  }
}

/// Overwrites a file with zeros, flushes, then deletes it. (On flash storage
/// this is best effort: the OS may keep old blocks; the file is private.)
///
/// A4 (0.11.2): the zeros go over the EXISTING bytes first (same length,
/// from position 0), are flushed, and only THEN is the file truncated and
/// deleted. Before, it was truncated first, so the old key blocks were
/// freed without being overwritten. [afterOverwrite] is a test hook called
/// between the flush and the truncate.
Future<void> secureDelete(
  File f, {
  Future<void> Function(File f)? afterOverwrite,
}) async {
  final len = await f.length();
  // FileMode.append opens read/write WITHOUT truncating; setPosition(0)
  // then writes over the existing bytes.
  final raf = await f.open(mode: FileMode.append);
  try {
    await raf.setPosition(0);
    await raf.writeFrom(List<int>.filled(len, 0));
    await raf.flush();
    await afterOverwrite?.call(f);
    await raf.truncate(0);
    await raf.flush();
  } finally {
    await raf.close();
  }
  await f.delete();
}
