import '../../catalog/domain/app_catalog.dart';
import '../../catalog/domain/app_identity.dart';
import '../../dashboard/domain/daily_usage_summary.dart';

class AppsPresenter {
  const AppsPresenter();

  AppsOverviewModel present({
    required WeeklyUsageDashboard dashboard,
    required CatalogSnapshot catalog,
    required Map<String, AppIdentity> identitiesByPackageName,
  }) {
    final builders = <String, _ObservedAppBuilder>{};
    final recentDays = dashboard.days.take(7).toList(growable: false);

    for (var dayIndex = 0; dayIndex < dashboard.days.length; dayIndex++) {
      final day = dashboard.days[dayIndex];
      final isRecentWeek = dayIndex < recentDays.length;
      final aggregates = day.appAggregates;
      if (aggregates.isNotEmpty) {
        for (final aggregate in aggregates) {
          builders
              .putIfAbsent(
                aggregate.packageName,
                () => _ObservedAppBuilder(
                  packageName: aggregate.packageName,
                  fallbackName: aggregate.appName,
                ),
              )
              .addUsage(
                dayStart: day.dayStart,
                duration: aggregate.duration,
                episodeCount: aggregate.episodeCount,
                isToday: dayIndex == 0,
                isRecentWeek: isRecentWeek,
              );
        }
        continue;
      }

      for (final episode in day.episodes) {
        builders
            .putIfAbsent(
              episode.packageName,
              () => _ObservedAppBuilder(
                packageName: episode.packageName,
                fallbackName: episode.displayName,
              ),
            )
            .addUsage(
              dayStart: day.dayStart,
              duration: episode.duration,
              episodeCount: 1,
              isToday: dayIndex == 0,
              isRecentWeek: isRecentWeek,
            );
      }
    }

    if (dashboard.notificationAvailability.isAvailable) {
      for (final count in dashboard.notificationCounts) {
        final isToday =
            dashboard.days.isNotEmpty &&
            _isSameCivilDay(count.dayStart, dashboard.days.first.dayStart);
        final isRecentWeek = recentDays.any(
          (day) => _isSameCivilDay(day.dayStart, count.dayStart),
        );
        builders
            .putIfAbsent(
              count.packageName,
              () => _ObservedAppBuilder(
                packageName: count.packageName,
                fallbackName: count.packageName,
              ),
            )
            .addNotifications(
              count.count,
              isToday: isToday,
              isRecentWeek: isRecentWeek,
            );
      }
    }

    final apps = builders.values.map((builder) {
      final catalogApp = catalog.appForPackageName(builder.packageName);
      final identity =
          identitiesByPackageName[builder.packageName] ??
          AppIdentity(packageName: builder.packageName);
      return builder.build(catalogApp: catalogApp, identity: identity);
    }).toList(growable: false)
      ..sort(_compareApps);

    return AppsOverviewModel(apps: apps);
  }

  static int _compareApps(AppsObservedApp left, AppsObservedApp right) {
    final durationOrder = right.weekDuration.compareTo(left.weekDuration);
    if (durationOrder != 0) return durationOrder;
    final episodeOrder = right.episodeCount.compareTo(left.episodeCount);
    if (episodeOrder != 0) return episodeOrder;
    return left.displayName.compareTo(right.displayName);
  }

  static bool _isSameCivilDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

class AppsOverviewModel {
  const AppsOverviewModel({required this.apps});

  final List<AppsObservedApp> apps;

  List<AppsObservedApp> appsForStatus(CatalogContextStatus status) => apps
      .where((app) => app.status == status)
      .toList(growable: false);
}

class AppsObservedApp {
  const AppsObservedApp({
    required this.packageName,
    required this.displayName,
    required this.identity,
    required this.catalogApp,
    required this.status,
    required this.todayDuration,
    required this.weekDuration,
    required this.episodeCount,
    required this.coveredDayCount,
    required this.todayNotificationCount,
    required this.weekNotificationCount,
  });

  final String packageName;
  final String displayName;
  final AppIdentity identity;
  final CatalogApp? catalogApp;
  final CatalogContextStatus status;
  final Duration todayDuration;
  final Duration weekDuration;
  final int episodeCount;
  final int coveredDayCount;
  final int? todayNotificationCount;
  final int? weekNotificationCount;

  bool get hasApprovedContext => status == CatalogContextStatus.approved;
  bool get hasCandidateSuggestion =>
      status == CatalogContextStatus.candidateAutomatic;
}

class _ObservedAppBuilder {
  _ObservedAppBuilder({required this.packageName, required this.fallbackName});

  final String packageName;
  final String fallbackName;
  final Set<DateTime> _coveredDays = {};
  Duration _todayDuration = Duration.zero;
  Duration _weekDuration = Duration.zero;
  int _episodeCount = 0;
  int? _todayNotificationCount;
  int? _weekNotificationCount;

  void addUsage({
    required DateTime dayStart,
    required Duration duration,
    required int episodeCount,
    required bool isToday,
    required bool isRecentWeek,
  }) {
    _coveredDays.add(DateTime(dayStart.year, dayStart.month, dayStart.day));
    if (isToday) {
      _todayDuration += duration;
    }
    if (isRecentWeek) {
      _weekDuration += duration;
    }
    _episodeCount += episodeCount;
  }

  void addNotifications(
    int count, {
    required bool isToday,
    required bool isRecentWeek,
  }) {
    if (isToday) {
      _todayNotificationCount = (_todayNotificationCount ?? 0) + count;
    }
    if (isRecentWeek) {
      _weekNotificationCount = (_weekNotificationCount ?? 0) + count;
    }
  }

  AppsObservedApp build({
    required CatalogApp? catalogApp,
    required AppIdentity identity,
  }) {
    final displayName = switch (identity.friendlyName?.trim()) {
      final String label when label.isNotEmpty => label,
      _ => switch (catalogApp?.displayName.trim()) {
        final String label when label.isNotEmpty => label,
        _ => fallbackName.trim().isEmpty ? packageName : fallbackName,
      },
    };
    return AppsObservedApp(
      packageName: packageName,
      displayName: displayName,
      identity: identity,
      catalogApp: catalogApp,
      status: catalogApp?.contextStatus ?? CatalogContextStatus.insufficient,
      todayDuration: _todayDuration,
      weekDuration: _weekDuration,
      episodeCount: _episodeCount,
      coveredDayCount: _coveredDays.length,
      todayNotificationCount: _todayNotificationCount,
      weekNotificationCount: _weekNotificationCount,
    );
  }
}
