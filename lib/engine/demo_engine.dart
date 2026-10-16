import 'models.dart';

/// DEMO history only (Phase 3). Real transfer history arrives in a later
/// phase. Shown with the label "DEMO - not a real transfer".
class DemoHistory {
  DemoHistory({this.latency = const Duration(milliseconds: 300), DateTime? now})
    : _now = now ?? DateTime(2026, 10, 16, 12) {
    DateTime ago(int m) => _now.subtract(Duration(minutes: m));
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
    ]);
  }

  final Duration latency;
  final DateTime _now;
  bool failNextCall = false;
  final List<TransferRecord> _history = [];

  Future<void> _wait() async {
    await Future<void>.delayed(latency);
    if (failNextCall) {
      failNextCall = false;
      throw StateError('DEMO error: simulated failure');
    }
  }

  Future<List<TransferRecord>> history() async {
    await _wait();
    return List.unmodifiable(_history);
  }

  Future<void> clearHistory() async {
    await _wait();
    _history.clear();
  }
}
