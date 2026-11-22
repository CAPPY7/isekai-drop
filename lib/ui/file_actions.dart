// "Open" and "Show in folder" after receiving.
// 0.11.0 (spec C13): desktops. D4 (0.12.0): Android too (through
// MainActivity: the saved Downloads item, or the file on Android 9 and
// older through a FileProvider link, read access only).
// The commands are built by plain functions so tests can check them
// without starting a process.
import 'dart:io';

import 'package:flutter/services.dart';

/// A program and its arguments. Never run through a shell.
typedef OpenCommand = (String, List<String>);

bool _isAbsolute(String os, String path) {
  if (path.isEmpty || path.startsWith('-')) return false;
  if (os == 'windows') {
    return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) || path.startsWith(r'\\');
  }
  return path.startsWith('/');
}

String _parent(String os, String path) {
  final sep = os == 'windows' ? RegExp(r'[\\/]') : RegExp('/');
  final i = path.lastIndexOf(sep);
  if (i <= 0) return os == 'windows' ? path : '/';
  return path.substring(0, i);
}

/// Opens a file with its default app.
OpenCommand? openFileCommand(String os, String path) {
  if (!_isAbsolute(os, path)) return null;
  return switch (os) {
    'windows' => ('explorer.exe', [path]),
    'macos' => ('open', [path]),
    'linux' => ('xdg-open', [path]),
    _ => null,
  };
}

/// Shows the folder with the file selected (Linux: just the folder).
OpenCommand? showInFolderCommand(String os, String path) {
  if (!_isAbsolute(os, path)) return null;
  return switch (os) {
    'windows' => ('explorer.exe', ['/select,', path]),
    'macos' => ('open', ['-R', path]),
    'linux' => ('xdg-open', [_parent(os, path)]),
    _ => null,
  };
}

/// Opens a folder.
OpenCommand? openFolderCommand(String os, String dir) {
  if (!_isAbsolute(os, dir)) return null;
  return switch (os) {
    'windows' => ('explorer.exe', [dir]),
    'macos' => ('open', [dir]),
    'linux' => ('xdg-open', [dir]),
    _ => null,
  };
}

/// E1: opens an http/https link in the browser (only after a tap).
OpenCommand? openLinkCommand(String os, Uri link) {
  if (link.scheme != 'http' && link.scheme != 'https') return null;
  if (link.host.isEmpty) return null;
  final s = link.toString();
  return switch (os) {
    'windows' => ('rundll32.exe', ['url.dll,FileProtocolHandler', s]),
    'macos' => ('open', [s]),
    'linux' => ('xdg-open', [s]),
    _ => null,
  };
}

/// D4: Android side ("isekai_drop/android"). Only files this app saved
/// (Downloads/Isekai Drop, or an "Isekai Drop" folder on Android 9 and
/// older) are passed on; MainActivity checks again.
class AndroidFileOpener {
  const AndroidFileOpener(this.channel);
  final MethodChannel channel;

  static bool isOwnSaved(String path) {
    if (path.split('/').any((s) => s == '..' || s == '.')) return false;
    if (path.startsWith('Downloads/Isekai Drop/')) return true;
    return path.startsWith('/') && path.contains('/Isekai Drop/');
  }

  Future<bool> open(String path) async {
    if (!isOwnSaved(path)) return false;
    return await channel.invokeMethod<bool>('openReceived', {'path': path}) ??
        false;
  }

  /// E1: a web link in the browser (MainActivity checks http/https again).
  Future<bool> openLink(Uri link) async {
    if (link.scheme != 'http' && link.scheme != 'https') return false;
    return await channel.invokeMethod<bool>('openLink', {
          'url': link.toString(),
        }) ??
        false;
  }

  /// Downloads/Isekai Drop in the system file manager.
  Future<bool> openFolder() async =>
      await channel.invokeMethod<bool>('openReceiveFolder') ?? false;
}

/// What the screens use (tests replace it with [savedFileActions]).
class SavedFileActions {
  static const _android = AndroidFileOpener(
    MethodChannel('isekai_drop/android'),
  );

  bool get canOpen =>
      Platform.isWindows ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isAndroid;

  Future<bool> _run(OpenCommand? c) async {
    if (c == null) return false;
    try {
      await Process.start(c.$1, c.$2);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> open(String path) async {
    try {
      if (Platform.isAndroid) return await _android.open(path);
      if (!File(path).existsSync()) return false;
      return await _run(openFileCommand(Platform.operatingSystem, path));
    } catch (_) {
      return false;
    }
  }

  Future<bool> showInFolder(String path) async {
    try {
      if (Platform.isAndroid) return await _android.openFolder();
      if (!File(path).existsSync()) return false;
      return await _run(showInFolderCommand(Platform.operatingSystem, path));
    } catch (_) {
      return false;
    }
  }

  /// E1: iPhone/iPad have no handler here yet: no Open button there.
  bool get canOpenLinks => canOpen;

  Future<bool> openLink(Uri link) async {
    try {
      if (Platform.isAndroid) return await _android.openLink(link);
      return await _run(openLinkCommand(Platform.operatingSystem, link));
    } catch (_) {
      return false;
    }
  }

  Future<bool> openFolder(String dir) async {
    try {
      if (Platform.isAndroid) return await _android.openFolder();
      if (!Directory(dir).existsSync()) return false;
      return await _run(openFolderCommand(Platform.operatingSystem, dir));
    } catch (_) {
      return false;
    }
  }
}

/// Replaced by tests with a fake.
SavedFileActions savedFileActions = SavedFileActions();

/// Kept names for older callers.
bool get canOpenSavedFiles => savedFileActions.canOpen;
Future<bool> openSavedFile(String path) => savedFileActions.open(path);
Future<bool> showSavedInFolder(String path) =>
    savedFileActions.showInFolder(path);
