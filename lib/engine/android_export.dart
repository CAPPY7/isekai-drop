import 'package:flutter/services.dart';

/// Audit #6: on Android 9 and older the app must hold
/// WRITE_EXTERNAL_STORAGE to save into the public Downloads folder. This
/// asks once (native side answers true at once on Android 10+) before the
/// first save. If the user says no, files go to the app's own folder and the
/// native side reports that real location.
class AndroidExporter {
  AndroidExporter(this.channel);
  final MethodChannel channel;
  Future<bool>? _gate;

  Future<bool> _ensure() => _gate ??= channel
      .invokeMethod<bool>('ensureLegacyStorage')
      .then((v) => v ?? false, onError: (_) => false);

  Future<String> export(String path, String name, String sub) async {
    await _ensure();
    return (await channel.invokeMethod<String>('exportToDownloads', {
      'path': path,
      'name': name,
      'sub': sub,
    }))!;
  }

  Future<bool> folderExists(String name) async {
    await _ensure();
    return await channel.invokeMethod<bool>('folderExists', {'name': name}) ==
        true;
  }
}
