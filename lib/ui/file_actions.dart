// 0.11.0 (spec C13): "Open" and "Show in folder" after receiving, on
// desktops only (the saved path is a real file there). Android saves
// through MediaStore and gets a display path, so these are not offered.
import 'dart:io';

bool get canOpenSavedFiles =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Opens [path] with the default app. Returns false if it could not start.
Future<bool> openSavedFile(String path) async {
  try {
    if (!File(path).existsSync()) return false;
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [path], runInShell: false);
    } else if (Platform.isMacOS) {
      await Process.start('open', [path]);
    } else {
      await Process.start('xdg-open', [path]);
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Shows the folder holding [path] (the file is selected where possible).
Future<bool> showSavedInFolder(String path) async {
  try {
    final f = File(path);
    if (!f.existsSync()) return false;
    if (Platform.isWindows) {
      await Process.start('explorer.exe', ['/select,', path]);
    } else if (Platform.isMacOS) {
      await Process.start('open', ['-R', path]);
    } else {
      await Process.start('xdg-open', [f.parent.path]);
    }
    return true;
  } catch (_) {
    return false;
  }
}
