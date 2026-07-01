import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/data/app_identity_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/catalog/domain/app_identity.dart';
import 'package:foco_tela/features/dashboard/data/in_memory_derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/notifications/data/in_memory_notification_repository.dart';
import 'package:foco_tela/features/notifications/domain/notification_observation.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fluxo V3 percorre Hoje, Apps, Analises e Configuracoes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 25, 14),
        usageRepository: _V3UsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        appIdentityRepository: InMemoryAppIdentityRepository(_identities()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
        notificationRepository: InMemoryNotificationRepository(
          accessStatus: NotificationAccessStatus.granted,
          counts: [
            DailyNotificationCount(
              dayStart: DateTime(2026, 6, 25),
              packageName: 'com.instagram.android',
              count: 4,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('hoje-page')), findsOneWidget);
    expect(find.text('Resumo do dia'), findsWidgets);
    expect(
      find.byKey(const ValueKey('today-slice-chip-category-insufficient')),
      findsOneWidget,
    );
    expect(find.text('score do dia'), findsNothing);
    expect(find.text('score_total'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('App').first,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('App').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('today-slice-chip-app-com.instagram.android')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('nav-apps')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apps-page')), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('CapCut'), findsOneWidget);

    await tester.tap(find.text('Sugerido').first);
    await tester.pumpAndSettle();
    expect(find.text('CapCut'), findsOneWidget);
    expect(find.text('Instagram'), findsNothing);

    await tester.tap(find.text('CapCut'));
    await tester.pumpAndSettle();
    expect(find.text('Tipo sugerido'), findsWidgets);
    expect(find.text('Identificador técnico'), findsOneWidget);
    expect(find.text('com.lemon.lvoverseas'), findsOneWidget);
    expect(find.textContaining('não é atribuída causalmente'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-analises')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('analises-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('analysis-window-selector')),
      findsOneWidget,
    );
    expect(find.text('Sinais e mecanismos observados'), findsOneWidget);
    expect(find.text('Mudanças no período'), findsOneWidget);
    expect(find.text('Episódios relevantes'), findsOneWidget);
    expect(find.textContaining('conteúdo armazenado'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('configuracoes-page')), findsOneWidget);
    expect(find.text('Coleta de notificações'), findsOneWidget);
    expect(find.text('Listener ativo'), findsOneWidget);
    expect(find.textContaining('notificações futuras'), findsOneWidget);
  });
}

class _V3UsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    return switch (normalized) {
      DateTime(year: 2026, month: 6, day: 25) => DailyUsageAnalysis(
        dayStart: normalized,
        episodes: [
          _episode(
            packageName: 'com.instagram.android',
            appName: 'Instagram',
            startedAt: DateTime(2026, 6, 25, 8),
            duration: const Duration(minutes: 50),
          ),
          _episode(
            packageName: 'com.lemon.lvoverseas',
            appName: 'CapCut',
            startedAt: DateTime(2026, 6, 25, 10),
            duration: const Duration(minutes: 35),
          ),
          _episode(
            packageName: 'com.example.reader',
            appName: 'Reader',
            startedAt: DateTime(2026, 6, 25, 12),
            duration: const Duration(minutes: 15),
          ),
        ],
        unlockCount: 39,
      ),
      _ => DailyUsageAnalysis(
        dayStart: normalized,
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

SmartphoneUsageEpisode _episode({
  required String packageName,
  required String appName,
  required DateTime startedAt,
  required Duration duration,
}) => SmartphoneUsageEpisode(
  packageName: packageName,
  appName: appName,
  startedAt: startedAt,
  endedAt: startedAt.add(duration),
  duration: duration,
);

CatalogSnapshot _catalog() => CatalogSnapshot(
  header: const CatalogHeader(
    version: 'catalog-v3-integration',
    owxIri: 'urn:test:owl',
    owxVersion: 'owl-v3-integration',
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
    nativeCategoryLabel: 'Social',
  ),
  const AppIdentity(
    packageName: 'com.lemon.lvoverseas',
    friendlyName: 'CapCut',
    nativeCategoryLabel: 'Video',
  ),
  const AppIdentity(
    packageName: 'com.example.reader',
    friendlyName: 'Reader',
    nativeCategoryLabel: 'Leitura',
  ),
];

CatalogAssociation _approvedAssociation(String iri) => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: iri,
  label: iri,
  contextualRole: CatalogContextualRole.retention,
  confidence: CatalogConfidence.high,
  evidence: [_evidence('approved-evidence')],
);

CatalogAssociation _candidateAssociation(String iri) => CatalogAssociation(
  kind: CatalogAssociationKind.technicalMechanism,
  iri: iri,
  label: iri,
  contextualRole: CatalogContextualRole.undetermined,
  confidence: CatalogConfidence.medium,
  evidence: [_evidence('candidate-evidence')],
);

CatalogEvidence _evidence(String id) => CatalogEvidence(
  id: id,
  type: CatalogEvidenceType.appStoreListing,
  reference: 'Fixture local V3',
  date: DateTime(2026, 6, 25),
  observedVersion: '1.0',
  supportedStatement: 'Evidência sintética para teste de integração V3.',
  scope: 'teste',
);

final Uint8List _tinyPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
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
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
