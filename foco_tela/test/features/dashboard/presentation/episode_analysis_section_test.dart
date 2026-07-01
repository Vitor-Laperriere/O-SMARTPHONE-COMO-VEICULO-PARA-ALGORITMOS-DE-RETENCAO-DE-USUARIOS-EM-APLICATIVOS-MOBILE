import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:foco_tela/features/assistive_action/domain/assistive_settings.dart';
import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_summary.dart';
import 'package:foco_tela/features/dashboard/domain/episode_classifier.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/dashboard/presentation/dashboard_page.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  testWidgets(
    'explica classificação convergente sem misturar comportamento e contexto',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        FocoTelaApp(
          now: () => DateTime(2026, 6, 21, 14, 30),
          usageRepository: _ClassifiableUsageRepository(),
          usageAccessRepository: _GrantedUsageAccessRepository(),
          catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-analises')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('assistive-action-open-settings')),
        findsNothing,
      );
      final dayCard = find.byKey(const ValueKey('day-summary-2026-06-20'));
      await tester.ensureVisible(dayCard);
      await tester.tap(dayCard);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assistive-action-open-settings')),
        findsNothing,
      );
      final episodeTile = find.byKey(const ValueKey('episode-0'));
      await tester.ensureVisible(episodeTile);
      await tester.tap(episodeTile);
      await tester.pumpAndSettle();

      expect(find.text('Análise do episódio'), findsOneWidget);
      expect(
        find.text('Sinais convergentes de retenção intensificada'),
        findsOneWidget,
      );
      expect(find.text('score_sinais'), findsOneWidget);
      expect(find.text('0.8 (alta)'), findsOneWidget);
      expect(find.text('Força contextual de retenção'), findsOneWidget);
      expect(find.text('0.5 (média)'), findsWidgets);
      expect(find.text('LongSessionDuration'), findsOneWidget);
      expect(
        find.textContaining('sinal do episódio · ativo · peso 0.5'),
        findsOneWidget,
      );
      expect(find.text('HighScreenTime'), findsOneWidget);
      expect(
        find.textContaining('sinal diário compartilhado · ativo · peso 0.3'),
        findsOneWidget,
      );
      expect(find.text('PatternExplanation'), findsOneWidget);
      expect(
        find.textContaining('não demonstra que o aplicativo causou'),
        findsOneWidget,
      );
      expect(find.text('SelfRegulationAlert'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('assistive-action-open-settings')),
        findsOneWidget,
      );
      expect(find.text('Cobertura suficiente'), findsWidgets);
      expect(find.textContaining('2026-06-21-v1'), findsOneWidget);
      expect(find.textContaining('catalog-v1'), findsOneWidget);
      expect(find.textContaining('owl-v1'), findsOneWidget);
      expect(find.textContaining('score_total'), findsNothing);
      expect(find.textContaining('diagnóstico'), findsNothing);
      expect(find.textContaining('vício'), findsNothing);
      expect(find.textContaining('detectado'), findsNothing);
    },
  );

  testWidgets(
    'cancelar ação convergente mantém a análise e não abre configurações',
    (tester) async {
      final settingsRepository = _RecordingAssistiveSettingsRepository();
      await _openConvergentEpisode(
        tester,
        settingsRepository: settingsRepository,
      );

      final action = find.byKey(
        const ValueKey('assistive-action-open-settings'),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(
        find.text('Revisar configurações deste aplicativo?'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Nenhum limite, bloqueio, notificação ou permissão',
        ),
        findsOneWidget,
      );
      expect(settingsRepository.openedPackages, isEmpty);

      await tester.tap(find.byKey(const ValueKey('assistive-action-cancel')));
      await tester.pumpAndSettle();

      expect(settingsRepository.openedPackages, isEmpty);
      expect(find.text('PatternExplanation'), findsOneWidget);
      expect(
        find.text('Sinais convergentes de retenção intensificada'),
        findsOneWidget,
      );
    },
  );

  testWidgets('confirmar ação abre o packageName e mantém a análise visível', (
    tester,
  ) async {
    final settingsRepository = _RecordingAssistiveSettingsRepository();
    await _openConvergentEpisode(
      tester,
      settingsRepository: settingsRepository,
    );

    final action = find.byKey(const ValueKey('assistive-action-open-settings'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistive-action-confirm')));
    await tester.pumpAndSettle();

    expect(settingsRepository.openedPackages, ['com.example.social']);
    expect(find.text('PatternExplanation'), findsOneWidget);
    expect(
      find.textContaining('A análise permanece inalterada.'),
      findsOneWidget,
    );
  });

  testWidgets('dia encerrado parcial explica por que não foi classificado', (
    tester,
  ) async {
    final episode = SmartphoneUsageEpisode(
      packageName: 'com.example.social',
      appName: 'App Social',
      startedAt: DateTime(2026, 6, 20, 10),
      endedAt: DateTime(2026, 6, 20, 10, 20),
      duration: const Duration(minutes: 20),
    );
    final day = DailyUsageSummary(
      dayStart: DateTime(2026, 6, 20),
      coverageStatus: CoverageStatus.partial,
      lastUpdatedAt: DateTime(2026, 6, 21, 14, 30),
      totalUsage: const Duration(hours: 4),
      analysis: DailyUsageAnalysis(
        dayStart: DateTime(2026, 6, 20),
        episodes: [episode],
        unlockCount: 40,
      ),
    );
    final catalog = _catalog();
    final classifiedDay = _withEpisodeAnalyses(day, catalog);
    await tester.pumpWidget(
      Provider<AppCatalogRepository>.value(
        value: InMemoryAppCatalogRepository(catalog),
        child: MaterialApp(
          home: EpisodeDetailPage(episode: episode, day: classifiedDay),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Classificação não calculada'), findsOneWidget);
    expect(find.textContaining('sinais diários incompletos'), findsOneWidget);
    expect(find.text('score_sinais'), findsNothing);
    expect(find.text('PatternExplanation'), findsNothing);
  });

  testWidgets('estado de revisão explica sem oferecer ação assistiva', (
    tester,
  ) async {
    final episode = SmartphoneUsageEpisode(
      packageName: 'com.example.social',
      appName: 'App Social',
      startedAt: DateTime(2026, 6, 20, 10),
      endedAt: DateTime(2026, 6, 20, 14),
      duration: const Duration(hours: 4),
    );
    final day = DailyUsageSummary(
      dayStart: DateTime(2026, 6, 20),
      coverageStatus: CoverageStatus.sufficient,
      lastUpdatedAt: DateTime(2026, 6, 21, 14, 30),
      totalUsage: const Duration(hours: 4),
      analysis: DailyUsageAnalysis(
        dayStart: DateTime(2026, 6, 20),
        episodes: [episode],
        unlockCount: 10,
      ),
    );
    final catalog = _catalog(confidence: CatalogConfidence.low);
    final classifiedDay = _withEpisodeAnalyses(day, catalog);
    await tester.pumpWidget(
      Provider<AppCatalogRepository>.value(
        value: InMemoryAppCatalogRepository(catalog),
        child: MaterialApp(
          home: EpisodeDetailPage(episode: episode, day: classifiedDay),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sinais para revisão'), findsOneWidget);
    expect(find.text('PatternExplanation'), findsOneWidget);
    expect(find.text('SelfRegulationAlert'), findsNothing);
    expect(
      find.byKey(const ValueKey('assistive-action-open-settings')),
      findsNothing,
    );
  });
}

DailyUsageSummary _withEpisodeAnalyses(
  DailyUsageSummary day,
  CatalogSnapshot catalog,
) => DailyUsageSummary(
  dayStart: day.dayStart,
  coverageStatus: day.coverageStatus,
  lastUpdatedAt: day.lastUpdatedAt,
  analyzedThrough: day.analyzedThrough,
  totalUsage: day.totalUsage,
  analysis: day.analysis,
  episodeAnalyses: day.episodes
      .map(
        (episode) => EpisodeClassifier().analyze(
          episode: episode,
          day: day,
          catalog: catalog,
        ),
      )
      .toList(growable: false),
  issueMessage: day.issueMessage,
);

Future<void> _openConvergentEpisode(
  WidgetTester tester, {
  required AssistiveSettingsRepository settingsRepository,
}) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
  await tester.ensureVisible(dayCard);
  await tester.tap(dayCard);
  await tester.pumpAndSettle();
  final episodeTile = find.byKey(const ValueKey('episode-0'));
  await tester.ensureVisible(episodeTile);
  await tester.tap(episodeTile);
  await tester.pumpAndSettle();
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

CatalogSnapshot _catalog({
  CatalogConfidence confidence = CatalogConfidence.medium,
}) {
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
            confidence: confidence,
            evidence: [evidence],
          ),
        ],
        osComponents: const [],
      ),
    ],
    evidence: [evidence],
  );
}
