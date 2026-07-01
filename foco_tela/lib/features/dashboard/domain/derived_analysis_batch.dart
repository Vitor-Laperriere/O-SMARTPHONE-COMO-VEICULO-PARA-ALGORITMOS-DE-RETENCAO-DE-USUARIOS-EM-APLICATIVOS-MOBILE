export 'coverage_status.dart';

import 'daily_usage_analysis.dart';
import 'daily_usage_summary.dart';
import 'episode_analysis.dart';
import 'smartphone_usage_episode.dart';

class DerivedAnalysisBatch {
  DerivedAnalysisBatch({
    required this.dayStart,
    required this.generatedAt,
    required this.coverageStatus,
    required this.totalUsage,
    required this.unlockCount,
    required List<SmartphoneUsageEpisode> episodes,
    required List<EpisodeAnalysisResult> episodeAnalyses,
    required this.versions,
    this.analyzedThrough,
    this.issueMessage,
  }) : episodes = List.unmodifiable(episodes),
       episodeAnalyses = List.unmodifiable(episodeAnalyses) {
    if (coverageStatus.isAvailable && totalUsage == null) {
      throw ArgumentError('Dia disponível exige agregado de uso.');
    }
    if (coverageStatus.isAvailable && unlockCount == null) {
      throw ArgumentError('Dia disponível exige agregado de desbloqueios.');
    }
    if (!coverageStatus.isAvailable &&
        (totalUsage != null || unlockCount != null || episodes.isNotEmpty)) {
      throw ArgumentError(
        'Dia indisponível não pode fabricar agregados ou episódios.',
      );
    }
    if (episodeAnalyses.length != episodes.length) {
      throw ArgumentError(
        'Cada episódio derivado deve ter exatamente um resultado de análise.',
      );
    }
    for (var index = 0; index < episodes.length; index++) {
      final result = episodeAnalyses[index];
      if (!_sameEpisode(episodes[index], result.episode) ||
          result.coverageStatus != coverageStatus ||
          result.isProvisional != isProvisional ||
          !isCompatibleWith(result.versions)) {
        throw ArgumentError(
          'Resultado de episódio incompatível com a fotografia do lote.',
        );
      }
    }
  }

  final DateTime dayStart;
  final DateTime generatedAt;
  final DateTime? analyzedThrough;
  final CoverageStatus coverageStatus;
  final Duration? totalUsage;
  final int? unlockCount;
  final List<SmartphoneUsageEpisode> episodes;
  final List<EpisodeAnalysisResult> episodeAnalyses;
  final AnalysisArtifactVersions versions;
  final String? issueMessage;

  bool get isProvisional => analyzedThrough != null;

  bool isCompatibleWith(AnalysisArtifactVersions candidate) =>
      versions.calibrationVersion == candidate.calibrationVersion &&
      versions.catalogVersion == candidate.catalogVersion &&
      versions.owxIri == candidate.owxIri &&
      versions.owxVersion == candidate.owxVersion &&
      versions.owxCommit == candidate.owxCommit &&
      versions.owxHash == candidate.owxHash;

  DailyUsageSummary toDailySummary() {
    final analysis = coverageStatus.isAvailable
        ? DailyUsageAnalysis(
            dayStart: dayStart,
            episodes: episodes,
            unlockCount: unlockCount!,
          )
        : null;
    return DailyUsageSummary(
      dayStart: dayStart,
      coverageStatus: coverageStatus,
      lastUpdatedAt: generatedAt,
      analyzedThrough: analyzedThrough,
      totalUsage: totalUsage,
      analysis: analysis,
      episodeAnalyses: episodeAnalyses,
      issueMessage: issueMessage,
    );
  }
}

bool _sameEpisode(SmartphoneUsageEpisode left, SmartphoneUsageEpisode right) =>
    left.packageName == right.packageName &&
    left.startedAt == right.startedAt &&
    left.endedAt == right.endedAt &&
    left.duration == right.duration;
