/// The boundary between the UI and the transfer engine.
///
/// The UI only talks to [TransferEngine]. The real engine (discovery,
/// pairing, TLS sessions, chunked streaming, hashing, resume) is built in
/// Phase 2 and later. Phase 1 ships ONLY [EngineStatus.notImplemented]: there
/// is no fake discovery, no fake devices and no fake speed.
library;

/// What the engine can currently do.
enum EngineStatus {
  /// Phase 1: the engine has not been built yet.
  notImplemented,

  /// Later phases: the engine is running and ready.
  ready,
}

/// Contract the UI depends on. Later phases add discovery, pairing and
/// transfer methods here; the UI never reaches past this interface.
abstract interface class TransferEngine {
  /// Short human-readable engine version, e.g. "phase1-stub".
  String get version;

  /// Current engine status.
  EngineStatus get status;
}

/// Honest Phase 1 placeholder. It does nothing and says so.
class Phase1EngineStub implements TransferEngine {
  const Phase1EngineStub();

  @override
  String get version => 'phase1-stub';

  @override
  EngineStatus get status => EngineStatus.notImplemented;
}
