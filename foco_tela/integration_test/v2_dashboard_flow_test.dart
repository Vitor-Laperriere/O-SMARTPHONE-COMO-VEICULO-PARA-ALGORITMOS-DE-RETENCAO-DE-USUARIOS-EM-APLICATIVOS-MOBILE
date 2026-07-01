import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
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

  testWidgets('fluxo V2 alterna janela e abre explorador de episódios', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 23, 12),
        usageRepository: _WindowUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
        notificationRepository: InMemoryNotificationRepository(
          accessStatus: NotificationAccessStatus.granted,
          counts: [
            DailyNotificationCount(
              dayStart: DateTime(2026, 6, 23),
              packageName: 'com.example.social',
              count: 3,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-analises')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('analysis-window-selector')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('window-trend-summary')), findsOneWidget);

    await tester.tap(find.text('30 dias'));
    await tester.pumpAndSettle();

    expect(find.text('Janela de 30 dias'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-day-calendar')), findsOneWidget);

    final explorerButton = find.byKey(const ValueKey('open-episode-explorer'));
    await tester.ensureVisible(explorerButton);
    await tester.tap(explorerButton);
    await tester.pumpAndSettle();

    expect(find.text('Lista longitudinal'), findsOneWidget);
    expect(find.byKey(const ValueKey('episode-sort-selector')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('episode-group-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('episode-active-filter-count')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('episode-duration-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('episode-intensity-filter')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('episode-signal-filter')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('episode-coverage-filter')),
      findsOneWidget,
    );
  });
}

class _WindowUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    final hasEpisode = normalized.day.isOdd;
    return DailyUsageAnalysis(
      dayStart: normalized,
      episodes: hasEpisode
          ? [
              SmartphoneUsageEpisode(
                packageName: 'com.example.social',
                appName: 'App Social',
                startedAt: normalized.add(const Duration(hours: 9)),
                endedAt: normalized.add(const Duration(hours: 9, minutes: 20)),
                duration: const Duration(minutes: 20),
              ),
            ]
          : const [],
      unlockCount: hasEpisode ? 41 : 5,
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
