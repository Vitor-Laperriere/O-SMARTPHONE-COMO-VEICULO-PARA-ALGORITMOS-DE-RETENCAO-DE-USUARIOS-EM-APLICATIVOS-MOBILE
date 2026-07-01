import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/data/in_memory_derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/app_daily_aggregate.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/derived_analysis_batch.dart';
import 'package:foco_tela/features/dashboard/domain/derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/notifications/data/in_memory_notification_repository.dart';
import 'package:foco_tela/features/notifications/domain/notification_observation.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  testWidgets('abre privacidade e apresenta estado real e artefatos', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _EmptyUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
        notificationRepository: InMemoryNotificationRepository(
          accessStatus: NotificationAccessStatus.granted,
          counts: [
            DailyNotificationCount(
              dayStart: DateTime(2026, 6, 21),
              packageName: 'com.example.social',
              count: 3,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();

    expect(find.text('Configurações e privacidade'), findsWidgets);
    expect(find.text('Concedida'), findsOneWidget);
    expect(find.text('Coleta de notificações'), findsOneWidget);
    expect(find.text('Listener ativo'), findsOneWidget);
    expect(find.textContaining('com.example.social'), findsOneWidget);
    expect(find.textContaining('3 notificações'), findsOneWidget);
    expect(find.textContaining('notificações futuras'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('catalog-test-v1'),
      find.byKey(const ValueKey('settings-privacy-list')),
      const Offset(0, -500),
    );
    expect(find.text('catalog-test-v1'), findsOneWidget);
    expect(find.text('2026-06-21-v1'), findsAtLeastNWidgets(1));
    expect(find.textContaining('owl-test-v1'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('sincronização'),
      find.byKey(const ValueKey('settings-privacy-list')),
      const Offset(0, -500),
    );
    expect(find.textContaining('sete dias'), findsWidgets);
    expect(find.textContaining('sincronização'), findsOneWidget);
  });

  testWidgets('abre configuração de notificações e reverifica listener', (
    tester,
  ) async {
    final notificationRepository = _RecordingNotificationRepository(
      accessStatus: NotificationAccessStatus.denied,
    );
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _EmptyUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
        notificationRepository: notificationRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();

    expect(find.text('Listener inativo'), findsOneWidget);

    final openSettings = find.byKey(
      const ValueKey('notification-listener-open-settings'),
    );
    await tester.ensureVisible(openSettings);
    await tester.tap(openSettings);
    await tester.pumpAndSettle();

    expect(notificationRepository.openSettingsCalls, 1);
    expect(find.textContaining('Configurações abertas'), findsOneWidget);

    notificationRepository
      ..accessStatus = NotificationAccessStatus.granted
      ..counts = [
        DailyNotificationCount(
          dayStart: DateTime(2026, 6, 21),
          packageName: 'com.example.social',
          count: 4,
        ),
      ];

    await tester.tap(
      find.byKey(const ValueKey('notification-listener-recheck')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Listener ativo'), findsOneWidget);
    expect(find.textContaining('com.example.social'), findsOneWidget);
    expect(find.textContaining('4 notificações'), findsOneWidget);
    expect(find.textContaining('reverificado'), findsOneWidget);
  });

  testWidgets(
    'conteúdo textual aparece desativado por padrão e separado da contagem',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        FocoTelaApp(
          now: () => DateTime(2026, 6, 21, 14, 30),
          usageRepository: _EmptyUsageRepository(),
          usageAccessRepository: _GrantedUsageAccessRepository(),
          catalogRepository: InMemoryAppCatalogRepository(_catalog()),
          derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
          notificationRepository: _RecordingNotificationRepository(
            accessStatus: NotificationAccessStatus.granted,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
      await tester.pumpAndSettle();

      final contentCard = find.byKey(
        const ValueKey('notification-content-settings-card'),
      );
      await tester.ensureVisible(contentCard);
      await tester.pumpAndSettle();

      expect(find.text('Conteúdo textual de notificações'), findsOneWidget);
      expect(find.text('Desativado por padrão'), findsOneWidget);
      expect(find.text('0 apps autorizados'), findsOneWidget);
      expect(find.textContaining('até 7 dias'), findsOneWidget);
      expect(
        find.textContaining('autenticação do dispositivo'),
        findsOneWidget,
      );
      expect(find.textContaining('não alimenta métricas'), findsOneWidget);
      expect(find.textContaining('Contagem de notificações'), findsNothing);
    },
  );

  testWidgets('autoriza conteúdo textual para apps observados em lote', (
    tester,
  ) async {
    final notificationRepository = _RecordingNotificationRepository(
      accessStatus: NotificationAccessStatus.granted,
    );
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _EmptyUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: _ObservedAppsDerivedRepository({
          'com.example.social',
          'com.example.run',
        }),
        notificationRepository: notificationRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();

    final authorizeButton = find.byKey(
      const ValueKey('notification-content-authorize-observed'),
    );
    await tester.dragUntilVisible(
      authorizeButton,
      find.byKey(const ValueKey('settings-privacy-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(authorizeButton);
    await tester.pumpAndSettle();

    expect(notificationRepository.contentSettings.enabled, isTrue);
    expect(notificationRepository.contentSettings.authorizedPackageNames, {
      'com.example.social',
      'com.example.run',
    });
    expect(find.text('2 apps autorizados'), findsOneWidget);
    expect(find.textContaining('2 apps observados'), findsWidgets);
  });

  testWidgets('heurística e score-sinais são páginas informativas sem edição', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _EmptyUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();

    final heuristicButton = find.byKey(
      const ValueKey('settings-open-heuristic'),
    );
    await tester.dragUntilVisible(
      heuristicButton,
      find.byKey(const ValueKey('settings-privacy-list')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await tester.tap(heuristicButton);
    await tester.pumpAndSettle();

    expect(find.text('Configuração heurística'), findsWidgets);
    expect(find.text('2026-06-21-v1'), findsOneWidget);
    expect(find.text('LongSessionDuration'), findsAtLeastNWidgets(1));
    expect(find.text('HighScreenTime'), findsAtLeastNWidgets(1));
    expect(find.text('FrequentUnlocking'), findsAtLeastNWidgets(1));
    expect(find.text('0.5'), findsOneWidget);
    expect(find.textContaining('15 minutes'), findsOneWidget);
    expect(find.textContaining('não permite editar'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Slider), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final scoreButton = find.byKey(
      const ValueKey('settings-open-score-signals'),
    );
    await tester.drag(
      find.byKey(const ValueKey('settings-privacy-list')),
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    await tester.tap(scoreButton);
    await tester.pumpAndSettle();

    expect(find.text('Como os sinais são calculados'), findsWidgets);
    expect(find.textContaining('score_sinais'), findsWidgets);
    expect(find.textContaining('não é diagnóstico'), findsOneWidget);
    expect(find.textContaining('NotificationCount'), findsOneWidget);
    expect(find.textContaining('não altera score_sinais'), findsOneWidget);
  });

  testWidgets('confirma exclusão, limpa derivados e preserva artefatos', (
    tester,
  ) async {
    final derivedRepository = _RecordingDerivedRepository();
    final catalogRepository = InMemoryAppCatalogRepository(_catalog());
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _EmptyUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: catalogRepository,
        derivedAnalysisRepository: derivedRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('privacy-delete-history')),
      find.byKey(const ValueKey('settings-privacy-list')),
      const Offset(0, -700),
    );

    await tester.tap(find.byKey(const ValueKey('privacy-delete-history')));
    await tester.pumpAndSettle();
    expect(find.text('Apagar histórico local?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('privacy-delete-cancel')));
    await tester.pumpAndSettle();
    expect(derivedRepository.clearCalls, 0);

    await tester.tap(find.byKey(const ValueKey('privacy-delete-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('privacy-delete-confirm')));
    await tester.pumpAndSettle();

    expect(derivedRepository.clearCalls, 1);
    expect(
      find.textContaining('Catálogo e configuração foram preservados'),
      findsOneWidget,
    );
    expect(await derivedRepository.loadDay(DateTime(2026, 6, 21)), isNull);
    expect(
      (await catalogRepository.loadSnapshot()).header.version,
      'catalog-test-v1',
    );

    await tester.tap(find.byKey(const ValueKey('nav-hoje')));
    await tester.pumpAndSettle();
    expect(find.text('Histórico derivado local vazio'), findsOneWidget);
    expect(find.text('Últimos 7 dias'), findsNothing);
  });

  testWidgets('reconsulta e mostra permissão revogada ao abrir privacidade', (
    tester,
  ) async {
    final accessRepository = _SequentialUsageAccessRepository();
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _EmptyUsageRepository(),
        usageAccessRepository: accessRepository,
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-configuracoes')));
    await tester.pumpAndSettle();

    expect(find.text('Não concedida'), findsOneWidget);
    expect(accessRepository.checkCount, 2);
  });
}

class _EmptyUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async =>
      DailyUsageAnalysis(
        dayStart: DateTime(day.year, day.month, day.day),
        episodes: const [],
        unlockCount: 0,
      );
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

class _SequentialUsageAccessRepository implements UsageAccessRepository {
  int checkCount = 0;

  @override
  Future<UsageAccessSnapshot> checkAccess() async {
    checkCount += 1;
    return UsageAccessSnapshot(
      contractVersion: usageAccessContractVersion,
      status: checkCount == 1
          ? UsageAccessStatus.granted
          : UsageAccessStatus.denied,
    );
  }

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
  apps: const [],
  evidence: const [],
);

class _RecordingDerivedRepository extends InMemoryDerivedAnalysisRepository {
  int clearCalls = 0;

  @override
  Future<void> clearAllDerived() async {
    clearCalls += 1;
    await super.clearAllDerived();
  }
}

class _ObservedAppsDerivedRepository implements DerivedAnalysisRepository {
  _ObservedAppsDerivedRepository(this.packageNames);

  final Set<String> packageNames;

  @override
  Future<void> initialize({required DateTime now}) async {}

  @override
  Future<void> save(DerivedAnalysisBatch batch) async {}

  @override
  Future<DerivedAnalysisBatch?> loadDay(
    DateTime day, {
    AnalysisArtifactVersions? compatibleWith,
  }) async => null;

  @override
  Future<List<AppDailyAggregate>> loadAppDailyAggregates({
    required DateTime start,
    required DateTime end,
    AnalysisArtifactVersions? compatibleWith,
  }) async => packageNames
      .map(
        (packageName) => AppDailyAggregate(
          dayStart: DateTime(2026, 6, 21),
          packageName: packageName,
          appName: packageName,
          duration: const Duration(minutes: 10),
          episodeCount: 1,
          stateCounts: const {},
          coverageStatus: CoverageStatus.sufficient,
          generatedAt: DateTime(2026, 6, 21, 14),
          versions: const AnalysisArtifactVersions(
            calibrationVersion: 'test-calibration',
            catalogVersion: 'test-catalog',
            owxIri: 'urn:test:owl',
            owxVersion: 'test-owl',
            owxCommit: 'abc123',
            owxHash: 'def456',
          ),
        ),
      )
      .toList(growable: false);

  @override
  Future<void> prune({required DateTime now}) async {}

  @override
  Future<void> clearAllDerived() async {}

  @override
  Future<void> close() async {}
}

class _RecordingNotificationRepository implements NotificationRepository {
  _RecordingNotificationRepository({
    this.accessStatus = NotificationAccessStatus.unsupported,
  });

  NotificationAccessStatus accessStatus;
  List<DailyNotificationCount> counts = const [];
  NotificationContentSettings contentSettings =
      NotificationContentSettings.defaults();
  int openSettingsCalls = 0;

  @override
  Future<NotificationAccessStatus> checkAccess() async => accessStatus;

  @override
  Future<void> openSettings() async {
    openSettingsCalls += 1;
  }

  @override
  Future<List<DailyNotificationCount>> loadDailyCounts({
    required DateTime start,
    required DateTime end,
  }) async {
    if (accessStatus != NotificationAccessStatus.granted) return const [];
    return counts
        .where(
          (count) =>
              !count.dayStart.isBefore(start) && count.dayStart.isBefore(end),
        )
        .toList(growable: false);
  }

  @override
  Future<NotificationLastObservation?> loadLastObservation() async {
    if (accessStatus != NotificationAccessStatus.granted) return null;
    final observed = counts.where((count) => count.count > 0).toList();
    if (observed.isEmpty) return null;
    observed.sort((left, right) => right.dayStart.compareTo(left.dayStart));
    final latest = observed.first;
    return NotificationLastObservation(
      observedAt: latest.dayStart,
      packageName: latest.packageName,
      count: latest.count,
    );
  }

  @override
  Future<NotificationContentSettings> loadContentSettings() async =>
      contentSettings;

  @override
  Future<void> setContentModeEnabled(bool enabled) async {
    contentSettings = enabled
        ? NotificationContentSettings(
            enabled: true,
            authorizedPackageNames: contentSettings.authorizedPackageNames,
          )
        : NotificationContentSettings.defaults();
  }

  @override
  Future<void> authorizeContentPackage(String packageName) async {
    await authorizeContentPackages({packageName});
  }

  @override
  Future<void> authorizeContentPackages(Set<String> packageNames) async {
    contentSettings = NotificationContentSettings(
      enabled: contentSettings.enabled,
      authorizedPackageNames: {
        ...contentSettings.authorizedPackageNames,
        ...packageNames,
      },
    );
  }

  @override
  Future<void> revokeContentPackage(String packageName) async {}

  @override
  Future<bool> authenticateContentViewing() async => false;

  @override
  Future<List<NotificationTextRecord>> loadStoredContent({
    required DateTime start,
    required DateTime end,
    String? packageName,
  }) async => const [];

  @override
  Future<void> clearStoredContent() async {}
}
