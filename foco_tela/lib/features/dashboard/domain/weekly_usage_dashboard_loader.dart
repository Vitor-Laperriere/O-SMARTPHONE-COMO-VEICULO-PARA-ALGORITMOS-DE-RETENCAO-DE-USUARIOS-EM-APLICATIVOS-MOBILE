import 'analysis_window.dart';
import 'daily_usage_analysis.dart';
import 'daily_usage_summary.dart';
import 'smartphone_usage_episode.dart';
import 'usage_repository.dart';

class SevenDayUsageDashboardLoader {
  SevenDayUsageDashboardLoader({
    required UsageRepository usageRepository,
    AnalysisWindow window = AnalysisWindow.sevenDays,
    DateTime Function()? now,
  }) : _usageRepository = usageRepository,
       _window = window,
       _now = now ?? DateTime.now;

  final UsageRepository _usageRepository;
  final AnalysisWindow _window;
  final DateTime Function() _now;

  Future<WeeklyUsageDashboard> load() async {
    final generatedAt = _now();
    final today = DateTime(
      generatedAt.year,
      generatedAt.month,
      generatedAt.day,
    );
    final requestedDays = List.generate(
      _window.detailedDayCount,
      (index) => DateTime(
        today.year,
        today.month,
        today.day - _window.detailedDayCount + 1 + index,
      ),
    );

    final analyses = <DateTime, DailyUsageAnalysis?>{};
    final failures = <DateTime, String>{};

    for (final day in requestedDays) {
      try {
        analyses[day] = await _usageRepository.getAnalysisForDay(day);
      } catch (error) {
        analyses[day] = null;
        failures[day] = error.toString();
      }
    }

    final allEpisodes = analyses.values
        .whereType<DailyUsageAnalysis>()
        .expand((analysis) => analysis.episodes)
        .toList(growable: false);

    final days = requestedDays.reversed
        .map(
          (day) => _buildSummary(
            day: day,
            generatedAt: generatedAt,
            today: today,
            analysis: analyses[day],
            issueMessage: failures[day],
            allEpisodes: allEpisodes,
          ),
        )
        .toList(growable: false);

    return WeeklyUsageDashboard(
      generatedAt: generatedAt,
      days: days,
      window: _window,
    );
  }

  DailyUsageSummary _buildSummary({
    required DateTime day,
    required DateTime generatedAt,
    required DateTime today,
    required DailyUsageAnalysis? analysis,
    required String? issueMessage,
    required List<SmartphoneUsageEpisode> allEpisodes,
  }) {
    if (analysis == null) {
      return DailyUsageSummary(
        dayStart: day,
        coverageStatus: CoverageStatus.unavailable,
        lastUpdatedAt: generatedAt,
        totalUsage: null,
        analysis: null,
        issueMessage: issueMessage,
      );
    }

    final coverageStatus = _isSameCivilDay(day, today)
        ? CoverageStatus.partial
        : CoverageStatus.sufficient;

    return DailyUsageSummary(
      dayStart: day,
      coverageStatus: coverageStatus,
      lastUpdatedAt: generatedAt,
      analyzedThrough: coverageStatus == CoverageStatus.partial
          ? generatedAt
          : null,
      totalUsage: _splitUsageAcrossCivilDay(
        episodes: allEpisodes,
        dayStart: day,
      ),
      analysis: analysis,
    );
  }

  Duration _splitUsageAcrossCivilDay({
    required List<SmartphoneUsageEpisode> episodes,
    required DateTime dayStart,
  }) {
    final civilDayStart = DateTime(dayStart.year, dayStart.month, dayStart.day);
    final civilDayEnd = DateTime(
      dayStart.year,
      dayStart.month,
      dayStart.day + 1,
    );

    var total = Duration.zero;
    for (final episode in episodes) {
      final overlapStart = episode.startedAt.isAfter(civilDayStart)
          ? episode.startedAt
          : civilDayStart;
      final overlapEnd = episode.endedAt.isBefore(civilDayEnd)
          ? episode.endedAt
          : civilDayEnd;
      if (!overlapEnd.isAfter(overlapStart)) {
        continue;
      }
      total += overlapEnd.difference(overlapStart);
    }
    return total;
  }

  bool _isSameCivilDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
