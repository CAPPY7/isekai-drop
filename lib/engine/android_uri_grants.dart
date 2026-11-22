// C4 (0.11.4): picked Android files keep their read access after a restart
// (the Kotlin side takes a persistable URI permission when picking). This
// gives that access back once no saved or running send needs the file.
import 'package:flutter/services.dart';

class AndroidUriGrants {
  AndroidUriGrants(this.channel);
  final MethodChannel channel;

  static List<String> _uris(Iterable<Map<String, dynamic>> sources) => [
    for (final s in sources)
      if (s['k'] == 'uri' && s['uri'] is String) s['uri'] as String,
  ];

  /// [release]: encoded sources that are no longer needed. [keep]: encoded
  /// sources still needed (a folder's access is kept while any file of it
  /// is still needed; Kotlin compares the folder).
  Future<void> release(
    List<Map<String, dynamic>> release,
    List<Map<String, dynamic>> keep,
  ) async {
    final keepUris = _uris(keep).toSet();
    final rel = _uris(release).where((u) => !keepUris.contains(u)).toSet();
    if (rel.isEmpty) return;
    await channel.invokeMethod<void>('releaseUris', {
      'release': rel.toList(),
      'keep': keepUris.toList(),
    });
  }
}
