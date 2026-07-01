import 'derived_analysis_batch.dart';
import 'episode_analysis.dart';
import 'app_daily_aggregate.dart';

abstract interface class DerivedAnalysisRepository {
  Future<void> initialize({required DateTime now});

  Future<void> save(DerivedAnalysisBatch batch);

  Future<DerivedAnalysisBatch?> loadDay(
    DateTime day, {
    AnalysisArtifactVersions? compatibleWith,
  });

  Future<List<AppDailyAggregate>> loadAppDailyAggregates({
    required DateTime start,
    required DateTime end,
    AnalysisArtifactVersions? compatibleWith,
  });

  Future<void> prune({required DateTime now});

  Future<void> clearAllDerived();

  Future<void> close();
}

class DerivedAnalysisPersistenceException implements Exception {
  const DerivedAnalysisPersistenceException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
