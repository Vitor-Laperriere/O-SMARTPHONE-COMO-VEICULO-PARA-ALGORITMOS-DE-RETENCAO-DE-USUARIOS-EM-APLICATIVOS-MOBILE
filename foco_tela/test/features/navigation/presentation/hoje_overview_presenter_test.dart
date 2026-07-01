import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/catalog/domain/app_identity.dart';
import 'package:foco_tela/features/dashboard/domain/app_daily_aggregate.dart';
import 'package:foco_tela/features/dashboard/domain/behavioral_signal_calibration.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_summary.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/navigation/presentation/hoje_overview.dart';

void main() {
  test('agrupa por categoria e separa contexto insuficiente', () {
    final fixture = _fixture();

    final data = const TodayOverviewPresenter().present(
      dashboard: fixture.dashboard,
      catalog: fixture.catalog,
      identitiesByPackageName: fixture.identitiesByPackageName,
      grouping: TodayGrouping.category,
    );

    expect(data.screenTimeAvailable, isTrue);
    expect(data.screenTime, const Duration(hours: 4));
    expect(data.approvedContextShare, closeTo(0.5, 0.0001));
    expect(data.evaluatedTypeShare, closeTo(0.75, 0.0001));
    expect(data.retentionIndications.level, TodayRetentionIndicationLevel.high);
    expect(data.signals.isAvailable, isTrue);
    expect(data.signals.episodesWithSignals, 4);
    expect(data.signals.distinctActiveSignals, 3);
    expect(data.signals.maxIntensityRange, BehavioralScoreRange.high);
    expect(data.signals.approvedContextShare, closeTo(0.5, 0.0001));
    expect(data.signals.evaluatedTypeShare, closeTo(0.75, 0.0001));

    expect(
      data.slices.map((slice) => slice.label),
      containsAll(['retenção/social', 'casos mistos', 'Tipo não avaliado']),
    );

    final suggested = data.sliceById('category-suggested-mixed');
    expect(suggested, isNotNull);
    expect(suggested!.status, CatalogContextStatus.candidateAutomatic);
    expect(
      suggested.candidateAssociations.map((item) => item.label),
      contains('SocialValidation'),
    );

    final insufficient = data.sliceById('category-insufficient');
    expect(insufficient, isNotNull);
    expect(insufficient!.status, CatalogContextStatus.insufficient);
    expect(insufficient.apps, hasLength(1));
  });

  test('agrupa por aplicativo preservando status de catálogo', () {
    final fixture = _fixture();

    final data = const TodayOverviewPresenter().present(
      dashboard: fixture.dashboard,
      catalog: fixture.catalog,
      identitiesByPackageName: fixture.identitiesByPackageName,
      grouping: TodayGrouping.app,
    );

    expect(data.slices, hasLength(3));
    expect(
      data.slices.map((slice) => slice.label),
      containsAll(['Instagram', 'CapCut', 'Reader']),
    );

    final candidate = data.sliceById('app-com.lemon.lvoverseas');
    expect(candidate, isNotNull);
    expect(candidate!.status, CatalogContextStatus.candidateAutomatic);
    expect(candidate.subtitle, contains('Tipo sugerido'));

    final approved = data.sliceById('app-com.instagram.android');
    expect(approved, isNotNull);
    expect(approved!.status, CatalogContextStatus.approved);
    expect(approved.approvedAssociations, isNotEmpty);
  });
}

({
  WeeklyUsageDashboard dashboard,
  CatalogSnapshot catalog,
  Map<String, AppIdentity> identitiesByPackageName,
})
_fixture() {
  final day = DateTime(2026, 6, 21);
  final approvedEpisode = _episode(
    packageName: 'com.instagram.android',
    appName: 'Instagram',
    startedAt: DateTime(2026, 6, 21, 8),
  );
  final candidateEpisode = _episode(
    packageName: 'com.lemon.lvoverseas',
    appName: 'CapCut',
    startedAt: DateTime(2026, 6, 21, 9),
  );
  final unknownEpisode = _episode(
    packageName: 'com.example.reader',
    appName: 'Reader',
    startedAt: DateTime(2026, 6, 21, 10),
  );
  final extraApprovedEpisode = _episode(
    packageName: 'com.instagram.android',
    appName: 'Instagram',
    startedAt: DateTime(2026, 6, 21, 11),
  );

  final summary = DailyUsageSummary(
    dayStart: day,
    coverageStatus: CoverageStatus.sufficient,
    lastUpdatedAt: DateTime(2026, 6, 21, 14, 30),
    totalUsage: const Duration(hours: 4),
    analysis: DailyUsageAnalysis(
      dayStart: day,
      episodes: [
        approvedEpisode,
        candidateEpisode,
        unknownEpisode,
        extraApprovedEpisode,
      ],
      unlockCount: 40,
    ),
    notificationCount: 7,
    appAggregates: [
      AppDailyAggregate(
        dayStart: day,
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        duration: const Duration(hours: 2),
        episodeCount: 2,
        stateCounts: const <AnalysisState, int>{},
        coverageStatus: CoverageStatus.sufficient,
        generatedAt: DateTime(2026, 6, 21, 14, 30),
        versions: _versions,
      ),
      AppDailyAggregate(
        dayStart: day,
        packageName: 'com.lemon.lvoverseas',
        appName: 'CapCut',
        duration: const Duration(hours: 1),
        episodeCount: 1,
        stateCounts: const <AnalysisState, int>{},
        coverageStatus: CoverageStatus.sufficient,
        generatedAt: DateTime(2026, 6, 21, 14, 30),
        versions: _versions,
      ),
      AppDailyAggregate(
        dayStart: day,
        packageName: 'com.example.reader',
        appName: 'Reader',
        duration: const Duration(hours: 1),
        episodeCount: 1,
        stateCounts: const <AnalysisState, int>{},
        coverageStatus: CoverageStatus.sufficient,
        generatedAt: DateTime(2026, 6, 21, 14, 30),
        versions: _versions,
      ),
    ],
    episodeAnalyses: [
      _classifiedAnalysis(approvedEpisode, approvedContext: true),
      _classifiedAnalysis(candidateEpisode),
      _classifiedAnalysis(unknownEpisode),
      _classifiedAnalysis(extraApprovedEpisode, approvedContext: true),
    ],
  );

  final dashboard = WeeklyUsageDashboard(
    generatedAt: DateTime(2026, 6, 21, 14, 30),
    days: [summary],
    notificationAvailability:
        const NotificationsUnavailableForDashboard.available(),
  );

  final catalog = CatalogSnapshot(
    header: const CatalogHeader(
      version: 'catalog-test-v1',
      owxIri: 'urn:test:owl',
      owxVersion: 'owl-test-v1',
      owxCommit: 'abc123',
      owxHash: 'def456',
    ),
    apps: [_approvedCatalogApp(), _candidateCatalogApp()],
    evidence: [_evidence('approved-evidence'), _evidence('candidate-evidence')],
  );

  final identities = {
    'com.instagram.android': const AppIdentity(
      packageName: 'com.instagram.android',
      friendlyName: 'Instagram',
    ),
    'com.lemon.lvoverseas': const AppIdentity(
      packageName: 'com.lemon.lvoverseas',
      friendlyName: 'CapCut',
    ),
    'com.example.reader': const AppIdentity(
      packageName: 'com.example.reader',
      friendlyName: 'Reader',
    ),
  };

  return (
    dashboard: dashboard,
    catalog: catalog,
    identitiesByPackageName: identities,
  );
}

SmartphoneUsageEpisode _episode({
  required String packageName,
  required String appName,
  required DateTime startedAt,
}) {
  final endedAt = startedAt.add(const Duration(hours: 1));
  return SmartphoneUsageEpisode(
    packageName: packageName,
    appName: appName,
    startedAt: startedAt,
    endedAt: endedAt,
    duration: const Duration(hours: 1),
  );
}

ClassifiedEpisodeAnalysis _classifiedAnalysis(
  SmartphoneUsageEpisode episode, {
  bool approvedContext = false,
}) {
  final observations = [
    _signal(BehavioralSignalKind.longSessionDuration),
    _signal(BehavioralSignalKind.highScreenTime),
    _signal(BehavioralSignalKind.frequentUnlocking),
  ];
  return ClassifiedEpisodeAnalysis(
    episode: episode,
    coverageStatus: CoverageStatus.sufficient,
    isProvisional: false,
    signalObservations: observations,
    versions: _versions,
    behavioralScore: BehavioralSignalScore(
      value: 1.0,
      range: BehavioralScoreRange.high,
      contributions: observations,
    ),
    context: ContextualRetentionStrength(
      isAvailable: approvedContext,
      rawValue: approvedContext ? 1.0 : 0,
      matrixValue: approvedContext ? 1.0 : 0,
      cap: 2.0,
      range: approvedContext
          ? ContextualStrengthRange.high
          : ContextualStrengthRange.absent,
      contributions: const [],
    ),
    state: approvedContext
        ? AnalysisState.convergentIntensifiedRetentionSignals
        : AnalysisState.contextUnavailable,
    patternExplanation: const PatternExplanation(
      summary: 'Leitura exploratória.',
      caveat: 'Sem inferência causal.',
    ),
  );
}

BehavioralSignalObservation _signal(BehavioralSignalKind kind) =>
    BehavioralSignalObservation(
      kind: kind,
      scope: SignalScope.episode,
      isActive: true,
      weight: switch (kind) {
        BehavioralSignalKind.longSessionDuration => 0.5,
        BehavioralSignalKind.highScreenTime => 0.3,
        BehavioralSignalKind.frequentUnlocking => 0.2,
      },
      observedValue: 'observado',
      threshold: _threshold(kind),
    );

ThresholdDefinition _threshold(BehavioralSignalKind kind) => switch (kind) {
  BehavioralSignalKind.longSessionDuration => const ThresholdDefinition(
    id: 'long_session_duration_minutes',
    kind: ThresholdKind.behavioral,
    value: 15,
    unit: 'minutes',
    justification: 'Teste.',
    version: '2026-06-21-v1',
  ),
  BehavioralSignalKind.highScreenTime => const ThresholdDefinition(
    id: 'high_screen_time_hours_per_day',
    kind: ThresholdKind.behavioral,
    value: 4,
    unit: 'hours/day',
    justification: 'Teste.',
    version: '2026-06-21-v1',
  ),
  BehavioralSignalKind.frequentUnlocking => const ThresholdDefinition(
    id: 'frequent_unlocks_per_day',
    kind: ThresholdKind.behavioral,
    value: 40,
    unit: 'unlocks/day',
    justification: 'Teste.',
    version: '2026-06-21-v1',
  ),
};

CatalogApp _approvedCatalogApp() => CatalogApp(
  packageName: 'com.instagram.android',
  displayName: 'Instagram',
  sampleGroup: CatalogSampleGroup.retentionSocial,
  technicalMechanisms: [_approvedAssociation('FeedAlgorithm')],
  osComponents: const [],
);

CatalogApp _candidateCatalogApp() => CatalogApp(
  packageName: 'com.lemon.lvoverseas',
  displayName: 'CapCut',
  sampleGroup: CatalogSampleGroup.mixed,
  technicalMechanisms: [_candidateAssociation('SocialValidation')],
  osComponents: const [],
);

CatalogAssociation _approvedAssociation(String iri) => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: iri,
  label: iri,
  contextualRole: CatalogContextualRole.retention,
  confidence: CatalogConfidence.high,
  evidence: [_evidence('${iri.toLowerCase()}-evidence')],
);

CatalogAssociation _candidateAssociation(String iri) => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: iri,
  label: iri,
  contextualRole: CatalogContextualRole.undetermined,
  confidence: CatalogConfidence.medium,
  evidence: [_evidence('${iri.toLowerCase()}-evidence')],
);

CatalogEvidence _evidence(String id) => CatalogEvidence(
  id: id,
  type: CatalogEvidenceType.appStoreListing,
  reference: 'https://example.test/$id',
  date: DateTime(2026, 6, 21),
  observedVersion: '2026-06-21',
  supportedStatement: 'Teste.',
  scope: 'app_specific',
);

const AnalysisArtifactVersions _versions = AnalysisArtifactVersions(
  calibrationVersion: '2026-06-21-v1',
  catalogVersion: 'catalog-test-v1',
  owxIri: 'urn:test:owl',
  owxVersion: 'owl-test-v1',
  owxCommit: 'abc123',
  owxHash: 'def456',
);
