import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/domain/derived_analysis_batch.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';

void main() {
  test('lote derivado preserva uma fotografia imutável completa do dia', () {
    final episode = SmartphoneUsageEpisode(
      packageName: 'com.example.social',
      appName: 'Social',
      startedAt: DateTime(2026, 6, 21, 10),
      endedAt: DateTime(2026, 6, 21, 10, 20),
      duration: const Duration(minutes: 20),
    );
    final episodes = [episode];
    final analyses = <EpisodeAnalysisResult>[_unclassified(episode: episode)];

    final batch = DerivedAnalysisBatch(
      dayStart: DateTime(2026, 6, 21),
      generatedAt: DateTime(2026, 6, 21, 14, 30),
      analyzedThrough: DateTime(2026, 6, 21, 14, 30),
      coverageStatus: CoverageStatus.partial,
      totalUsage: const Duration(minutes: 20),
      unlockCount: 7,
      episodes: episodes,
      episodeAnalyses: analyses,
      versions: _versions,
    );

    episodes.clear();
    analyses.clear();

    expect(batch.episodes, [episode]);
    expect(batch.episodeAnalyses, hasLength(1));
    expect(batch.coverageStatus, CoverageStatus.partial);
    expect(batch.isProvisional, isTrue);
    expect(batch.toDailySummary().analysisForEpisode(episode), isNotNull);
    expect(() => batch.episodes.add(episode), throwsUnsupportedError);
  });

  test('compatibilidade exige todas as versões dos artefatos', () {
    final batch = DerivedAnalysisBatch(
      dayStart: DateTime(2026, 6, 20),
      generatedAt: DateTime(2026, 6, 21),
      coverageStatus: CoverageStatus.sufficient,
      totalUsage: Duration.zero,
      unlockCount: 0,
      episodes: const [],
      episodeAnalyses: const [],
      versions: _versions,
    );

    expect(batch.isCompatibleWith(_versions), isTrue);
    expect(
      batch.isCompatibleWith(
        const AnalysisArtifactVersions(
          calibrationVersion: 'calibration-v2',
          catalogVersion: 'catalog-v1',
          owxIri: 'urn:test:owl',
          owxVersion: 'owl-v1',
          owxCommit: 'abc123',
          owxHash: 'def456',
        ),
      ),
      isFalse,
    );
  });
}

const _versions = AnalysisArtifactVersions(
  calibrationVersion: 'calibration-v1',
  catalogVersion: 'catalog-v1',
  owxIri: 'urn:test:owl',
  owxVersion: 'owl-v1',
  owxCommit: 'abc123',
  owxHash: 'def456',
);

EpisodeAnalysisResult _unclassified({required SmartphoneUsageEpisode episode}) {
  return UnclassifiedEpisodeAnalysis(
    episode: episode,
    coverageStatus: CoverageStatus.partial,
    isProvisional: true,
    signalObservations: const [],
    versions: _versions,
    reason: EpisodeAnalysisUnavailableReason.incompleteDailyCoverage,
  );
}
