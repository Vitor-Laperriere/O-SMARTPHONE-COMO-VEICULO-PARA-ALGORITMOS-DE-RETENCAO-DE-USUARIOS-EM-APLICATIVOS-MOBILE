import '../../notifications/domain/notification_observation.dart';
import '../../dashboard/domain/behavioral_signal_calibration.dart';
import '../../usage_access/domain/usage_access.dart';

class PrivacySettingsSnapshot {
  const PrivacySettingsSnapshot({
    required this.usageAccessStatus,
    required this.notificationDiagnostic,
    required this.notificationContentSettings,
    required this.observedPackageNames,
    required this.calibration,
    required this.catalogVersion,
    required this.heuristicVersion,
    required this.owxIri,
    required this.owxVersion,
    required this.owxCommit,
    required this.owxHash,
  });

  final UsageAccessStatus usageAccessStatus;
  final NotificationListenerDiagnostic notificationDiagnostic;
  final NotificationContentSettings notificationContentSettings;
  final Set<String> observedPackageNames;
  final BehavioralSignalCalibration calibration;
  final String catalogVersion;
  final String heuristicVersion;
  final String owxIri;
  final String owxVersion;
  final String owxCommit;
  final String owxHash;

  PrivacySettingsSnapshot copyWith({
    UsageAccessStatus? usageAccessStatus,
    NotificationListenerDiagnostic? notificationDiagnostic,
    NotificationContentSettings? notificationContentSettings,
    Set<String>? observedPackageNames,
    BehavioralSignalCalibration? calibration,
    String? catalogVersion,
    String? heuristicVersion,
    String? owxIri,
    String? owxVersion,
    String? owxCommit,
    String? owxHash,
  }) => PrivacySettingsSnapshot(
    usageAccessStatus: usageAccessStatus ?? this.usageAccessStatus,
    notificationDiagnostic:
        notificationDiagnostic ?? this.notificationDiagnostic,
    notificationContentSettings:
        notificationContentSettings ?? this.notificationContentSettings,
    observedPackageNames: observedPackageNames ?? this.observedPackageNames,
    calibration: calibration ?? this.calibration,
    catalogVersion: catalogVersion ?? this.catalogVersion,
    heuristicVersion: heuristicVersion ?? this.heuristicVersion,
    owxIri: owxIri ?? this.owxIri,
    owxVersion: owxVersion ?? this.owxVersion,
    owxCommit: owxCommit ?? this.owxCommit,
    owxHash: owxHash ?? this.owxHash,
  );
}
