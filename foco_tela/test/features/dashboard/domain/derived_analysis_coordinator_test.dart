import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/data/in_memory_derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/derived_analysis_batch.dart';
import 'package:foco_tela/features/dashboard/domain/derived_analysis_coordinator.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/episode_classifier.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/dashboard/domain/analysis_window.dart';
import 'package:foco_tela/features/notifications/data/in_memory_notification_repository.dart';
import 'package:foco_tela/features/notifications/domain/notification_observation.dart';

void main() {
  test(
    'classifica e persiste cada dia antes de entregá-lo à apresentação',
    () async {
      final derived = InMemoryDerivedAnalysisRepository();
      final coordinator = DerivedAnalysisCoordinator(
        usageRepository: _UsageRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedRepository: derived,
        now: () => DateTime(2026, 6, 21, 14, 30),
      );

      final dashboard = await coordinator.load();
      final yesterday = dashboard.summaryFor(DateTime(2026, 6, 20))!;

      expect(yesterday.episodeAnalyses, hasLength(1));
      expect(
        yesterday.episodeAnalyses.single,
        isA<ClassifiedEpisodeAnalysis>(),
      );
      expect(await derived.loadDay(DateTime(2026, 6, 20)), isNotNull);
    },
  );

  test(
    'derivado suficiente compatível completa dia fora do horizonte',
    () async {
      final derived = InMemoryDerivedAnalysisRepository();
      final preserved = _preservedBatch(
        day: DateTime(2026, 6, 15),
        versions: EpisodeClassifier().artifactVersionsFor(_catalog()),
      );
      await derived.save(preserved);
      final coordinator = DerivedAnalysisCoordinator(
        usageRepository: _UsageRepository(
          unavailableDay: DateTime(2026, 6, 15),
        ),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedRepository: derived,
        now: () => DateTime(2026, 6, 21, 14, 30),
      );

      final dashboard = await coordinator.load();
      final recovered = dashboard.summaryFor(DateTime(2026, 6, 15))!;

      expect(recovered.coverageStatus, CoverageStatus.sufficient);
      expect(recovered.episodes.single.packageName, 'com.example.preserved');
      expect(recovered.episodeAnalyses, hasLength(1));
    },
  );

  test(
    'derivado incompatível não completa a cobertura e outro dia permanece válido',
    () async {
      final derived = InMemoryDerivedAnalysisRepository();
      await derived.save(
        _preservedBatch(
          day: DateTime(2026, 6, 15),
          versions: const AnalysisArtifactVersions(
            calibrationVersion: 'incompatível',
            catalogVersion: 'catalog-v1',
            owxIri: 'urn:test:owl',
            owxVersion: 'owl-v1',
            owxCommit: 'abc123',
            owxHash: 'def456',
          ),
        ),
      );
      final coordinator = DerivedAnalysisCoordinator(
        usageRepository: _UsageRepository(
          unavailableDay: DateTime(2026, 6, 15),
        ),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedRepository: derived,
        now: () => DateTime(2026, 6, 21, 14, 30),
      );

      final dashboard = await coordinator.load();

      expect(
        dashboard.summaryFor(DateTime(2026, 6, 15))!.coverageStatus,
        CoverageStatus.unavailable,
      );
      expect(
        dashboard.summaryFor(DateTime(2026, 6, 20))!.coverageStatus,
        CoverageStatus.sufficient,
      );
    },
  );

  test(
    'compara a janela atual com período anterior equivalente sem fabricar indisponibilidade',
    () async {
      final derived = InMemoryDerivedAnalysisRepository();
      final versions = EpisodeClassifier().artifactVersionsFor(_catalog());
      for (var day = 8; day <= 14; day++) {
        await derived.save(
          _preservedBatch(day: DateTime(2026, 6, day), versions: versions),
        );
      }
      final coordinator = DerivedAnalysisCoordinator(
        usageRepository: _UsageRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedRepository: derived,
        notificationRepository: InMemoryNotificationRepository(
          accessStatus: NotificationAccessStatus.granted,
          counts: [
            DailyNotificationCount(
              dayStart: DateTime(2026, 6, 20),
              packageName: 'com.example.social',
              count: 2,
            ),
            DailyNotificationCount(
              dayStart: DateTime(2026, 6, 10),
              packageName: 'com.example.social',
              count: 1,
            ),
          ],
        ),
        now: () => DateTime(2026, 6, 21, 14, 30),
      );

      final dashboard = await coordinator.load();

      expect(dashboard.comparison.isAvailable, isTrue);
      expect(dashboard.comparison.activeTimeMinutes?.previous, 70);
      expect(dashboard.comparison.episodeCount?.previous, 7);
      expect(dashboard.comparison.notificationCount?.current, 2);
      expect(dashboard.comparison.notificationCount?.previous, 1);
      expect(dashboard.summaryFor(DateTime(2026, 6, 20))?.notificationCount, 2);
    },
  );

  test(
    'recorte semestral inclui dias antigos somente como agregados selecionáveis',
    () async {
      final derived = InMemoryDerivedAnalysisRepository();
      await derived.save(
        _preservedBatch(
          day: DateTime(2026, 1, 15),
          versions: EpisodeClassifier().artifactVersionsFor(_catalog()),
        ),
      );
      final coordinator = DerivedAnalysisCoordinator(
        usageRepository: _UsageRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedRepository: derived,
        now: () => DateTime(2026, 6, 21, 14, 30),
      );

      final dashboard = await coordinator.load(window: AnalysisWindow.semester);
      final aggregateOnlyDay = dashboard.summaryFor(DateTime(2026, 1, 15));

      expect(aggregateOnlyDay, isNotNull);
      expect(aggregateOnlyDay!.episodes, isEmpty);
      expect(aggregateOnlyDay.appAggregates, isNotEmpty);
      expect(aggregateOnlyDay.canOpenDetail, isTrue);
    },
  );
}

class _UsageRepository implements UsageRepository {
  _UsageRepository({this.unavailableDay});

  final DateTime? unavailableDay;

  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    if (normalized == unavailableDay) {
      throw StateError('Eventos fora do horizonte validado.');
    }
    final episodes = normalized == DateTime(2026, 6, 20)
        ? [
            SmartphoneUsageEpisode(
              packageName: 'com.example.social',
              appName: 'Social',
              startedAt: DateTime(2026, 6, 20, 10),
              endedAt: DateTime(2026, 6, 20, 10, 20),
              duration: const Duration(minutes: 20),
            ),
          ]
        : const <SmartphoneUsageEpisode>[];
    return DailyUsageAnalysis(
      dayStart: normalized,
      episodes: episodes,
      unlockCount: normalized == DateTime(2026, 6, 20) ? 40 : 0,
    );
  }
}

CatalogSnapshot _catalog() {
  final evidence = CatalogEvidence(
    id: 'evidence-a',
    type: CatalogEvidenceType.appStoreListing,
    reference: 'https://example.test/evidence-a',
    date: DateTime(2026, 6, 20),
    observedVersion: '2026-06-20',
    supportedStatement: 'Evidência específica.',
    scope: 'app_specific',
  );
  return CatalogSnapshot(
    header: const CatalogHeader(
      version: 'catalog-v1',
      owxIri: 'urn:test:owl',
      owxVersion: 'owl-v1',
      owxCommit: 'abc123',
      owxHash: 'def456',
    ),
    apps: [
      CatalogApp(
        packageName: 'com.example.social',
        displayName: 'Social',
        sampleGroup: CatalogSampleGroup.retentionSocial,
        technicalMechanisms: [
          CatalogAssociation(
            kind: CatalogAssociationKind.technicalMechanism,
            iri: 'InfiniteScrollFeed',
            label: 'Rolagem infinita',
            contextualRole: CatalogContextualRole.retention,
            confidence: CatalogConfidence.medium,
            evidence: [evidence],
          ),
        ],
        osComponents: const [],
      ),
    ],
    evidence: [evidence],
  );
}

DerivedAnalysisBatch _preservedBatch({
  required DateTime day,
  required AnalysisArtifactVersions versions,
}) {
  final episode = SmartphoneUsageEpisode(
    packageName: 'com.example.preserved',
    appName: 'Preservado',
    startedAt: day.add(const Duration(hours: 9)),
    endedAt: day.add(const Duration(hours: 9, minutes: 10)),
    duration: const Duration(minutes: 10),
  );
  final result = UnclassifiedEpisodeAnalysis(
    episode: episode,
    coverageStatus: CoverageStatus.sufficient,
    isProvisional: false,
    signalObservations: const [],
    versions: versions,
    reason: EpisodeAnalysisUnavailableReason.incompleteDailyCoverage,
  );
  return DerivedAnalysisBatch(
    dayStart: day,
    generatedAt: DateTime(2026, 6, 16),
    coverageStatus: CoverageStatus.sufficient,
    totalUsage: const Duration(minutes: 10),
    unlockCount: 3,
    episodes: [episode],
    episodeAnalyses: [result],
    versions: versions,
  );
}
