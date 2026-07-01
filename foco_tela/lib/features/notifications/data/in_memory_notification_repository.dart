import '../domain/notification_observation.dart';

class InMemoryNotificationRepository implements NotificationRepository {
  InMemoryNotificationRepository({
    this.accessStatus = NotificationAccessStatus.unsupported,
    NotificationContentSettings? initialSettings,
    List<DailyNotificationCount> counts = const [],
    List<NotificationTextRecord> content = const [],
  }) : _settings = initialSettings ?? NotificationContentSettings.defaults(),
       _counts = List.of(counts),
       _content = List.of(content);

  NotificationAccessStatus accessStatus;
  NotificationContentSettings _settings;
  final List<DailyNotificationCount> _counts;
  final List<NotificationTextRecord> _content;

  @override
  Future<NotificationAccessStatus> checkAccess() async => accessStatus;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DailyNotificationCount>> loadDailyCounts({
    required DateTime start,
    required DateTime end,
  }) async {
    if (accessStatus != NotificationAccessStatus.granted) return const [];
    return _counts
        .where(
          (count) =>
              !count.dayStart.isBefore(_day(start)) &&
              count.dayStart.isBefore(_day(end)),
        )
        .toList(growable: false);
  }

  @override
  Future<NotificationLastObservation?> loadLastObservation() async {
    if (accessStatus != NotificationAccessStatus.granted) return null;
    final observed = _counts.where((count) => count.count > 0).toList();
    if (observed.isEmpty) return null;
    observed.sort((left, right) {
      final dayComparison = right.dayStart.compareTo(left.dayStart);
      if (dayComparison != 0) return dayComparison;
      final countComparison = right.count.compareTo(left.count);
      if (countComparison != 0) return countComparison;
      return left.packageName.compareTo(right.packageName);
    });
    final latest = observed.first;
    return NotificationLastObservation(
      observedAt: latest.dayStart,
      packageName: latest.packageName,
      count: latest.count,
    );
  }

  @override
  Future<NotificationContentSettings> loadContentSettings() async => _settings;

  @override
  Future<void> setContentModeEnabled(bool enabled) async {
    if (!enabled) {
      _content.clear();
      _settings = NotificationContentSettings.defaults();
      return;
    }
    _settings = NotificationContentSettings(
      enabled: true,
      authorizedPackageNames: _settings.authorizedPackageNames,
    );
  }

  @override
  Future<void> authorizeContentPackage(String packageName) async {
    final packages = {..._settings.authorizedPackageNames, packageName};
    _settings = NotificationContentSettings(
      enabled: _settings.enabled,
      authorizedPackageNames: packages,
    );
  }

  @override
  Future<void> authorizeContentPackages(Set<String> packageNames) async {
    final packages = {..._settings.authorizedPackageNames, ...packageNames};
    _settings = NotificationContentSettings(
      enabled: _settings.enabled,
      authorizedPackageNames: packages,
    );
  }

  @override
  Future<void> revokeContentPackage(String packageName) async {
    final packages = {..._settings.authorizedPackageNames}..remove(packageName);
    _content.removeWhere((record) => record.packageName == packageName);
    _settings = NotificationContentSettings(
      enabled: _settings.enabled,
      authorizedPackageNames: packages,
    );
  }

  @override
  Future<bool> authenticateContentViewing() async => true;

  @override
  Future<List<NotificationTextRecord>> loadStoredContent({
    required DateTime start,
    required DateTime end,
    String? packageName,
  }) async {
    final now = DateTime.now();
    _content.removeWhere((record) => !record.expiresAt.isAfter(now));
    if (!_settings.enabled) return const [];
    return _content
        .where(
          (record) =>
              !record.postedAt.isBefore(start) &&
              record.postedAt.isBefore(end) &&
              _settings.authorizedPackageNames.contains(record.packageName) &&
              (packageName == null || record.packageName == packageName),
        )
        .toList(growable: false);
  }

  @override
  Future<void> clearStoredContent() async => _content.clear();

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
}
