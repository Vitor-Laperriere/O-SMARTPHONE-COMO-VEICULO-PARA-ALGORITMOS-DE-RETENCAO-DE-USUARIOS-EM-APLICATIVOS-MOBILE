import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/data/app_identity_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/catalog/domain/app_identity.dart';
import 'package:foco_tela/features/dashboard/data/in_memory_derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  testWidgets(
    'alterna entre categoria e aplicativo e abre a fatia insuficiente',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        FocoTelaApp(
          now: () => DateTime(2026, 6, 21, 14, 30),
          usageRepository: _UsageRepository(),
          usageAccessRepository: _GrantedUsageAccessRepository(),
          catalogRepository: InMemoryAppCatalogRepository(_catalog()),
          appIdentityRepository: InMemoryAppIdentityRepository(_identities()),
          derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resumo do dia'), findsOneWidget);
      expect(find.text('Indícios de retenção hoje'), findsOneWidget);
      expect(find.text('Altos'), findsOneWidget);
      expect(find.text('Como o smartphone foi usado'), findsOneWidget);
      expect(find.text('Apps do dia'), findsNothing);
      expect(
        find.byKey(const ValueKey('today-grouping-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('today-slice-chip-category-insufficient')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('today-slice-chip-category-suggested-mixed')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('App').first,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('App').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('today-slice-chip-app-com.instagram.android'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('today-slice-chip-app-com.lemon.lvoverseas')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Tipo').first,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Tipo').first);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('today-slice-chip-category-insufficient')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(
        find.byKey(const ValueKey('today-slice-chip-category-insufficient')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tipo não avaliado'), findsWidgets);
      expect(find.text('Aplicativos neste grupo'), findsOneWidget);
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Sugestões automáticas'), findsNothing);
      expect(find.text('Contexto OWL insuficiente'), findsNothing);
    },
  );

  testWidgets(
    'mostra sinais observados como detalhe científico sem repetir métricas macro',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        FocoTelaApp(
          now: () => DateTime(2026, 6, 21, 14, 30),
          usageRepository: _UsageRepository(),
          usageAccessRepository: _GrantedUsageAccessRepository(),
          catalogRepository: InMemoryAppCatalogRepository(_catalog()),
          appIdentityRepository: InMemoryAppIdentityRepository(_identities()),
          derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('today-signals-summary')),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Sinais observados hoje'), findsOneWidget);
      expect(find.text('Episódios com sinais'), findsOneWidget);
      expect(find.text('Maior intensidade'), findsOneWidget);
      expect(find.text('Sinais ativos distintos'), findsOneWidget);
      expect(find.text('Qualidade da leitura'), findsOneWidget);
      expect(find.text('Tempo em tipos avaliados'), findsOneWidget);
      expect(find.text('Tempo de tela observado'), findsNothing);
      expect(find.text('Desbloqueios observados'), findsNothing);
      expect(find.text('Notificações observadas'), findsNothing);
      expect(find.text('score do dia'), findsNothing);
      expect(find.text('Estado do dia'), findsNothing);
      expect(find.text('Classificação global do dia'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('understand-score-signals')));
      await tester.pumpAndSettle();

      expect(find.text('Como os sinais são calculados'), findsOneWidget);
      expect(find.textContaining('não é diagnóstico'), findsOneWidget);
      expect(
        find.textContaining('valor numérico fica na rastreabilidade'),
        findsOneWidget,
      );
      expect(
        find.textContaining('tipo aprovado pelo TCC/OWL e cautelas'),
        findsOneWidget,
      );
    },
  );
}

class _UsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    if (normalized != DateTime(2026, 6, 21)) {
      return DailyUsageAnalysis(
        dayStart: normalized,
        episodes: const [],
        unlockCount: 0,
      );
    }

    final episodes = [
      _episode(
        packageName: 'com.instagram.android',
        appName: 'Instagram',
        startedAt: DateTime(2026, 6, 21, 8),
      ),
      _episode(
        packageName: 'com.lemon.lvoverseas',
        appName: 'CapCut',
        startedAt: DateTime(2026, 6, 21, 9),
      ),
      _episode(
        packageName: 'com.example.reader',
        appName: 'Reader',
        startedAt: DateTime(2026, 6, 21, 10),
      ),
    ];

    return DailyUsageAnalysis(
      dayStart: normalized,
      episodes: episodes,
      unlockCount: 40,
    );
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

SmartphoneUsageEpisode _episode({
  required String packageName,
  required String appName,
  required DateTime startedAt,
}) {
  return SmartphoneUsageEpisode(
    packageName: packageName,
    appName: appName,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(hours: 1)),
    duration: const Duration(hours: 1),
  );
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
      packageName: 'com.instagram.android',
      displayName: 'Instagram',
      sampleGroup: CatalogSampleGroup.retentionSocial,
      technicalMechanisms: [_approvedAssociation('FeedAlgorithm')],
      osComponents: const [],
    ),
    CatalogApp(
      packageName: 'com.lemon.lvoverseas',
      displayName: 'CapCut',
      sampleGroup: CatalogSampleGroup.mixed,
      technicalMechanisms: [_candidateAssociation('SocialValidation')],
      osComponents: const [],
    ),
  ],
  evidence: [_evidence('approved-evidence'), _evidence('candidate-evidence')],
);

List<AppIdentity> _identities() => [
  AppIdentity(
    packageName: 'com.instagram.android',
    friendlyName: 'Instagram',
    iconPngBytes: _tinyPng,
  ),
  const AppIdentity(
    packageName: 'com.lemon.lvoverseas',
    friendlyName: 'CapCut',
  ),
  const AppIdentity(packageName: 'com.example.reader', friendlyName: 'Reader'),
];

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

final Uint8List _tinyPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x04,
  0x00,
  0x00,
  0x00,
  0xb5,
  0x1c,
  0x0c,
  0x02,
  0x00,
  0x00,
  0x00,
  0x0b,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0xf8,
  0xcf,
  0xc0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xdd,
  0x8d,
  0x18,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);
