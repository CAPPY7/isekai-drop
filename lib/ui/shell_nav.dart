import 'package:flutter/foundation.dart';

import '../engine/pick_result.dart';

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

/// D1: files shared from another app, waiting for the Send screen.
final ValueNotifier<PickResult?> sharedFilesInbox = ValueNotifier<PickResult?>(
  null,
);

/// D1: hands shared files to the Send screen and opens the Send tab.
void deliverShared(PickResult r, {ValueNotifier<PickResult?>? inbox}) {
  if (r.files.isEmpty && r.skipped.total == 0) return;
  (inbox ?? sharedFilesInbox).value = r;
  shellTabRequest.value = ShellTab.send;
}
