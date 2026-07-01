const int notificationContractVersion = 1;

enum NotificationAccessStatus { granted, denied, unsupported }

enum NotificationAvailabilityReason {
  permissionDenied,
  unsupportedPlatform,
  readFailure,
}

enum NotificationListenerDiagnosticStatus {
  active,
  inactive,
  apiUnavailable,
  readFailure,
}

enum NotificationObservationReadiness { observed, notObservedYet, unavailable }

sealed class NotificationAvailability {
  const NotificationAvailability();
}

final class NotificationsAvailable extends NotificationAvailability {
  const NotificationsAvailable();
}

final class NotificationsUnavailable extends NotificationAvailability {
  const NotificationsUnavailable(this.reason);

  final NotificationAvailabilityReason reason;
}

class DailyNotificationCount {
  const DailyNotificationCount({
    required this.dayStart,
    required this.packageName,
    required this.count,
  }) : assert(count >= 0);

  final DateTime dayStart;
  final String packageName;
  final int count;
}

class NotificationLastObservation {
  const NotificationLastObservation({
    required this.observedAt,
    required this.packageName,
    required this.count,
  }) : assert(count > 0);

  final DateTime observedAt;
  final String packageName;
  final int count;
}

class NotificationListenerDiagnostic {
  const NotificationListenerDiagnostic({
    required this.status,
    required this.checkedAt,
    this.lastObservation,
  });

  final NotificationListenerDiagnosticStatus status;
  final DateTime checkedAt;
  final NotificationLastObservation? lastObservation;

  NotificationObservationReadiness get readiness =>
      switch ((status, lastObservation)) {
        (NotificationListenerDiagnosticStatus.active, final observation?)
            when observation.count > 0 =>
          NotificationObservationReadiness.observed,
        (NotificationListenerDiagnosticStatus.active, null) =>
          NotificationObservationReadiness.notObservedYet,
        _ => NotificationObservationReadiness.unavailable,
      };
}

class NotificationContentSettings {
  NotificationContentSettings({
    required this.enabled,
    required Set<String> authorizedPackageNames,
    this.retention = const Duration(days: 7),
    this.protectedAtRest = true,
    this.requiresDeviceAuthenticationForViewing = true,
    this.excludedFromBackup = true,
  }) : authorizedPackageNames = Set.unmodifiable(authorizedPackageNames);

  factory NotificationContentSettings.defaults() => NotificationContentSettings(
    enabled: false,
    authorizedPackageNames: const {},
  );

  final bool enabled;
  final Set<String> authorizedPackageNames;
  final Duration retention;
  final bool protectedAtRest;
  final bool requiresDeviceAuthenticationForViewing;
  final bool excludedFromBackup;

  bool canPersistContentFor(String packageName) =>
      enabled && authorizedPackageNames.contains(packageName);
}

class NotificationTextRecord {
  const NotificationTextRecord({
    required this.packageName,
    required this.postedAt,
    required this.title,
    required this.text,
    required this.expiresAt,
  });

  final String packageName;
  final DateTime postedAt;
  final String title;
  final String text;
  final DateTime expiresAt;
}

abstract interface class NotificationRepository {
  Future<NotificationAccessStatus> checkAccess();

  Future<void> openSettings();

  Future<List<DailyNotificationCount>> loadDailyCounts({
    required DateTime start,
    required DateTime end,
  });

  Future<NotificationLastObservation?> loadLastObservation();

  Future<NotificationContentSettings> loadContentSettings();

  Future<void> setContentModeEnabled(bool enabled);

  Future<void> authorizeContentPackage(String packageName);

  Future<void> authorizeContentPackages(Set<String> packageNames);

  Future<void> revokeContentPackage(String packageName);

  Future<bool> authenticateContentViewing();

  Future<List<NotificationTextRecord>> loadStoredContent({
    required DateTime start,
    required DateTime end,
    String? packageName,
  });

  Future<void> clearStoredContent();
}

class NotificationRepositoryException implements Exception {
  const NotificationRepositoryException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
