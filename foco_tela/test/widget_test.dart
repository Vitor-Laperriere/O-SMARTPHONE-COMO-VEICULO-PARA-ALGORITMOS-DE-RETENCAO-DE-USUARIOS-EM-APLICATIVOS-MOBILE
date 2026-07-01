import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/data/app_identity_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/catalog/domain/app_identity.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  testWidgets('abre em Hoje e alterna entre as quatro áreas persistentes', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _SevenDayUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        appIdentityRepository: InMemoryAppIdentityRepository(const [
          AppIdentity(
            packageName: 'com.example.video',
            friendlyName: 'App Teste',
            nativeCategoryLabel: 'Vídeo',
          ),
          AppIdentity(
            packageName: 'com.unknown.reader',
            friendlyName: 'Leitor Local',
            nativeCategoryLabel: 'Leitura',
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hoje-page')), findsOneWidget);
    expect(find.text('Hoje'), findsWidgets);
    expect(find.text('Resumo do dia'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('nav-analises')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('analises-page')), findsOneWidget);
    expect(find.text('Análises'), findsWidgets);
    expect(find.text('Últimos 7 dias'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-apps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('apps-page')), findsOneWidget);
    expect(find.text('Apps observados'), findsOneWidget);
    expect(find.text('App Teste'), findsOneWidget);
    expect(find.text('Leitor Local'), findsOneWidget);

    await tester.tap(find.text('Não avaliado').first);
    await tester.pumpAndSettle();

    expect(find.text('Leitor Local'), findsOneWidget);
    expect(find.text('App Teste'), findsNothing);

    await tester.tap(find.text('Leitor Local'));
    await tester.pumpAndSettle();

    expect(find.text('Identificador técnico'), findsOneWidget);
    expect(find.text('com.unknown.reader'), findsOneWidget);
    expect(find.textContaining('não é atribuída causalmente'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('configuracoes-page')), findsOneWidget);
    expect(find.text('Configurações e privacidade'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('nav-hoje')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hoje-page')), findsOneWidget);
    expect(find.text('Hoje'), findsWidgets);
  });
}

class _SevenDayUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    return switch (dayStart) {
      DateTime(year: 2026, month: 6, day: 21) => DailyUsageAnalysis(
        dayStart: dayStart,
        episodes: [
          SmartphoneUsageEpisode(
            packageName: 'com.example.video',
            appName: 'App Video',
            startedAt: DateTime(2026, 6, 21, 10, 0),
            endedAt: DateTime(2026, 6, 21, 10, 30),
            duration: const Duration(minutes: 30),
          ),
          SmartphoneUsageEpisode(
            packageName: 'com.unknown.reader',
            appName: 'Reader técnico',
            startedAt: DateTime(2026, 6, 21, 11, 0),
            endedAt: DateTime(2026, 6, 21, 11, 15),
            duration: const Duration(minutes: 15),
          ),
        ],
        unlockCount: 0,
      ),
      _ => DailyUsageAnalysis(
        dayStart: dayStart,
        episodes: const [],
        unlockCount: 0,
      ),
    };
  }
}

class _GrantedUsageAccessRepository implements UsageAccessRepository {
  @override
  Future<UsageAccessSnapshot> checkAccess() async => const UsageAccessSnapshot(
    contractVersion: usageAccessContractVersion,
    status: UsageAccessStatus.granted,
  );

  @override
  Future<void> openSettings() async {}
}

CatalogSnapshot _catalog() => CatalogSnapshot(
  header: const CatalogHeader(
    version: 'catalog-test-v1',
    owxIri: 'urn:test:owl',
    owxVersion: 'owl-test-v1',
    owxCommit: 'abc123',
    owxHash: 'def456',
  ),
  apps: [
    CatalogApp(
      packageName: 'com.example.video',
      displayName: 'App Teste',
      sampleGroup: CatalogSampleGroup.retentionSocial,
      technicalMechanisms: [_approvedAssociation()],
      osComponents: [],
    ),
  ],
  evidence: [_evidence()],
);

CatalogAssociation _approvedAssociation() => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: 'urn:test:SocialNetworkApp',
  label: 'SocialNetworkApp',
  contextualRole: CatalogContextualRole.retention,
  confidence: CatalogConfidence.high,
  evidence: [_evidence()],
);

CatalogEvidence _evidence() => CatalogEvidence(
  id: 'ev-widget',
  type: CatalogEvidenceType.appStoreListing,
  reference: 'Fixture local',
  date: DateTime(2026, 6, 21),
  observedVersion: '1.0',
  supportedStatement: 'Evidência sintética para teste de widget.',
  scope: 'teste',
);
