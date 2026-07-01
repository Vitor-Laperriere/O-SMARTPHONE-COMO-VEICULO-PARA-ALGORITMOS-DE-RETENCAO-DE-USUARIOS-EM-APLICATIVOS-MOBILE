import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:foco_tela/features/assistive_action/domain/assistive_settings.dart';
import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('usuário abre e audita a classificação de um episódio', (
    tester,
  ) async {
    final settingsRepository = _RecordingAssistiveSettingsRepository();
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _ClassifiableUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        assistiveSettingsRepository: settingsRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-analises')));
    await tester.pumpAndSettle();

    final dayCard = find.byKey(const ValueKey('day-summary-2026-06-20'));
    await tester.scrollUntilVisible(
      dayCard,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(dayCard);
    await tester.pumpAndSettle();

    final episodeTile = find.byKey(const ValueKey('episode-0'));
    await tester.scrollUntilVisible(
      episodeTile,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(episodeTile);
    await tester.pumpAndSettle();

    expect(
      find.text('Sinais convergentes de retenção intensificada'),
      findsOneWidget,
    );
    expect(find.text('score_sinais'), findsOneWidget);
    expect(find.text('Força contextual de retenção'), findsOneWidget);
    expect(find.text('PatternExplanation'), findsOneWidget);
    final action = find.byKey(const ValueKey('assistive-action-open-settings'));
    await tester.scrollUntilVisible(
      action,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(settingsRepository.openedPackages, isEmpty);
    await tester.tap(find.byKey(const ValueKey('assistive-action-confirm')));
    await tester.pumpAndSettle();
    expect(settingsRepository.openedPackages, ['com.example.social']);
    expect(find.text('PatternExplanation'), findsOneWidget);
    expect(
      find.text('Sinais convergentes de retenção intensificada'),
      findsOneWidget,
    );
    expect(find.textContaining('score_total'), findsNothing);
    expect(find.textContaining('detectado'), findsNothing);
  });
}

class _RecordingAssistiveSettingsRepository
    implements AssistiveSettingsRepository {
  final List<String> openedPackages = [];

  @override
  Future<AssistiveSettingsOpenResult> openForPackage(String packageName) async {
    openedPackages.add(packageName);
    return const AssistiveSettingsOpenResult(
      destination: AssistiveSettingsDestination.appUsageSettings,
    );
  }
}

class _ClassifiableUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    return switch (dayStart) {
      DateTime(year: 2026, month: 6, day: 20) => DailyUsageAnalysis(
        dayStart: dayStart,
        episodes: [
          SmartphoneUsageEpisode(
            packageName: 'com.example.social',
            appName: 'App Social',
            startedAt: DateTime(2026, 6, 20, 10),
            endedAt: DateTime(2026, 6, 20, 14),
            duration: const Duration(hours: 4),
          ),
        ],
        unlockCount: 10,
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

CatalogSnapshot _catalog() {
  final evidence = CatalogEvidence(
    id: 'app-specific-evidence',
    type: CatalogEvidenceType.appStoreListing,
    reference: 'https://example.test/app',
    date: DateTime(2026, 6, 21),
    observedVersion: '2026-06-21',
    supportedStatement: 'O aplicativo oferece feed de descoberta contínua.',
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
        displayName: 'App Social',
        sampleGroup: CatalogSampleGroup.retentionSocial,
        technicalMechanisms: [
          CatalogAssociation(
            kind: CatalogAssociationKind.technicalMechanism,
            iri: 'InfiniteScrollFeed',
            label: 'Infinite Scroll Feed',
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
