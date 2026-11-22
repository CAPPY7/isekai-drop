// D1 (0.12.0): files shared from another Android app (Share > Isekai Drop).
// MainActivity keeps what arrived (also while the app is open) until the
// Dart side takes it with "takeShared" on the "isekai_drop/android"
// channel.
import 'package:flutter/services.dart';

import 'pick_result.dart';

/// This app's own content links (FileProvider, D4). Never sent on: another
/// app could share them back to read this app's files.
const String kOwnAuthorityPrefix = 'com.isujaykumar.isekaidrop';

/// True for a link another app may hand us: content:// only (a file://
/// link could point into this app's private folder), not our own.
bool isAcceptableSharedUri(String uri) {
  final u = Uri.tryParse(uri);
  if (u == null || u.scheme != 'content') return false;
  return !u.host.startsWith(kOwnAuthorityPrefix);
}

/// Result of "takeShared" (null = nothing shared).
PickResult parseSharedFiles(Map<Object?, Object?>? m) {
  if (m == null) return PickResult.empty;
  final ok = <Object?>[];
  var bad = (m['unreadable'] as num?)?.toInt() ?? 0;
  for (final f in (m['files'] as List? ?? const [])) {
    final uri = f is Map ? f['uri'] : null;
    if (uri is String && isAcceptableSharedUri(uri) && f['name'] is String) {
      ok.add(f);
    } else {
      bad++;
    }
  }
  final r = parseAndroidPicked(ok);
  return PickResult(r.files, r.skipped + SkippedFiles(unreadable: bad));
}

class ShareIntake {
  const ShareIntake(this.channel);
  final MethodChannel channel;

  /// Files shared since the last call (empty when none).
  Future<PickResult> take() async => parseSharedFiles(
    await channel.invokeMapMethod<Object?, Object?>('takeShared'),
  );
}
