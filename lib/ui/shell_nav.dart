import 'package:flutter/foundation.dart';

/// Bottom-bar tabs, in order (spec E25).
abstract final class ShellTab {
  static const home = 0;
  static const send = 1;
  static const connect = 2;
  static const history = 3;
  static const settings = 4;
}

/// A screen pushed over the shell (e.g. "Send more" after a transfer)
/// sets this; the shell switches to that tab and clears it.
final ValueNotifier<int?> shellTabRequest = ValueNotifier<int?>(null);
