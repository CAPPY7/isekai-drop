/// The boundary between the UI and the transfer engine.
///
/// The UI only talks to [TransferEngine]. In Phase 2 the only implementation
/// is [DemoTransferEngine] (see demo_engine.dart): DEMO data, no networking.
/// The real engine (discovery, pairing, TLS, streaming) replaces it later
/// without changing the screens.
library;

import 'models.dart';

export 'models.dart';

abstract interface class TransferEngine {
  /// Short engine version, e.g. "demo-phase2".
  String get version;

  /// True when every piece of data comes from DEMO data, not real devices.
  bool get isDemo;

  /// Devices seen nearby right now.
  Future<List<DeviceRecord>> nearbyDevices();

  /// Saved trusted devices.
  Future<List<DeviceRecord>> trustedDevices();

  /// Rename a trusted device (local nickname only).
  Future<void> renameTrustedDevice(String id, String newName);

  /// Remove trust. The device must pair again before it is trusted.
  Future<void> revokeTrustedDevice(String id);

  /// Past transfers, newest first.
  Future<List<TransferRecord>> history();

  /// Delete all history entries.
  Future<void> clearHistory();
}
