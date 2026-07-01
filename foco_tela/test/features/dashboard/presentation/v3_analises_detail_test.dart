import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_summary.dart';
import 'package:foco_tela/features/dashboard/domain/episode_classifier.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/presentation/dashboard_page.dart';

void main() {
  testWidgets('detalhe diario prioriza numeros analiticos TCC OWL', (
    tester,
  ) async {
    final fixture = _fixture();

    await tester.pumpWidget(
      _TestApp(child: DayDetailPage(summary: fixture.day)),
    );
    await tester.pumpAndSettle();

    final analyticTitle = find.text('Números analíticos TCC/OWL');
    final observedTitle = find.text('Métricas observadas complementares');
    expect(analyticTitle, findsOneWidget);
    expect(observedTitle, findsOneWidget);
    expect(
      tester.getTopLeft(analyticTitle).dy,
      lessThan(tester.getTopLeft(observedTitle).dy),
    );
    expect(find.text('Episódios com sinais'), findsOneWidget);
    expect(find.text('Maior intensidade'), findsOneWidget);
    expect(find.text('Alta'), findsOneWidget);
    expect(find.text('Sinais ativos distintos'), findsOneWidget);
    expect(find.text('Tempo em contexto OWL aprovado'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Tempo ativo total'), findsOneWidget);
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Desbloqueios'), findsOneWidget);
  });

  testWidgets('filtro do detalhe diario explicita escopo de um dia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _fixture();

    await tester.pumpWidget(
      _TestApp(child: DayDetailPage(summary: fixture.day)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filtrar episódios do dia'), findsOneWidget);
    expect(
      find.textContaining('Este filtro está restrito a 21/06'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('day-episode-app-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('day-episode-intensity-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('day-episode-signal-filter')),
      findsOneWidget,
    );
    expect(find.textContaining('Lista longitudinal'), findsNothing);

    final appFilter = find.byKey(const ValueKey('day-episode-app-filter'));
    await tester.ensureVisible(appFilter);
    await tester.tap(appFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('App Leitura').last);
    await tester.pumpAndSettle();

    expect(
      find.text('1 filtro(s) do dia ativo(s) · 1 episódio(s) neste dia'),
      findsOneWidget,
    );
    expect(find.text('App Leitura'), findsWidgets);
    expect(find.text('App Social'), findsNothing);
  });

  testWidgets('detalhe de episodio destaca duracao indicios e chips', (
    tester,
  ) async {
    final fixture = _fixture();
    final episode = fixture.day.episodes.first;

    await tester.pumpWidget(
      _TestApp(
        child: EpisodeDetailPage(episode: episode, day: fixture.day),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('episode-detail-priority-headline')),
      findsOneWidget,
    );
    expect(find.text('2 h · Indícios de retenção moderados'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('episode-detail-signal-context-chips')),
      findsOneWidget,
    );
    expect(find.textContaining('LongSessionDuration'), findsWidgets);
    expect(find.textContaining('HighScreenTime'), findsWidgets);
    expect(find.textContaining('FrequentUnlocking'), findsWidgets);
    expect(find.text('Infinite Scroll Feed'), findsWidgets);
    expect(find.text('Rastreabilidade científica mínima'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Provider<AppCatalogRepository>.value(
      value: InMemoryAppCatalogRepository(_catalog()),
      child: MaterialApp(home: child),
    );
  }
}

({DailyUsageSummary day}) _fixture() {
  final dayStart = DateTime(2026, 6, 21);
  final socialEpisode = SmartphoneUsageEpisode(
    packageName: 'com.example.social',
    appName: 'App Social',
    startedAt: DateTime(2026, 6, 21, 8),
    endedAt: DateTime(2026, 6, 21, 10),
    duration: const Duration(hours: 2),
  );
  final readerEpisode = SmartphoneUsageEpisode(
    packageName: 'com.example.reader',
    appName: 'App Leitura',
    startedAt: DateTime(2026, 6, 21, 11),
    endedAt: DateTime(2026, 6, 21, 13),
    duration: const Duration(hours: 2),
  );
  final baseDay = DailyUsageSummary(
    dayStart: dayStart,
    coverageStatus: CoverageStatus.sufficient,
    lastUpdatedAt: DateTime(2026, 6, 21, 14, 30),
    totalUsage: const Duration(hours: 4),
    analysis: DailyUsageAnalysis(
      dayStart: dayStart,
      episodes: [socialEpisode, readerEpisode],
      unlockCount: 40,
    ),
    notificationCount: 5,
  );
  final catalog = _catalog();
  final day = DailyUsageSummary(
    dayStart: baseDay.dayStart,
    coverageStatus: baseDay.coverageStatus,
    lastUpdatedAt: baseDay.lastUpdatedAt,
    totalUsage: baseDay.totalUsage,
    analysis: baseDay.analysis,
    notificationCount: baseDay.notificationCount,
    episodeAnalyses: baseDay.episodes
        .map(
          (episode) => EpisodeClassifier().analyze(
            episode: episode,
            day: baseDay,
            catalog: catalog,
          ),
        )
        .toList(growable: false),
  );

  return (day: day);
}

CatalogSnapshot _catalog() {
  final evidence = CatalogEvidence(
    id: 'social-feed',
    type: CatalogEvidenceType.appStoreListing,
    reference: 'https://example.test/social',
    date: DateTime(2026, 6, 21),
    observedVersion: '2026-06-21',
    supportedStatement: 'O aplicativo usa feed de descoberta contínua.',
    scope: 'app_specific',
  );
  return CatalogSnapshot(
    header: const CatalogHeader(
      version: 'catalog-test-v1',
      owxIri: 'urn:test:owl',
      owxVersion: 'owl-test-v1',
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
            confidence: CatalogConfidence.low,
            evidence: [evidence],
          ),
        ],
        osComponents: const [],
      ),
    ],
    evidence: [evidence],
  );
}
