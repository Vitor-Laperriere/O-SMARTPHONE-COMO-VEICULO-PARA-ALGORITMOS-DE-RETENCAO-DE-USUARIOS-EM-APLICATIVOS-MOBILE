export 'coverage_status.dart';

import 'coverage_status.dart';
import 'app_daily_aggregate.dart';
import 'daily_usage_analysis.dart';
import 'episode_analysis.dart';
import 'smartphone_usage_episode.dart';
import 'analysis_window.dart';

class DailyUsageSummary {
  DailyUsageSummary({
    required this.dayStart,
    required this.coverageStatus,
    required this.lastUpdatedAt,
    required this.totalUsage,
    required this.analysis,
    List<EpisodeAnalysisResult> episodeAnalyses = const [],
    List<AppDailyAggregate> appAggregates = const [],
    this.analyzedThrough,
    this.notificationCount,
    this.issueMessage,
  }) : episodeAnalyses = List.unmodifiable(episodeAnalyses),
       appAggregates = List.unmodifiable(appAggregates);

  final DateTime dayStart;
  final CoverageStatus coverageStatus;
  final DateTime lastUpdatedAt;
  final DateTime? analyzedThrough;
  final Duration? totalUsage;
  final DailyUsageAnalysis? analysis;
  final List<EpisodeAnalysisResult> episodeAnalyses;
  final List<AppDailyAggregate> appAggregates;
  final int? notificationCount;
  final String? issueMessage;

  bool get isProvisional => analyzedThrough != null;

  bool get canOpenDetail => analysis != null || appAggregates.isNotEmpty;

  int? get episodeCount =>
      analysis?.episodes.length ??
      (appAggregates.isEmpty
          ? null
          : appAggregates.fold<int>(
              0,
              (total, aggregate) => total + aggregate.episodeCount,
            ));

  List<SmartphoneUsageEpisode> get episodes =>
      analysis?.episodes ?? const <SmartphoneUsageEpisode>[];

  Map<AnalysisState, int> get stateDistribution {
    final counts = {for (final state in AnalysisState.values) state: 0};
    for (final result in episodeAnalyses) {
      if (result case ClassifiedEpisodeAnalysis(:final state)) {
        counts[state] = counts[state]! + 1;
      }
    }
    if (episodeAnalyses.isEmpty && appAggregates.isNotEmpty) {
      for (final aggregate in appAggregates) {
        for (final entry in aggregate.stateCounts.entries) {
          counts[entry.key] = counts[entry.key]! + entry.value;
        }
      }
    }
    return Map.unmodifiable(counts);
  }

  EpisodeAnalysisResult? analysisForEpisode(SmartphoneUsageEpisode episode) {
    for (final result in episodeAnalyses) {
      if (_sameEpisode(result.episode, episode)) {
        return result;
      }
    }
    return null;
  }
}

class WeeklyUsageDashboard {
  WeeklyUsageDashboard({
    required this.generatedAt,
    required List<DailyUsageSummary> days,
    this.window = AnalysisWindow.sevenDays,
    this.notificationAvailability = const NotificationsUnavailableForDashboard(
      'Notificações indisponíveis',
    ),
    List<DailyNotificationCountForDashboard> notificationCounts = const [],
    this.comparison = const WindowComparison.insufficient(
      'Faltou período anterior equivalente com cobertura suficiente.',
    ),
  }) : days = List.unmodifiable(days),
       notificationCounts = List.unmodifiable(notificationCounts);

  final DateTime generatedAt;
  final List<DailyUsageSummary> days;
  final AnalysisWindow window;
  final NotificationsUnavailableForDashboard notificationAvailability;
  final List<DailyNotificationCountForDashboard> notificationCounts;
  final WindowComparison comparison;

  DailyUsageSummary? summaryFor(DateTime dayStart) {
    final normalized = DateTime(dayStart.year, dayStart.month, dayStart.day);
    for (final day in days) {
      if (_isSameCivilDay(day.dayStart, normalized)) {
        return day;
      }
    }
    return null;
  }

  bool get hasAnyAvailableDay =>
      days.any((day) => day.coverageStatus.isAvailable);

  Duration get totalUsage => days.fold(
    Duration.zero,
    (total, day) => total + (day.totalUsage ?? Duration.zero),
  );

  int get totalEpisodeCount =>
      days.fold(0, (total, day) => total + (day.episodeCount ?? 0));

  int? get totalNotificationCount => notificationAvailability.isAvailable
      ? notificationCounts.fold<int>(0, (total, count) => total + count.count)
      : null;

  int? notificationCountFor(DateTime dayStart) {
    if (!notificationAvailability.isAvailable) return null;
    final normalized = DateTime(dayStart.year, dayStart.month, dayStart.day);
    return notificationCounts
        .where((count) => _isSameCivilDay(count.dayStart, normalized))
        .fold<int>(0, (total, count) => total + count.count);
  }

  Map<AnalysisState, int> get stateDistribution {
    final counts = {for (final state in AnalysisState.values) state: 0};
    for (final day in days) {
      for (final entry in day.stateDistribution.entries) {
        counts[entry.key] = counts[entry.key]! + entry.value;
      }
    }
    return Map.unmodifiable(counts);
  }

  List<AppWindowRanking> appDurationRanking({int limit = 5}) {
    final rankings = _appRankings();
    rankings.sort((left, right) {
      final durationOrder = right.duration.compareTo(left.duration);
      if (durationOrder != 0) return durationOrder;
      final recurrenceOrder = right.coveredDayCount.compareTo(
        left.coveredDayCount,
      );
      if (recurrenceOrder != 0) return recurrenceOrder;
      return left.appName.compareTo(right.appName);
    });
    return rankings.take(limit).toList(growable: false);
  }

  List<AppWindowRanking> appRecurrenceRanking({int limit = 5}) {
    final rankings = _appRankings();
    rankings.sort((left, right) {
      final recurrenceOrder = right.coveredDayCount.compareTo(
        left.coveredDayCount,
      );
      if (recurrenceOrder != 0) return recurrenceOrder;
      final episodeOrder = right.episodeCount.compareTo(left.episodeCount);
      if (episodeOrder != 0) return episodeOrder;
      final durationOrder = right.duration.compareTo(left.duration);
      if (durationOrder != 0) return durationOrder;
      return left.appName.compareTo(right.appName);
    });
    return rankings.take(limit).toList(growable: false);
  }

  List<AppWindowRanking> _appRankings() {
    final builders = <String, _AppWindowRankingBuilder>{};
    for (final day in days) {
      if (day.appAggregates.isNotEmpty) {
        for (final aggregate in day.appAggregates) {
          builders
              .putIfAbsent(
                aggregate.packageName,
                () => _AppWindowRankingBuilder(
                  packageName: aggregate.packageName,
                  appName: aggregate.appName,
                ),
              )
              .addAggregate(day.dayStart, aggregate);
        }
        continue;
      }
      for (final episode in day.episodes) {
        builders
            .putIfAbsent(
              episode.packageName,
              () => _AppWindowRankingBuilder(
                packageName: episode.packageName,
                appName: episode.displayName,
              ),
            )
            .addEpisode(day.dayStart, episode);
      }
    }
    return builders.values.map((builder) => builder.build()).toList();
  }
}

class WindowMetricComparison {
  const WindowMetricComparison({
    required this.current,
    required this.previous,
    required this.unit,
  });

  final int current;
  final int previous;
  final String unit;

  int get absoluteDelta => current - previous;

  double? get percentageDelta =>
      previous == 0 ? null : (absoluteDelta / previous) * 100;

  bool get isNewRecord => previous == 0 && current > 0;
}

class WindowComparison {
  const WindowComparison({
    required this.activeTimeMinutes,
    required this.episodeCount,
    required this.notificationCount,
    this.insufficientReason,
  });

  const WindowComparison.insufficient(this.insufficientReason)
    : activeTimeMinutes = null,
      episodeCount = null,
      notificationCount = null;

  final WindowMetricComparison? activeTimeMinutes;
  final WindowMetricComparison? episodeCount;
  final WindowMetricComparison? notificationCount;
  final String? insufficientReason;

  bool get isAvailable =>
      activeTimeMinutes != null ||
      episodeCount != null ||
      notificationCount != null;
}

class AppWindowRanking {
  const AppWindowRanking({
    required this.packageName,
    required this.appName,
    required this.duration,
    required this.episodeCount,
    required this.coveredDayCount,
  });

  final String packageName;
  final String appName;
  final Duration duration;
  final int episodeCount;
  final int coveredDayCount;
}

class _AppWindowRankingBuilder {
  _AppWindowRankingBuilder({required this.packageName, required this.appName});

  final String packageName;
  final String appName;
  final Set<DateTime> _coveredDays = {};
  Duration _duration = Duration.zero;
  int _episodeCount = 0;

  void addAggregate(DateTime dayStart, AppDailyAggregate aggregate) {
    _coveredDays.add(DateTime(dayStart.year, dayStart.month, dayStart.day));
    _duration += aggregate.duration;
    _episodeCount += aggregate.episodeCount;
  }

  void addEpisode(DateTime dayStart, SmartphoneUsageEpisode episode) {
    _coveredDays.add(DateTime(dayStart.year, dayStart.month, dayStart.day));
    _duration += episode.duration;
    _episodeCount++;
  }

  AppWindowRanking build() => AppWindowRanking(
    packageName: packageName,
    appName: appName,
    duration: _duration,
    episodeCount: _episodeCount,
    coveredDayCount: _coveredDays.length,
  );
}

class NotificationsUnavailableForDashboard {
  const NotificationsUnavailableForDashboard(
    this.label, {
    this.isAvailable = false,
  });

  const NotificationsUnavailableForDashboard.available()
    : label = 'Notificações disponíveis',
      isAvailable = true;

  final String label;
  final bool isAvailable;
}

class DailyNotificationCountForDashboard {
  const DailyNotificationCountForDashboard({
    required this.dayStart,
    required this.packageName,
    required this.count,
  });

  final DateTime dayStart;
  final String packageName;
  final int count;
}

bool _isSameCivilDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

bool _sameEpisode(SmartphoneUsageEpisode left, SmartphoneUsageEpisode right) =>
    left.packageName == right.packageName &&
    left.startedAt == right.startedAt &&
    left.endedAt == right.endedAt;
