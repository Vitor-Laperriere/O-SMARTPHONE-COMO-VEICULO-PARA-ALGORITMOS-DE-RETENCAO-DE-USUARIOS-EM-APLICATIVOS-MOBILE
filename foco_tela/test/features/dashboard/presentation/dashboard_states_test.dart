import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/data/in_memory_derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  testWidgets('carregamento é apresentado como estado próprio', (tester) async {
    final repository = _GatedUsageRepository();
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: repository,
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('dashboard-loading-state')),
      findsOneWidget,
    );
    expect(find.text('Carregando análise retrospectiva…'), findsOneWidget);

    repository.release.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('erro técnico não é confundido com ausência de uso', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _EmptyUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: _FailingCatalogRepository(),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await _openAnalises(tester);

    expect(find.text('Erro ao carregar dados'), findsOneWidget);
    expect(find.text('Nenhum episódio foi reconstruído'), findsNothing);
  });

  testWidgets('vazio, parcial, indisponível e provisório são distinguíveis', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _PartiallyAvailableUsageRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_catalog()),
        derivedAnalysisRepository: InMemoryDerivedAnalysisRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await _openAnalises(tester);

    expect(find.byKey(const ValueKey('dashboard-empty-state')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('day-summary-2026-06-21')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Parcial'), findsWidgets);
    expect(find.textContaining('provisório'), findsWidgets);

    final unavailable = find.byKey(const ValueKey('day-summary-2026-06-19'));
    await tester.scrollUntilVisible(
      unavailable,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Indisponível'), findsWidgets);
    expect(find.text('Sem métricas disponíveis'), findsWidgets);
  });
}

Future<void> _openAnalises(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-analises')));
  await tester.pumpAndSettle();
}

class _GatedUsageRepository implements UsageRepository {
  final release = Completer<void>();

  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    await release.future;
    return _analysis(day);
  }
}

class _EmptyUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async =>
      _analysis(day);
}

class _PartiallyAvailableUsageRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    if (normalized == DateTime(2026, 6, 19)) {
      throw StateError('Intervalo indisponível');
    }
    return _analysis(day);
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

class _FailingCatalogRepository implements AppCatalogRepository {
  @override
  Future<CatalogSnapshot> loadSnapshot() =>
      Future.error(StateError('Catálogo inválido'));

  @override
  Future<CatalogApp?> findByPackageName(String packageName) async => null;
}

DailyUsageAnalysis _analysis(DateTime day) => DailyUsageAnalysis(
  dayStart: DateTime(day.year, day.month, day.day),
  episodes: const [],
  unlockCount: 0,
);

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
