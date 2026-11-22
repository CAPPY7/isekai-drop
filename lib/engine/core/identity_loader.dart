import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'identity.dart';
import 'key_migration.dart';

/// A1 (0.11.2): this device's key exists but could not be read (the key
/// store failed twice, or the saved data is damaged). The app must NOT make
/// a new key by itself: every paired device would then refuse this one.
/// The start screen asks the user instead (Try again / Create a new key).
class IdentityUnreadable implements Exception {
  const IdentityUnreadable(this.reason);

  /// `key_store_error`, `corrupted_saved` or `corrupted_fallback`.
  final String reason;

  @override
  String toString() => 'IdentityUnreadable($reason)';
}

/// Wait before the one retry of a failed key-store read.
const kIdentityRetryDelay = Duration(seconds: 2);

/// Parses a saved identity. Damaged data throws [IdentityUnreadable].
Identity parseSavedIdentity(String json, String reason) {
  try {
    return Identity.fromJson(jsonDecode(json) as Map<String, dynamic>);
  } catch (_) {
    throw IdentityUnreadable(reason);
  }
}

/// Reads the identity from the plain fallback file. A damaged file throws
/// [IdentityUnreadable] and is left as it is.
Future<Identity> readFallbackIdentity(File fallback) async {
  String text;
  try {
    text = await fallback.readAsString();
  } catch (_) {
    throw const IdentityUnreadable('corrupted_fallback');
  }
  return parseSavedIdentity(text, 'corrupted_fallback');
}

/// Reads the key store, retrying ONCE after [retryDelay] if it throws.
/// Returns null only when the store really has no identity. Throws
/// [IdentityUnreadable] if both reads fail.
Future<String?> readIdentityWithRetry(
  SecretSlot slot, {
  Duration timeout = const Duration(seconds: 30),
  Duration retryDelay = kIdentityRetryDelay,
}) async {
  try {
    return await slot.read().timeout(timeout);
  } catch (_) {}
  await Future<void>.delayed(retryDelay);
  try {
    return await slot.read().timeout(timeout);
  } catch (_) {
    throw const IdentityUnreadable('key_store_error');
  }
}

/// The key store failed to keep a NEW identity (write or read-back). Only
/// then may the caller use the fallback file: nothing was there before.
class IdentityNotStored implements Exception {
  const IdentityNotStored();
}

/// Loads the identity from the key store, or creates one when the store
/// returns null. Returns `(identity, created)`.
/// - read throws twice / saved data damaged: [IdentityUnreadable], nothing
///   is created or overwritten;
/// - store has nothing: a new identity is written and read back; if that
///   fails, [IdentityNotStored].
Future<(Identity, bool)> loadOrCreateFromSlot(
  SecretSlot slot, {
  required Future<Identity> Function() generate,
  Duration timeout = const Duration(seconds: 30),
  Duration retryDelay = kIdentityRetryDelay,
}) async {
  final saved = await readIdentityWithRetry(
    slot,
    timeout: timeout,
    retryDelay: retryDelay,
  );
  if (saved != null) {
    return (parseSavedIdentity(saved, 'corrupted_saved'), false);
  }
  final id = await generate();
  try {
    await slot.write(jsonEncode(id.toJson())).timeout(timeout);
    // Read back: only trust the key store if it really kept the key.
    final check = await slot.read().timeout(timeout);
    if (check == null) throw const IdentityNotStored();
  } catch (_) {
    throw const IdentityNotStored();
  }
  return (id, true);
}
