import 'package:flutter/material.dart';
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

  testWidgets(
    'percorre acesso, dashboard, dia, episódio e privacidade com exclusão',
    (tester) async {
      final accessRepository = _ControllableUsageAccessRepository();
      final derivedRepository = _RecordingDerivedRepository();
      await tester.pumpWidget(
        FocoTelaApp(
          now: () => DateTime(2026, 6, 21, 14, 30),
          usageRepository: _ObservedUsageRepository(),
          usageAccessRepository: accessRepository,
          catalogRepository: InMemoryAppCatalogRepository(_catalog()),
          derivedAnalysisRepository: derivedRepository,
          notificationRepository: InMemoryNotificationRepository(
            accessStatus: NotificationAccessStatus.granted,
            counts: [
              DailyNotificationCount(
                dayStart: DateTime(2026, 6, 21),
                packageName: 'com.example.observed',
                count: 2,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Precisamos de acesso ao uso do dispositivo'),
        findsOneWidget,
      );
      accessRepository.grant();
      final recheckAccess = find.byKey(const ValueKey('usage-access-recheck'));
      await tester.ensureVisible(recheckAccess);
      await tester.pumpAndSettle();
      await tester.tap(recheckAccess);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav-analises')));
      await tester.pumpAndSettle();
      expect(find.text('Últimos 7 dias'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('day-summary-2026-06-21')));
      await tester.pumpAndSettle();
      expect(find.text('Tempo ativo total'), findsOneWidget);

      final firstEpisode = find.byKey(const ValueKey('episode-0'));
      await tester.ensureVisible(firstEpisode);
      await tester.pumpAndSettle();
      await tester.tap(firstEpisode);
      await tester.pumpAndSettle();
      expect(find.text('Duração ativa'), findsOneWidget);
      expect(find.text('Análise do episódio'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-settings-privacy')));
      await tester.pumpAndSettle();

      expect(find.text('Configurações e privacidade'), findsWidgets);
      expect(find.text('Concedida'), findsOneWidget);
      expect(find.text('Coleta de notificações'), findsOneWidget);
      expect(find.text('Listener ativo'), findsOneWidget);
      expect(find.textContaining('2 notificações'), findsOneWidget);
      expect(find.textContaining('notificações futuras'), findsOneWidget);
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('notification-content-settings-card')),
        find.byKey(const ValueKey('settings-privacy-list')),
        const Offset(0, -500),
      );
      expect(find.text('Conteúdo textual de notificações'), findsOneWidget);
      expect(find.text('Desativado por padrão'), findsOneWidget);
      expect(find.textContaining('não alimenta métricas'), findsOneWidget);
      await tester.dragUntilVisible(
        find.byKey(const ValueKey('settings-open-heuristic')),
        find.byKey(const ValueKey('settings-privacy-list')),
        const Offset(0, -500),
      );
      expect(find.text('Heurística e score-sinais'), findsOneWidget);
      await tester.dragUntilVisible(
        find.text('catalog-integration-v1'),
        find.byKey(const ValueKey('settings-privacy-list')),
        const Offset(0, -500),
      );
      expect(find.text('catalog-integration-v1'), findsOneWidget);
      await tester.dragUntilVisible(
        find.textContaining('sincronização'),
        find.byKey(const ValueKey('settings-privacy-list')),
        const Offset(0, -800),
      );
      expect(find.textContaining('sincronização'), findsOneWidget);

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('privacy-delete-history')),
        find.byKey(const ValueKey('settings-privacy-list')),
        const Offset(0, -800),
      );
      await tester.tap(find.byKey(const ValueKey('privacy-delete-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('privacy-delete-confirm')));
      await tester.pumpAndSettle();
      expect(derivedRepository.clearCalls, 1);
      expect(find.textContaining('foram preservados'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Histórico derivado local vazio'), findsOneWidget);
      expect(find.textContaining('detectado'), findsNothing);
      expect(find.textContaining('diagnóstico'), findsNothing);
      expect(find.textContaining('causou'), findsNothing);
    },
  );
}

class _ControllableUsageAccessRepository implements UsageAccessRepository {
  var _status = UsageAccessStatus.denied;

  void grant() => _status = UsageAccessStatus.granted;

  @override
  Future<UsageAccessSnapshot> checkAccess() async => UsageAccessSnapshot(
    contractVersion: usageAccessContractVersion,
    status: _status,
  );

  @override
  Future<void> openSettings() async {}
}

class _ObservedUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    return DailyUsageAnalysis(
      dayStart: dayStart,
      episodes: dayStart == DateTime(2026, 6, 21)
          ? [
              SmartphoneUsageEpisode(
                packageName: 'com.example.observed',
                appName: 'Aplicativo observado',
                startedAt: DateTime(2026, 6, 21, 8),
                endedAt: DateTime(2026, 6, 21, 8, 20),
                duration: const Duration(minutes: 20),
              ),
            ]
          : const [],
      unlockCount: 2,
    );
  }
}

class _RecordingDerivedRepository extends InMemoryDerivedAnalysisRepository {
  int clearCalls = 0;

  @override
  Future<void> clearAllDerived() async {
    clearCalls += 1;
    await super.clearAllDerived();
  }
}

CatalogSnapshot _catalog() => CatalogSnapshot(
  header: const CatalogHeader(
    version: 'catalog-integration-v1',
    owxIri: 'urn:test:owl',
    owxVersion: 'owl-integration-v1',
    owxCommit: 'abc123',
    owxHash: 'def456',
  ),
  apps: const [],
  evidence: const [],
);
