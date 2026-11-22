// C6 (0.11.4): problems that used to be swallowed by an empty
// `catch (_) {}` around file or platform-channel work are now reported.
// The app points [errorSink] at the engine (Diagnostics: the error class
// only, never file names, device names, paths or keys). Unset (unit tests,
// before the engine exists): ignored.

typedef ErrorSink = void Function(String what, Object error);

ErrorSink? errorSink;

/// Reports [error] that happened while doing [what] (a short fixed word).
void noteError(String what, Object error) => errorSink?.call(what, error);
