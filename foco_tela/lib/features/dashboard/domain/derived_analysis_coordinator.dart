import '../../catalog/data/app_catalog_repository.dart';
import '../../notifications/domain/notification_observation.dart';
import 'analysis_window.dart';
import 'app_daily_aggregate.dart';
import 'daily_usage_summary.dart';
import 'derived_analysis_batch.dart';
import 'derived_analysis_repository.dart';
import 'episode_analysis.dart';
import 'episode_classifier.dart';
import 'usage_repository.dart';
import 'weekly_usage_dashboard_loader.dart';

class DerivedAnalysisCoordinator {
  DerivedAnalysisCoordinator({
    required UsageRepository usageRepository,
    required AppCatalogRepository catalogRepository,
    required DerivedAnalysisRepository derivedRepository,
    NotificationRepository? notificationRepository,
    EpisodeClassifier? classifier,
    DateTime Function()? now,
  }) : _usageRepository = usageRepository,
       _catalogRepository = catalogRepository,
       _derivedRepository = derivedRepository,
       _notificationRepository = notificationRepository,
       _classifier = classifier ?? EpisodeClassifier(),
       _now = now ?? DateTime.now;

  final UsageRepository _usageRepository;
  final AppCatalogRepository _catalogRepository;
  final DerivedAnalysisRepository _derivedRepository;
  final NotificationRepository? _notificationRepository;
  final EpisodeClassifier _classifier;
  final DateTime Function() _now;
  Future<WeeklyUsageDashboard>? _activeLoad;

  Future<WeeklyUsageDashboard> load({
    AnalysisWindow window = AnalysisWindow.sevenDays,
  }) {
    final active = _activeLoad;
    if (active != null) return active;
    final operation = _loadOnce(window);
    _activeLoad = operation;
    return operation.whenComplete(() {
      if (identical(_activeLoad, operation)) _activeLoad = null;
    });
  }

  Future<WeeklyUsageDashboard> _loadOnce(AnalysisWindow window) async {
    final generatedAt = _now();
    await _derivedRepository.initialize(now: generatedAt);
    final catalog = await _catalogRepository.loadSnapshot();
    final versions = _classifier.artifactVersionsFor(catalog);
    final current = await SevenDayUsageDashboardLoader(
      usageRepository: _usageRepository,
      window: window,
      now: () => generatedAt,
    ).load();
    final today = DateTime(
      generatedAt.year,
      generatedAt.month,
      generatedAt.day,
    );
    final windowStart = DateTime(
      today.year,
      today.month,
      today.day - window.dayCount + 1,
    );
    final windowEnd = DateTime(today.year, today.month, today.day + 1);
    final persistedAggregates = await _derivedRepository.loadAppDailyAggregates(
      start: windowStart,
      end: windowEnd,
      compatibleWith: versions,
    );
    final aggregatesByDay = <DateTime, List<AppDailyAggregate>>{};
    for (final aggregate in persistedAggregates) {
      aggregatesByDay
          .putIfAbsent(_normalizeDay(aggregate.dayStart), () => [])
          .add(aggregate);
    }
    final completedDays = <DailyUsageSummary>[];

    for (final day in current.days) {
      final dailyAnalysis = day.analysis;
      if (day.coverageStatus.isAvailable && dailyAnalysis != null) {
        final analyses = dailyAnalysis.episodes
            .map(
              (episode) => _classifier.analyze(
                episode: episode,
                day: day,
                catalog: catalog,
              ),
            )
            .toList(growable: false);
        final batch = DerivedAnalysisBatch(
          dayStart: day.dayStart,
          generatedAt: generatedAt,
          analyzedThrough: day.analyzedThrough,
          coverageStatus: day.coverageStatus,
          totalUsage: day.totalUsage,
          unlockCount: dailyAnalysis.unlockCount,
          episodes: dailyAnalysis.episodes,
          episodeAnalyses: analyses,
          versions: versions,
          issueMessage: day.issueMessage,
        );
        try {
          await _derivedRepository.save(batch);
          final savedAggregates = await _derivedRepository
              .loadAppDailyAggregates(
                start: day.dayStart,
                end: DateTime(
                  day.dayStart.year,
                  day.dayStart.month,
                  day.dayStart.day + 1,
                ),
                compatibleWith: versions,
              );
          if (savedAggregates.isNotEmpty) {
            aggregatesByDay[_normalizeDay(day.dayStart)] = savedAggregates;
          }
        } on DerivedAnalysisPersistenceException {
          // O resultado atual permanece utilizável; somente este dia deixou de
          // ser atualizado no histórico persistido.
        }
        completedDays.add(
          _withAggregates(
            batch.toDailySummary(),
            aggregatesByDay[_normalizeDay(day.dayStart)] ?? const [],
          ),
        );
        continue;
      }

      final preserved = await _derivedRepository.loadDay(
        day.dayStart,
        compatibleWith: versions,
      );
      if (preserved != null &&
          preserved.coverageStatus == CoverageStatus.sufficient) {
        completedDays.add(
          _withAggregates(
            preserved.toDailySummary(),
            aggregatesByDay[_normalizeDay(day.dayStart)] ?? const [],
          ),
        );
      } else {
        completedDays.add(
          _withAggregates(
            day,
            aggregatesByDay[_normalizeDay(day.dayStart)] ?? const [],
          ),
        );
      }
    }

    final allWindowDays = _mergeAggregateOnlyDays(
      completedDays,
      aggregatesByDay,
    );
    final notificationData = await _loadNotifications(windowStart, windowEnd);
    final daysWithNotifications = _withNotificationCounts(
      allWindowDays,
      notificationData.counts,
      notificationData.availability.isAvailable,
    );
    final comparison = await _buildWindowComparison(
      window: window,
      windowStart: windowStart,
      windowEnd: windowEnd,
      currentDays: daysWithNotifications,
      notificationAvailability: notificationData.availability,
      compatibleWith: versions,
    );
    return WeeklyUsageDashboard(
      generatedAt: generatedAt,
      days: daysWithNotifications,
      window: window,
      notificationAvailability: notificationData.availability,
      notificationCounts: notificationData.counts,
      comparison: comparison,
    );
  }

  Future<WindowComparison> _buildWindowComparison({
    required AnalysisWindow window,
    required DateTime windowStart,
    required DateTime windowEnd,
    required List<DailyUsageSummary> currentDays,
    required NotificationsUnavailableForDashboard notificationAvailability,
    required AnalysisArtifactVersions compatibleWith,
  }) async {
    final previousStart = DateTime(
      windowStart.year,
      windowStart.month,
      windowStart.day - window.dayCount,
    );
    final previousAggregates = await _derivedRepository.loadAppDailyAggregates(
      start: previousStart,
      end: windowStart,
      compatibleWith: compatibleWith,
    );
    final previousCoveredDays = {
      for (final aggregate in previousAggregates)
        _normalizeDay(aggregate.dayStart),
    };
    if (previousCoveredDays.length < window.dayCount) {
      return const WindowComparison.insufficient(
        'Faltou período anterior equivalente com cobertura suficiente.',
      );
    }

    final previousUsage = previousAggregates.fold<Duration>(
      Duration.zero,
      (total, aggregate) => total + aggregate.duration,
    );
    final previousEpisodes = previousAggregates.fold<int>(
      0,
      (total, aggregate) => total + aggregate.episodeCount,
    );
    WindowMetricComparison? notificationComparison;
    if (notificationAvailability.isAvailable) {
      final previousNotifications = await _loadNotifications(
        previousStart,
        windowStart,
      );
      if (previousNotifications.availability.isAvailable) {
        notificationComparison = WindowMetricComparison(
          current: currentDays.fold<int>(
            0,
            (total, day) => total + (day.notificationCount ?? 0),
          ),
          previous: previousNotifications.counts.fold<int>(
            0,
            (total, count) => total + count.count,
          ),
          unit: 'notificações',
        );
      }
    }

    return WindowComparison(
      activeTimeMinutes: WindowMetricComparison(
        current: currentDays.fold<int>(
          0,
          (total, day) => total + (day.totalUsage?.inMinutes ?? 0),
        ),
        previous: previousUsage.inMinutes,
        unit: 'minutos',
      ),
      episodeCount: WindowMetricComparison(
        current: currentDays.fold<int>(
          0,
          (total, day) => total + (day.episodeCount ?? 0),
        ),
        previous: previousEpisodes,
        unit: 'episódios',
      ),
      notificationCount: notificationComparison,
    );
  }

  Future<
    ({
      NotificationsUnavailableForDashboard availability,
      List<DailyNotificationCountForDashboard> counts,
    })
  >
  _loadNotifications(DateTime start, DateTime end) async {
    final repository = _notificationRepository;
    if (repository == null) {
      return (
        availability: const NotificationsUnavailableForDashboard(
          'Notificações indisponíveis',
        ),
        counts: const <DailyNotificationCountForDashboard>[],
      );
    }
    try {
      final access = await repository.checkAccess();
      if (access != NotificationAccessStatus.granted) {
        return (
          availability: const NotificationsUnavailableForDashboard(
            'Notificações indisponíveis',
          ),
          counts: const <DailyNotificationCountForDashboard>[],
        );
      }
      final counts = await repository.loadDailyCounts(start: start, end: end);
      return (
        availability: const NotificationsUnavailableForDashboard.available(),
        counts: counts
            .map(
              (count) => DailyNotificationCountForDashboard(
                dayStart: count.dayStart,
                packageName: count.packageName,
                count: count.count,
              ),
            )
            .toList(growable: false),
      );
    } catch (_) {
      return (
        availability: const NotificationsUnavailableForDashboard(
          'Notificações indisponíveis',
        ),
        counts: const <DailyNotificationCountForDashboard>[],
      );
    }
  }

  DailyUsageSummary _withAggregates(
    DailyUsageSummary summary,
    List<AppDailyAggregate> aggregates,
  ) {
    if (aggregates.isEmpty) return summary;
    final totalUsage =
        summary.totalUsage ??
        aggregates.fold<Duration>(
          Duration.zero,
          (total, aggregate) => total + aggregate.duration,
        );
    return DailyUsageSummary(
      dayStart: summary.dayStart,
      coverageStatus: summary.coverageStatus.isAvailable
          ? summary.coverageStatus
          : aggregates.first.coverageStatus,
      lastUpdatedAt: summary.lastUpdatedAt,
      analyzedThrough: summary.analyzedThrough,
      totalUsage: totalUsage,
      analysis: summary.analysis,
      episodeAnalyses: summary.episodeAnalyses,
      appAggregates: aggregates,
      notificationCount: summary.notificationCount,
      issueMessage: summary.issueMessage,
    );
  }

  List<DailyUsageSummary> _mergeAggregateOnlyDays(
    List<DailyUsageSummary> currentDays,
    Map<DateTime, List<AppDailyAggregate>> aggregatesByDay,
  ) {
    final merged = <DateTime, DailyUsageSummary>{
      for (final day in currentDays) _normalizeDay(day.dayStart): day,
    };
    for (final entry in aggregatesByDay.entries) {
      if (merged.containsKey(entry.key)) continue;
      final aggregates = entry.value;
      if (aggregates.isEmpty) continue;
      merged[entry.key] = DailyUsageSummary(
        dayStart: entry.key,
        coverageStatus:
            aggregates.any(
              (aggregate) =>
                  aggregate.coverageStatus == CoverageStatus.sufficient,
            )
            ? CoverageStatus.sufficient
            : aggregates.first.coverageStatus,
        lastUpdatedAt: aggregates
            .map((aggregate) => aggregate.generatedAt)
            .reduce((left, right) => left.isAfter(right) ? left : right),
        totalUsage: aggregates.fold<Duration>(
          Duration.zero,
          (total, aggregate) => total + aggregate.duration,
        ),
        analysis: null,
        appAggregates: aggregates,
      );
    }
    final days = merged.values.toList();
    days.sort((left, right) => right.dayStart.compareTo(left.dayStart));
    return days;
  }

  List<DailyUsageSummary> _withNotificationCounts(
    List<DailyUsageSummary> days,
    List<DailyNotificationCountForDashboard> counts,
    bool notificationsAvailable,
  ) {
    if (!notificationsAvailable) return days;
    final byDay = <DateTime, int>{};
    for (final count in counts) {
      final day = _normalizeDay(count.dayStart);
      byDay[day] = (byDay[day] ?? 0) + count.count;
    }
    return days
        .map(
          (day) => DailyUsageSummary(
            dayStart: day.dayStart,
            coverageStatus: day.coverageStatus,
            lastUpdatedAt: day.lastUpdatedAt,
            analyzedThrough: day.analyzedThrough,
            totalUsage: day.totalUsage,
            analysis: day.analysis,
            episodeAnalyses: day.episodeAnalyses,
            appAggregates: day.appAggregates,
            notificationCount: byDay[_normalizeDay(day.dayStart)] ?? 0,
            issueMessage: day.issueMessage,
          ),
        )
        .toList(growable: false);
  }

  DateTime _normalizeDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
