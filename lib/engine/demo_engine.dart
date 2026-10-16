import 'transfer_engine.dart';

/// DEMO data only. Nothing here talks to a network or a real device.
/// Every screen that shows this data labels it "DEMO - not a real transfer".
class DemoTransferEngine implements TransferEngine {
  DemoTransferEngine({
    this.latency = const Duration(milliseconds: 400),
    DateTime? now,
  }) : _now = now ?? DateTime(2026, 10, 16, 12) {
    _seed();
  }

  /// Simulated wait so loading states can be seen.
  final Duration latency;
  final DateTime _now;

  /// Test hook: when true, the next call fails so error states can be shown.
  bool failNextCall = false;

  final List<DeviceRecord> _nearby = [];
  final List<DeviceRecord> _trusted = [];
  final List<TransferRecord> _history = [];

  void _seed() {
    DateTime ago(int minutes) => _now.subtract(Duration(minutes: minutes));
    _nearby.addAll([
      DeviceRecord(
        id: 'demo-dev-1',
        name: 'DEMO Pixel phone',
        platform: DevicePlatform.android,
        trust: TrustLevel.trusted,
        createdAt: ago(9000),
        updatedAt: ago(5),
      ),
      DeviceRecord(
        id: 'demo-dev-4',
        name: 'DEMO Unknown laptop',
        platform: DevicePlatform.linux,
        trust: TrustLevel.unknown,
        createdAt: ago(2),
        updatedAt: ago(2),
      ),
    ]);
    _trusted.addAll([
      _nearby.first,
      DeviceRecord(
        id: 'demo-dev-2',
        name: 'DEMO Windows desktop',
        platform: DevicePlatform.windows,
        trust: TrustLevel.trusted,
        createdAt: ago(20000),
        updatedAt: ago(600),
      ),
      DeviceRecord(
        id: 'demo-dev-3',
        name: 'DEMO MacBook',
        platform: DevicePlatform.macos,
        trust: TrustLevel.identityChanged,
        createdAt: ago(30000),
        updatedAt: ago(60),
      ),
    ]);
    _history.addAll([
      TransferRecord(
        id: 'demo-tx-1',
        deviceName: 'DEMO Pixel phone',
        direction: TransferDirection.received,
        outcome: TransferOutcome.completed,
        fileCount: 12,
        totalBytes: 734003200,
        destination: 'Downloads/Isekai Drop',
        createdAt: ago(30),
        updatedAt: ago(28),
      ),
      TransferRecord(
        id: 'demo-tx-2',
        deviceName: 'DEMO Windows desktop',
        direction: TransferDirection.sent,
        outcome: TransferOutcome.failed,
        fileCount: 1,
        totalBytes: 2147483648,
        destination: 'Windows: Downloads',
        createdAt: ago(300),
        updatedAt: ago(290),
      ),
      TransferRecord(
        id: 'demo-tx-3',
        deviceName: 'DEMO MacBook',
        direction: TransferDirection.sent,
        outcome: TransferOutcome.cancelled,
        fileCount: 3,
        totalBytes: 15728640,
        destination: 'macOS: Downloads',
        createdAt: ago(2000),
        updatedAt: ago(1999),
      ),
    ]);
  }

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failNextCall) {
      failNextCall = false;
      throw StateError('DEMO error: simulated failure');
    }
  }

  @override
  String get version => 'demo-phase2';

  @override
  bool get isDemo => true;

  @override
  Future<List<DeviceRecord>> nearbyDevices() async {
    await _wait();
    return List.unmodifiable(_nearby);
  }

  @override
  Future<List<DeviceRecord>> trustedDevices() async {
    await _wait();
    return List.unmodifiable(_trusted);
  }

  @override
  Future<void> renameTrustedDevice(String id, String newName) async {
    await _wait();
    final i = _trusted.indexWhere((d) => d.id == id);
    if (i < 0) throw StateError('Device not found');
    _trusted[i] = _trusted[i].copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> revokeTrustedDevice(String id) async {
    await _wait();
    _trusted.removeWhere((d) => d.id == id);
    for (var i = 0; i < _nearby.length; i++) {
      if (_nearby[i].id == id) {
        _nearby[i] = _nearby[i].copyWith(trust: TrustLevel.unknown);
      }
    }
  }

  @override
  Future<List<TransferRecord>> history() async {
    await _wait();
    return List.unmodifiable(_history);
  }

  @override
  Future<void> clearHistory() async {
    await _wait();
    _history.clear();
  }
}
