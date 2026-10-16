/// Data records shared by the UI and the engine.
///
/// Every record has a unique [id], [createdAt] and [updatedAt] (data rules).
library;

enum DevicePlatform { android, ios, windows, macos, linux }

extension DevicePlatformLabel on DevicePlatform {
  String get label => switch (this) {
    DevicePlatform.android => 'Android',
    DevicePlatform.ios => 'iPhone / iPad',
    DevicePlatform.windows => 'Windows',
    DevicePlatform.macos => 'macOS',
    DevicePlatform.linux => 'Linux',
  };
}

/// How much a device is trusted. Never decided by name or IP alone.
enum TrustLevel {
  /// Paired by QR/code, approved, and key saved.
  trusted,

  /// Key checked this session but not saved as trusted.
  verified,

  /// Never paired. Cannot send without approval.
  unknown,

  /// Saved key changed unexpectedly. Blocked until verified again.
  identityChanged,
}

extension TrustLevelLabel on TrustLevel {
  String get label => switch (this) {
    TrustLevel.trusted => 'Trusted',
    TrustLevel.verified => 'Verified',
    TrustLevel.unknown => 'Unknown',
    TrustLevel.identityChanged => 'Identity changed - blocked',
  };
}

class DeviceRecord {
  const DeviceRecord({
    required this.id,
    required this.name,
    required this.platform,
    required this.trust,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DevicePlatform platform;
  final TrustLevel trust;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeviceRecord copyWith({
    String? name,
    TrustLevel? trust,
    DateTime? updatedAt,
  }) => DeviceRecord(
    id: id,
    name: name ?? this.name,
    platform: platform,
    trust: trust ?? this.trust,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

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
