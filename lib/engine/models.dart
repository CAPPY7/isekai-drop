/// Data records shared by the UI and the engine.
///
/// Every record has a unique [id], [createdAt] and [updatedAt] (data rules).
library;

/// Human label for a platform name sent by a device ("android", "ios"...).
String platformLabel(String p) => switch (p) {
  'android' => 'Android',
  'ios' => 'iPhone / iPad',
  'windows' => 'Windows',
  'macos' => 'macOS',
  'linux' => 'Linux',
  _ => 'Device',
};

/// Formats a MEASURED speed (bytes per second) as MB/s.
String formatSpeed(double bytesPerSecond) =>
    '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';

enum TransferDirection { sent, received }

enum TransferOutcome { completed, failed, cancelled }

extension TransferOutcomeLabel on TransferOutcome {
  String get label => switch (this) {
    TransferOutcome.completed => 'Completed',
    TransferOutcome.failed => 'Failed',
    TransferOutcome.cancelled => 'Cancelled',
  };
}

/// One history entry. Stores no file contents.
class TransferRecord {
  const TransferRecord({
    required this.id,
    required this.deviceName,
    required this.direction,
    required this.outcome,
    required this.fileCount,
    required this.totalBytes,
    required this.destination,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String deviceName;
  final TransferDirection direction;
  final TransferOutcome outcome;
  final int fileCount;
  final int totalBytes;
  final String destination;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Formats a byte count for people, e.g. 1.5 MB.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return unit == 0
      ? '$bytes B'
      : '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}
