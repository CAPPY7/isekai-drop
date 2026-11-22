import 'dart:async';

import 'package:flutter/foundation.dart';

import 'engine/core/diag_log.dart';

/// A6 (0.11.2): every uncaught error becomes a Diagnostics entry
/// (`uncaught_<class>`, plain words, no stack text with paths or names).
/// Sets FlutterError.onError (build/layout errors) and
/// PlatformDispatcher.instance.onError (errors outside Flutter's zone).
void installErrorHandlers(DiagLog log, {bool presentFlutterErrors = true}) {
  FlutterError.onError = (details) {
    recordUncaught(log, details.exception);
    // Debug console only (never sent anywhere).
    if (presentFlutterErrors) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    recordUncaught(log, error);
    return true;
  };
}

/// A6: runs the app start inside runZonedGuarded; async errors that nobody
/// caught go to [log].
void runGuardedStartup(DiagLog log, Future<void> Function() body) {
  runZonedGuarded(body, (error, stack) => recordUncaught(log, error));
}
