import 'package:flutter_test/flutter_test.dart';
import 'package:foco_tela/features/apps/presentation/apps_presenter.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/catalog/domain/app_identity.dart';
import 'package:foco_tela/features/dashboard/domain/app_daily_aggregate.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_summary.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';

void main() {
  test('lista app observado sem catalogo como contexto insuficiente', () {
    final model = const AppsPresenter().present(
      dashboard: _dashboard([
        _aggregate(
          packageName: 'com.unknown.reader',
          appName: 'Reader tecnico',
          minutes: 42,
          episodes: 3,
        ),
      ]),
      catalog: _catalog(apps: const []),
      identitiesByPackageName: {
        'com.unknown.reader': const AppIdentity(
          packageName: 'com.unknown.reader',
          friendlyName: 'Leitor Local',
        ),
      },
    );

    expect(model.apps, hasLength(1));
    expect(model.apps.single.displayName, 'Leitor Local');
    expect(model.apps.single.packageName, 'com.unknown.reader');
    expect(model.apps.single.status, CatalogContextStatus.insufficient);
    expect(model.apps.single.todayDuration, const Duration(minutes: 42));
    expect(model.apps.single.weekDuration, const Duration(minutes: 42));
    expect(model.apps.single.episodeCount, 3);
  });

  test('filtra aprovado candidato automatico e insuficiente sem misturar', () {
    final model = const AppsPresenter().present(
      dashboard: _dashboard([
        _aggregate(
          packageName: 'com.approved.social',
          appName: 'Social tecnico',
          minutes: 30,
          episodes: 2,
        ),
        _aggregate(
          packageName: 'com.candidate.shortvideo',
          appName: 'Short video tecnico',
          minutes: 25,
          episodes: 2,
        ),
        _aggregate(
          packageName: 'com.unknown.reader',
          appName: 'Reader tecnico',
          minutes: 10,
          episodes: 1,
        ),
      ]),
      catalog: _catalog(
        apps: [
          _catalogApp(
            packageName: 'com.approved.social',
            displayName: 'Social aprovado',
            associations: [_approvedAssociation('SocialNetworkApp')],
          ),
          _catalogApp(
            packageName: 'com.candidate.shortvideo',
            displayName: 'Short Video sugerido',
            associations: [_candidateAssociation('ShortVideoApp')],
          ),
        ],
      ),
      identitiesByPackageName: const {},
    );

    expect(
      model.appsForStatus(CatalogContextStatus.approved).single.packageName,
      'com.approved.social',
    );
    expect(
      model.appsForStatus(
        CatalogContextStatus.candidateAutomatic,
      ).single.packageName,
      'com.candidate.shortvideo',
    );
    expect(
      model.appsForStatus(CatalogContextStatus.insufficient).single.packageName,
      'com.unknown.reader',
    );
  });

  test('agrega notificacoes por app sem criar uso ou episodios ficticios', () {
    final model = const AppsPresenter().present(
      dashboard: _dashboard(
        [
          _aggregate(
            packageName: 'com.chat',
            appName: 'Chat',
            minutes: 0,
            episodes: 0,
          ),
        ],
        notifications: [
          DailyNotificationCountForDashboard(
            dayStart: _today,
            packageName: 'com.chat',
            count: 5,
          ),
        ],
      ),
      catalog: _catalog(apps: const []),
      identitiesByPackageName: const {},
    );

    expect(model.apps.single.weekNotificationCount, 5);
    expect(model.apps.single.todayNotificationCount, 5);
    expect(model.apps.single.weekDuration, Duration.zero);
    expect(model.apps.single.episodeCount, 0);
  });
}

CatalogSnapshot _catalog({required List<CatalogApp> apps}) => CatalogSnapshot(
  header: const CatalogHeader(
    version: 'catalog-test-v3',
    owxIri: 'urn:test:owl',
    owxVersion: 'owl-test',
    owxCommit: 'abc123',
    owxHash: 'def456',
  ),
  apps: apps,
  evidence: const [],
);

final _today = DateTime(2026, 6, 23);

WeeklyUsageDashboard _dashboard(
  List<AppDailyAggregate> aggregates, {
  List<DailyNotificationCountForDashboard> notifications = const [],
}) =>
    WeeklyUsageDashboard(
      generatedAt: DateTime(2026, 6, 23, 12),
      days: [
        DailyUsageSummary(
          dayStart: _today,
          coverageStatus: CoverageStatus.partial,
          lastUpdatedAt: DateTime(2026, 6, 23, 12),
          totalUsage: const Duration(minutes: 42),
          analysis: null,
          appAggregates: aggregates,
        ),
      ],
      notificationAvailability: notifications.isEmpty
          ? const NotificationsUnavailableForDashboard(
              'Notificações indisponíveis',
            )
          : const NotificationsUnavailableForDashboard.available(),
      notificationCounts: notifications,
    );

AppDailyAggregate _aggregate({
  required String packageName,
  required String appName,
  required int minutes,
  required int episodes,
}) => AppDailyAggregate(
  dayStart: DateTime(2026, 6, 23),
  packageName: packageName,
  appName: appName,
  duration: Duration(minutes: minutes),
  episodeCount: episodes,
  stateCounts: const {},
  coverageStatus: CoverageStatus.partial,
  generatedAt: DateTime(2026, 6, 23, 12),
  versions: const AnalysisArtifactVersions(
    calibrationVersion: 'test-calibration',
    catalogVersion: 'test-catalog',
    owxIri: 'urn:test:owl',
    owxVersion: 'test-owl',
    owxCommit: 'abc123',
    owxHash: 'def456',
  ),
);

CatalogApp _catalogApp({
  required String packageName,
  required String displayName,
  required List<CatalogAssociation> associations,
}) => CatalogApp(
  packageName: packageName,
  displayName: displayName,
  sampleGroup: CatalogSampleGroup.retentionSocial,
  technicalMechanisms: associations,
  osComponents: const [],
);

CatalogAssociation _approvedAssociation(String label) => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: 'urn:test:$label',
  label: label,
  contextualRole: CatalogContextualRole.retention,
  confidence: CatalogConfidence.high,
  evidence: [_evidence('ev-approved-$label')],
);

CatalogAssociation _candidateAssociation(String label) => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: 'urn:test:$label',
  label: label,
  contextualRole: CatalogContextualRole.undetermined,
  confidence: CatalogConfidence.medium,
  evidence: [_evidence('ev-candidate-$label')],
);

CatalogEvidence _evidence(String id) => CatalogEvidence(
  id: id,
  type: CatalogEvidenceType.appStoreListing,
  reference: 'Teste local',
  date: DateTime(2026, 6, 23),
  observedVersion: '1.0',
  supportedStatement: 'Evidência sintética de teste.',
  scope: 'teste',
);
