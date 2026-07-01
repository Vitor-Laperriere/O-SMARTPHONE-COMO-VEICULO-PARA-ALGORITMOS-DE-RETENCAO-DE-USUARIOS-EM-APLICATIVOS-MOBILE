import 'coverage_status.dart';
import 'episode_analysis.dart';

class AppDailyAggregate {
  const AppDailyAggregate({
    required this.dayStart,
    required this.packageName,
    required this.appName,
    required this.duration,
    required this.episodeCount,
    required this.stateCounts,
    required this.coverageStatus,
    required this.generatedAt,
    required this.versions,
  });

  final DateTime dayStart;
  final String packageName;
  final String appName;
  final Duration duration;
  final int episodeCount;
  final Map<AnalysisState, int> stateCounts;
  final CoverageStatus coverageStatus;
  final DateTime generatedAt;
  final AnalysisArtifactVersions versions;
}
