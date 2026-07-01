import '../domain/app_daily_aggregate.dart';
import '../domain/derived_analysis_batch.dart';
import '../domain/derived_analysis_repository.dart';
import '../domain/episode_analysis.dart';

class InMemoryDerivedAnalysisRepository implements DerivedAnalysisRepository {
  final Map<DateTime, DerivedAnalysisBatch> _batches = {};
  final Map<(DateTime, String), AppDailyAggregate> _aggregates = {};

  @override
  Future<void> initialize({required DateTime now}) => prune(now: now);

  @override
  Future<void> save(DerivedAnalysisBatch batch) async {
    final day = _normalize(batch.dayStart);
    _batches[day] = batch;
    _aggregates.removeWhere((key, _) => key.$1 == day);
    for (final aggregate in _buildAggregates(batch)) {
      _aggregates[(aggregate.dayStart, aggregate.packageName)] = aggregate;
    }
    await prune(now: batch.generatedAt);
  }

  @override
  Future<DerivedAnalysisBatch?> loadDay(
    DateTime day, {
    AnalysisArtifactVersions? compatibleWith,
  }) async {
    final batch = _batches[_normalize(day)];
    if (batch == null) return null;
    if (compatibleWith != null && !batch.isCompatibleWith(compatibleWith)) {
      return null;
    }
    return batch;
  }

  @override
  Future<List<AppDailyAggregate>> loadAppDailyAggregates({
    required DateTime start,
    required DateTime end,
    AnalysisArtifactVersions? compatibleWith,
  }) async {
    final normalizedStart = _normalize(start);
    final normalizedEnd = _normalize(end);
    return _aggregates.values
        .where((aggregate) {
          if (aggregate.dayStart.isBefore(normalizedStart) ||
              !aggregate.dayStart.isBefore(normalizedEnd)) {
            return false;
          }
          return compatibleWith == null ||
              _versionsMatch(aggregate.versions, compatibleWith);
        })
        .toList(growable: false)
      ..sort((left, right) {
        final dayOrder = left.dayStart.compareTo(right.dayStart);
        if (dayOrder != 0) return dayOrder;
        return left.packageName.compareTo(right.packageName);
      });
  }

  @override
  Future<void> prune({required DateTime now}) async {
    final today = _normalize(now);
    final oldestDetailed = DateTime(today.year, today.month, today.day - 29);
    final oldestAggregate = DateTime(today.year, today.month - 6, today.day);
    _batches.removeWhere((day, _) => day.isBefore(oldestDetailed));
    _aggregates.removeWhere((key, _) => key.$1.isBefore(oldestAggregate));
  }

  @override
  Future<void> clearAllDerived() async {
    _batches.clear();
    _aggregates.clear();
  }

  @override
  Future<void> close() async {}

  DateTime _normalize(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  List<AppDailyAggregate> _buildAggregates(DerivedAnalysisBatch batch) {
    if (!batch.coverageStatus.isAvailable) return const [];

    final byPackage = <String, List<EpisodeAnalysisResult>>{};
    for (final result in batch.episodeAnalyses) {
      byPackage.putIfAbsent(result.episode.packageName, () => []).add(result);
    }

    return byPackage.entries
        .map((entry) {
          final analyses = entry.value;
          final firstEpisode = analyses.first.episode;
          final stateCounts = <AnalysisState, int>{
            for (final state in AnalysisState.values) state: 0,
          };
          var duration = Duration.zero;
          for (final analysis in analyses) {
            duration += analysis.episode.duration;
            if (analysis case ClassifiedEpisodeAnalysis(:final state)) {
              stateCounts[state] = stateCounts[state]! + 1;
            }
          }
          return AppDailyAggregate(
            dayStart: _normalize(batch.dayStart),
            packageName: firstEpisode.packageName,
            appName: firstEpisode.appName,
            duration: duration,
            episodeCount: analyses.length,
            stateCounts: Map.unmodifiable(stateCounts),
            coverageStatus: batch.coverageStatus,
            generatedAt: batch.generatedAt,
            versions: batch.versions,
          );
        })
        .toList(growable: false);
  }

  bool _versionsMatch(
    AnalysisArtifactVersions left,
    AnalysisArtifactVersions right,
  ) =>
      left.calibrationVersion == right.calibrationVersion &&
      left.catalogVersion == right.catalogVersion &&
      left.owxIri == right.owxIri &&
      left.owxVersion == right.owxVersion &&
      left.owxCommit == right.owxCommit &&
      left.owxHash == right.owxHash;
}
