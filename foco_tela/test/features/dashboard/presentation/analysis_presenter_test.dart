import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/domain/analysis_window.dart';
import 'package:foco_tela/features/dashboard/domain/behavioral_signal_calibration.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_summary.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/score_total.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/presentation/analysis_presenter.dart';

void main() {
  test('monta resumo da janela sem ranking de apps ou estados completos', () {
    final data = const AnalysisPagePresenter().present(_dashboard());

    expect(data.selectedWindow, AnalysisWindow.sevenDays);
    expect(data.summary.headline, contains('tempo de tela observado reduziu'));
    expect(data.summary.metrics.map((metric) => metric.label), [
      'Tempo de tela',
      'Episódios',
      'Notificações',
    ]);
    expect(data.summary.coverageLabel, 'Cobertura: 1 de 1 dias carregados');
    expect(data.summary.headline, isNot(contains('Apps por duração')));
    expect(data.summary.headline, isNot(contains('Estados')));
  });

  test('seleciona sinais e associações curadas com rastreabilidade', () {
    final data = const AnalysisPagePresenter().present(_dashboard());

    expect(
      data.observedConcepts.map((concept) => concept.label),
      containsAll(['Sessão longa', 'Infinite Scroll Feed', 'Validação social']),
    );
    final curated = data.observedConcepts.firstWhere(
      (concept) => concept.label == 'Validação social',
    );
    expect(curated.iri, 'SocialValidation');
    expect(curated.scope, 'app_specific_catalog_association');
    expect(curated.caution, contains('Curada'));
  });

  test('prioriza indícios de retenção antes de tempo e episódios', () {
    final data = const AnalysisPagePresenter().present(_dashboard());

    expect(data.periodChange.priority, PeriodChangePriority.retention);
    expect(data.periodChange.headline, contains('1 episódio(s) altos'));
    expect(data.periodChange.detail, contains('não cria score longitudinal'));
  });
}

WeeklyUsageDashboard _dashboard() {
  final episode = SmartphoneUsageEpisode(
    packageName: 'com.example.social',
    appName: 'Social',
    startedAt: DateTime(2026, 6, 26, 9),
    endedAt: DateTime(2026, 6, 26, 9, 40),
    duration: const Duration(minutes: 40),
  );
  final day = DailyUsageSummary(
    dayStart: DateTime(2026, 6, 26),
    coverageStatus: CoverageStatus.sufficient,
    lastUpdatedAt: DateTime(2026, 6, 26, 11),
    totalUsage: const Duration(hours: 2),
    notificationCount: 8,
    analysis: DailyUsageAnalysis(
      dayStart: DateTime(2026, 6, 26),
      episodes: [episode],
      unlockCount: 30,
    ),
    episodeAnalyses: [_classified(episode)],
  );
  return WeeklyUsageDashboard(
    generatedAt: DateTime(2026, 6, 26, 11),
    window: AnalysisWindow.sevenDays,
    days: [day],
    notificationAvailability:
        const NotificationsUnavailableForDashboard.available(),
    notificationCounts: [
      DailyNotificationCountForDashboard(
        dayStart: DateTime(2026, 6, 26),
        packageName: 'com.example.social',
        count: 8,
      ),
    ],
    comparison: const WindowComparison(
      activeTimeMinutes: WindowMetricComparison(
        current: 120,
        previous: 180,
        unit: 'min',
      ),
      episodeCount: WindowMetricComparison(
        current: 1,
        previous: 2,
        unit: 'episódios',
      ),
      notificationCount: null,
    ),
  );
}

ClassifiedEpisodeAnalysis _classified(SmartphoneUsageEpisode episode) {
  final signal = BehavioralSignalObservation(
    kind: BehavioralSignalKind.longSessionDuration,
    scope: SignalScope.episode,
    isActive: true,
    weight: 0.5,
    observedValue: '2400 seconds',
    threshold: const ThresholdDefinition(
      id: 'long_session_duration_minutes',
      kind: ThresholdKind.behavioral,
      value: 15,
      unit: 'minutes',
      justification: 'Teste.',
      version: '2026-06-21-v1',
    ),
  );
  final curated = CatalogAssociation(
    kind: CatalogAssociationKind.psychologicalTechnique,
    iri: 'SocialValidation',
    label: 'Validação social',
    contextualRole: CatalogContextualRole.retention,
    confidence: CatalogConfidence.high,
    evidence: [_evidence()],
    relation: 'usesTechnique via SocialValidation',
    scope: 'app_specific_catalog_association',
    caution: 'Curada e cautelosa.',
  );
  return ClassifiedEpisodeAnalysis(
    episode: episode,
    coverageStatus: CoverageStatus.sufficient,
    isProvisional: false,
    signalObservations: [signal],
    versions: _versions,
    behavioralScore: BehavioralSignalScore(
      value: 1.0,
      range: BehavioralScoreRange.high,
      contributions: [signal],
    ),
    context: ContextualRetentionStrength(
      isAvailable: true,
      rawValue: 1.0,
      matrixValue: 1.0,
      cap: 2.0,
      range: ContextualStrengthRange.high,
      contributions: [
        ContextualRetentionContribution(
          iri: 'InfiniteScrollFeed',
          label: 'Infinite Scroll Feed',
          confidence: CatalogConfidence.high,
          weight: 1.0,
          evidence: [_evidence()],
        ),
      ],
    ),
    scoreTotal: ScoreTotalAssessment(
      value: 0.75,
      band: ScoreTotalBand.high,
      algorithmVersion: 'score-total-2026-06-26-v1',
      dimensions: const [],
      curatedAssociations: [curated],
    ),
    state: AnalysisState.convergentIntensifiedRetentionSignals,
    patternExplanation: null,
  );
}

CatalogEvidence _evidence() => CatalogEvidence(
  id: 'evidence',
  type: CatalogEvidenceType.appStoreListing,
  reference: 'https://example.test',
  date: DateTime(2026, 6, 26),
  observedVersion: '2026-06-26',
  supportedStatement: 'Evidência de teste.',
  scope: 'app_specific',
);

const _versions = AnalysisArtifactVersions(
  calibrationVersion: 'calibration-v1',
  catalogVersion: 'catalog-v1',
  owxIri: 'urn:test:owl',
  owxVersion: 'owl-v1',
  owxCommit: 'abc123',
  owxHash: 'def456',
);
