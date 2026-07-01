import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/domain/behavioral_signal_calibration.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_summary.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/episode_classifier.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';

void main() {
  test('classifica sinais altos e contexto médio como convergentes', () {
    final episode = SmartphoneUsageEpisode(
      packageName: 'com.example.social',
      appName: 'App Social',
      startedAt: DateTime(2026, 6, 20, 10),
      endedAt: DateTime(2026, 6, 20, 10, 20),
      duration: const Duration(minutes: 20),
    );
    final day = DailyUsageSummary(
      dayStart: DateTime(2026, 6, 20),
      coverageStatus: CoverageStatus.sufficient,
      lastUpdatedAt: DateTime(2026, 6, 21, 14, 30),
      totalUsage: const Duration(hours: 4),
      analysis: DailyUsageAnalysis(
        dayStart: DateTime(2026, 6, 20),
        episodes: [episode],
        unlockCount: 40,
      ),
    );

    final result = EpisodeClassifier().analyze(
      episode: episode,
      day: day,
      catalog: _catalog(
        app: _catalogApp(
          technicalMechanisms: [
            _association(
              iri: 'InfiniteScrollFeed',
              confidence: CatalogConfidence.medium,
            ),
          ],
        ),
      ),
    );

    expect(result, isA<ClassifiedEpisodeAnalysis>());
    final classified = result as ClassifiedEpisodeAnalysis;
    expect(classified.behavioralScore.value, 1.0);
    expect(classified.behavioralScore.range, BehavioralScoreRange.high);
    expect(
      classified.behavioralScore.contributions.map((item) => item.weight),
      [0.5, 0.3, 0.2],
    );
    expect(classified.behavioralScore.contributions.map((item) => item.scope), [
      SignalScope.episode,
      SignalScope.sharedDay,
      SignalScope.sharedDay,
    ]);
    expect(classified.context.rawValue, 0.5);
    expect(classified.context.matrixValue, 0.5);
    expect(classified.context.range, ContextualStrengthRange.medium);
    expect(
      classified.state,
      AnalysisState.convergentIntensifiedRetentionSignals,
    );
    expect(classified.patternExplanation, isNotNull);
    expect(classified.versions.calibrationVersion, '2026-06-21-v1');
    expect(classified.versions.catalogVersion, 'catalog-v1');
    expect(classified.versions.owxVersion, 'owl-v1');
  });

  test('sugestão automática não conta como contexto aprovado', () {
    final fixture = _eligibleFixture();

    final result =
        EpisodeClassifier().analyze(
              episode: fixture.episode,
              day: fixture.day,
              catalog: _catalog(
                app: _catalogApp(
                  technicalMechanisms: [
                    _association(
                      iri: 'SocialValidation',
                      confidence: CatalogConfidence.medium,
                      role: CatalogContextualRole.undetermined,
                    ),
                  ],
                ),
              ),
            )
            as ClassifiedEpisodeAnalysis;

    expect(result.context.isAvailable, isFalse);
    expect(result.context.rawValue, 0);
    expect(result.context.matrixValue, 0);
    expect(result.context.range, ContextualStrengthRange.absent);
    expect(result.state, AnalysisState.contextUnavailable);
    expect(result.behavioralScore.range, BehavioralScoreRange.high);
  });

  test('deduplica o peso por IRI e preserva as evidências auditáveis', () {
    final fixture = _eligibleFixture();
    final first = _association(
      iri: 'InfiniteScrollFeed',
      confidence: CatalogConfidence.low,
      evidenceId: 'evidence-a',
    );
    final second = _association(
      iri: 'InfiniteScrollFeed',
      confidence: CatalogConfidence.high,
      evidenceId: 'evidence-b',
    );

    final result =
        EpisodeClassifier().analyze(
              episode: fixture.episode,
              day: fixture.day,
              catalog: _catalog(
                app: _catalogApp(technicalMechanisms: [first, second]),
              ),
            )
            as ClassifiedEpisodeAnalysis;

    expect(result.context.rawValue, 1.0);
    expect(result.context.matrixValue, 1.0);
    expect(result.context.contributions, hasLength(1));
    expect(
      result.context.contributions.single.evidence.map((item) => item.id),
      containsAll(<String>['evidence-a', 'evidence-b']),
    );
  });

  test('a matriz produz somente os quatro estados aprovados', () {
    final lowSignals = _fixture(
      episodeDuration: const Duration(minutes: 5),
      totalUsage: const Duration(hours: 1),
      unlockCount: 5,
    );
    final mediumSignals = _fixture(
      episodeDuration: const Duration(minutes: 15),
      totalUsage: const Duration(hours: 1),
      unlockCount: 5,
    );
    final highSignals = _eligibleFixture();
    final mediumContext = _catalogApp(
      technicalMechanisms: [
        _association(
          iri: 'FeedAlgorithm',
          confidence: CatalogConfidence.medium,
        ),
      ],
    );
    final lowContext = _catalogApp(
      technicalMechanisms: [
        _association(iri: 'FeedAlgorithm', confidence: CatalogConfidence.low),
      ],
    );

    AnalysisState stateFor(
      ({SmartphoneUsageEpisode episode, DailyUsageSummary day}) fixture,
      CatalogSnapshot catalog,
    ) =>
        (EpisodeClassifier().analyze(
                  episode: fixture.episode,
                  day: fixture.day,
                  catalog: catalog,
                )
                as ClassifiedEpisodeAnalysis)
            .state;

    final states = {
      stateFor(highSignals, _catalog()),
      stateFor(lowSignals, _catalog(app: mediumContext)),
      stateFor(mediumSignals, _catalog(app: mediumContext)),
      stateFor(highSignals, _catalog(app: lowContext)),
      stateFor(highSignals, _catalog(app: mediumContext)),
    };

    expect(states, AnalysisState.values.toSet());
    expect(
      stateFor(highSignals, _catalog(app: lowContext)),
      AnalysisState.signalsForReview,
    );
    expect(
      stateFor(highSignals, _catalog(app: mediumContext)),
      AnalysisState.convergentIntensifiedRetentionSignals,
    );
  });

  test(
    'aplica pesos contextuais, preserva soma bruta e limita a matriz ao teto',
    () {
      final fixture = _eligibleFixture();
      final app = _catalogApp(
        technicalMechanisms: [
          _association(iri: 'LowRetention', confidence: CatalogConfidence.low),
          _association(
            iri: 'MediumRetention',
            confidence: CatalogConfidence.medium,
          ),
          _association(
            iri: 'HighRetentionA',
            confidence: CatalogConfidence.high,
          ),
          _association(
            iri: 'HighRetentionB',
            confidence: CatalogConfidence.high,
          ),
          _association(
            iri: 'UnavailableRetention',
            confidence: CatalogConfidence.unavailable,
          ),
          _association(
            iri: 'UtilityOnly',
            confidence: CatalogConfidence.high,
            role: CatalogContextualRole.utility,
          ),
        ],
      );

      final result =
          EpisodeClassifier().analyze(
                episode: fixture.episode,
                day: fixture.day,
                catalog: _catalog(app: app),
              )
              as ClassifiedEpisodeAnalysis;

      expect(result.context.rawValue, 2.6);
      expect(result.context.matrixValue, 2.0);
      expect(result.context.cap, 2.0);
      expect(result.context.range, ContextualStrengthRange.high);
      expect(
        result.context.contributions.map((item) => item.weight),
        containsAll(<double>[0.1, 0.5, 1.0, 1.0, 0.0]),
      );
      expect(
        result.context.contributions.map((item) => item.iri),
        isNot(contains('UtilityOnly')),
      );
    },
  );

  test(
    'NotificationCount não altera score_sinais, sinais ativos ou estado V3',
    () {
      final withoutNotifications = _eligibleFixture();
      final withNotifications = _fixture(
        episodeDuration: const Duration(minutes: 20),
        totalUsage: const Duration(hours: 4),
        unlockCount: 40,
        notificationCount: 80,
      );
      final catalog = _catalog(
        app: _catalogApp(
          technicalMechanisms: [
            _association(
              iri: 'PushNotification',
              confidence: CatalogConfidence.high,
            ),
          ],
        ),
      );

      final baseline =
          EpisodeClassifier().analyze(
                episode: withoutNotifications.episode,
                day: withoutNotifications.day,
                catalog: catalog,
              )
              as ClassifiedEpisodeAnalysis;
      final compared =
          EpisodeClassifier().analyze(
                episode: withNotifications.episode,
                day: withNotifications.day,
                catalog: catalog,
              )
              as ClassifiedEpisodeAnalysis;

      expect(compared.behavioralScore.value, baseline.behavioralScore.value);
      expect(compared.behavioralScore.range, baseline.behavioralScore.range);
      expect(compared.state, baseline.state);
      expect(compared.signalObservations.map((signal) => signal.kind), [
        BehavioralSignalKind.longSessionDuration,
        BehavioralSignalKind.highScreenTime,
        BehavioralSignalKind.frequentUnlocking,
      ]);
    },
  );

  test('dia encerrado parcial não executa a matriz dependente do dia', () {
    final fixture = _fixture(
      episodeDuration: const Duration(minutes: 20),
      totalUsage: const Duration(hours: 4),
      unlockCount: 40,
      coverageStatus: CoverageStatus.partial,
    );

    final result = EpisodeClassifier().analyze(
      episode: fixture.episode,
      day: fixture.day,
      catalog: _catalog(app: _catalogApp()),
    );

    expect(result, isA<UnclassifiedEpisodeAnalysis>());
    final unavailable = result as UnclassifiedEpisodeAnalysis;
    expect(
      unavailable.reason,
      EpisodeAnalysisUnavailableReason.incompleteDailyCoverage,
    );
    expect(unavailable.signalObservations, hasLength(1));
    expect(unavailable.signalObservations.single.scope, SignalScope.episode);
  });
}

({SmartphoneUsageEpisode episode, DailyUsageSummary day}) _eligibleFixture() {
  return _fixture(
    episodeDuration: const Duration(minutes: 20),
    totalUsage: const Duration(hours: 4),
    unlockCount: 40,
  );
}

({SmartphoneUsageEpisode episode, DailyUsageSummary day}) _fixture({
  required Duration episodeDuration,
  required Duration totalUsage,
  required int unlockCount,
  int? notificationCount,
  CoverageStatus coverageStatus = CoverageStatus.sufficient,
}) {
  final episode = SmartphoneUsageEpisode(
    packageName: 'com.example.social',
    appName: 'App Social',
    startedAt: DateTime(2026, 6, 20, 10),
    endedAt: DateTime(2026, 6, 20, 10).add(episodeDuration),
    duration: episodeDuration,
  );
  return (
    episode: episode,
    day: DailyUsageSummary(
      dayStart: DateTime(2026, 6, 20),
      coverageStatus: coverageStatus,
      lastUpdatedAt: DateTime(2026, 6, 21, 14, 30),
      totalUsage: totalUsage,
      notificationCount: notificationCount,
      analysis: DailyUsageAnalysis(
        dayStart: DateTime(2026, 6, 20),
        episodes: [episode],
        unlockCount: unlockCount,
      ),
    ),
  );
}

CatalogSnapshot _catalog({CatalogApp? app}) => CatalogSnapshot(
  header: const CatalogHeader(
    version: 'catalog-v1',
    owxIri: 'urn:test:owl',
    owxVersion: 'owl-v1',
    owxCommit: 'abc123',
    owxHash: 'def456',
  ),
  apps: [if (app != null) app],
  evidence: const [],
);

CatalogApp _catalogApp({
  List<CatalogAssociation> technicalMechanisms = const [],
  List<CatalogAssociation> osComponents = const [],
}) => CatalogApp(
  packageName: 'com.example.social',
  displayName: 'App Social',
  sampleGroup: CatalogSampleGroup.retentionSocial,
  technicalMechanisms: technicalMechanisms,
  osComponents: osComponents,
);

CatalogAssociation _association({
  required String iri,
  required CatalogConfidence confidence,
  CatalogContextualRole role = CatalogContextualRole.retention,
  String? evidenceId,
}) => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: iri,
  label: iri,
  contextualRole: role,
  confidence: confidence,
  evidence: [
    CatalogEvidence(
      id: evidenceId ?? 'evidence-$iri',
      type: CatalogEvidenceType.appStoreListing,
      reference: 'https://example.test/$iri',
      date: DateTime(2026, 6, 21),
      observedVersion: '2026-06-21',
      supportedStatement: 'Evidência específica para $iri.',
      scope: 'app_specific',
    ),
  ],
);
