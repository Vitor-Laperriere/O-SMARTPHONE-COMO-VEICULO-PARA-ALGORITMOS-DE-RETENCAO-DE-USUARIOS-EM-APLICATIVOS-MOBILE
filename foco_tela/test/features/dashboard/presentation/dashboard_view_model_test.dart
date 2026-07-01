import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/data/in_memory_derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';

void main() {
  test(
    'atualizações concorrentes compartilham uma análise retrospectiva',
    () async {
      final usageRepository = _GatedUsageRepository();
      final viewModel = DashboardViewModel(
        usageRepository: usageRepository,
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedRepository: InMemoryDerivedAnalysisRepository(),
        now: () => DateTime(2026, 6, 21, 14, 30),
      );
      addTearDown(viewModel.dispose);

      await usageRepository.firstReadStarted.future;
      final firstRefresh = viewModel.refresh();
      final secondRefresh = viewModel.refresh();
      usageRepository.releaseFirstRead.complete();
      await Future.wait([firstRefresh, secondRefresh]);

      expect(usageRepository.readCount, 7);
      expect(viewModel.dashboard?.days, hasLength(7));
      expect(viewModel.errorMessage, isNull);
    },
  );
}

class _GatedUsageRepository implements UsageRepository {
  final firstReadStarted = Completer<void>();
  final releaseFirstRead = Completer<void>();
  int readCount = 0;

  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    readCount += 1;
    if (!firstReadStarted.isCompleted) {
      firstReadStarted.complete();
      await releaseFirstRead.future;
    }
    return DailyUsageAnalysis(
      dayStart: DateTime(day.year, day.month, day.day),
      episodes: const [],
      unlockCount: 0,
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
