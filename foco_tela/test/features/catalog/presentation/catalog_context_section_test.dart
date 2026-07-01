import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/catalog/data/app_catalog_repository.dart';
import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  testWidgets('mostra o contexto do TikTok no detalhe do episódio', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _CatalogPilotUsageRepository(
          packageName: 'com.zhiliaoapp.musically',
          displayName: 'TikTok',
        ),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_snapshot()),
      ),
    );
    await tester.pumpAndSettle();

    await _openAnalises(tester);

    await tester.tap(find.byKey(const ValueKey('day-summary-2026-06-21')));
    await tester.pumpAndSettle();

    final episodeTile = find.byKey(const ValueKey('episode-0'));
    await tester.ensureVisible(episodeTile);
    await tester.tap(episodeTile);
    await tester.pumpAndSettle();

    expect(find.text('Contexto do aplicativo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('catalog-context-status-approved')),
      findsOneWidget,
    );
    expect(find.text('TikTok'), findsWidgets);
    expect(find.text('retenção/social'), findsOneWidget);
    expect(find.text('não determinada'), findsWidgets);
    expect(find.text('Feed Algorithm'), findsWidgets);
    expect(find.text('Infinite Scroll Feed'), findsWidgets);
    expect(find.text('Push Notification'), findsWidgets);
    expect(find.textContaining('confiança média'), findsWidgets);
    expect(find.textContaining('confiança baixa'), findsWidgets);
  });

  testWidgets('mostra contexto indisponível para aplicativo não catalogado', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _CatalogPilotUsageRepository(
          packageName: 'com.example.unknown',
          displayName: 'App Desconhecido',
        ),
        usageAccessRepository: _GrantedUsageAccessRepository(),
        catalogRepository: InMemoryAppCatalogRepository(_snapshot()),
      ),
    );
    await tester.pumpAndSettle();

    await _openAnalises(tester);

    await tester.tap(find.byKey(const ValueKey('day-summary-2026-06-21')));
    await tester.pumpAndSettle();

    final episodeTile = find.byKey(const ValueKey('episode-0'));
    await tester.ensureVisible(episodeTile);
    await tester.tap(episodeTile);
    await tester.pumpAndSettle();

    expect(find.text('Contexto indisponível'), findsWidgets);
    expect(
      find.text(
        'Este aplicativo não está catalogado. A análise mantém episódios e métricas, mas o contexto do app fica indisponível.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('catalog-context-status-insufficient')),
      findsOneWidget,
    );
  });
}

CatalogSnapshot _snapshot() => CatalogSnapshot.fromJson(_catalogJson());

Future<void> _openAnalises(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-analises')));
  await tester.pumpAndSettle();
}

Map<Object?, Object?> _catalogJson() => {
  'header': {
    'version': '2026-06-21-v1',
    'owx_iri': 'urn:webprotege:ontology:7543882f-929e-4586-bf29-1f3930cfc5f2',
    'owx_version': '2026-06-14',
    'owx_commit': 'abc123',
    'owx_hash': 'def456',
  },
  'apps': [
    {
      'package_name': 'com.zhiliaoapp.musically',
      'display_name': 'TikTok',
      'sample_group': 'retention_social',
      'psychological_technique': null,
      'institutional_intention': null,
      'technical_mechanisms': [
        {
          'kind': 'technical_mechanism',
          'iri': 'FeedAlgorithm',
          'label': 'Feed Algorithm',
          'contextual_role': 'retention',
          'confidence': 'medium',
          'evidence_refs': ['tiktok_sample_selection', 'tiktok_play_listing'],
        },
        {
          'kind': 'technical_mechanism',
          'iri': 'InfiniteScrollFeed',
          'label': 'Infinite Scroll Feed',
          'contextual_role': 'retention',
          'confidence': 'medium',
          'evidence_refs': ['tiktok_sample_selection', 'tiktok_play_listing'],
        },
      ],
      'os_components': [
        {
          'kind': 'os_component',
          'iri': 'PushNotification',
          'label': 'Push Notification',
          'contextual_role': 'retention',
          'confidence': 'low',
          'evidence_refs': ['tiktok_sample_selection'],
        },
      ],
    },
  ],
  'evidence': [
    {
      'id': 'tiktok_sample_selection',
      'type': 'sample_selection',
      'reference':
          'docs/prototipo/pesquisa-selecao-catalogo-apps-2026-06-21.md',
      'date': '2026-06-21',
      'observed_version': '2026-06-21',
      'supported_statement':
          'TikTok is part of the approved retention/social sample.',
      'scope': 'sample_selection',
    },
    {
      'id': 'tiktok_play_listing',
      'type': 'app_store_listing',
      'reference':
          'https://play.google.com/store/apps/details?id=com.zhiliaoapp.musically',
      'date': '2026-06-21',
      'observed_version': '2026-06-21',
      'supported_statement':
          'TikTok is presented as a discovery platform for short videos, livestreams, shopping, and more.',
      'scope': 'app_description',
    },
  ],
};

class _CatalogPilotUsageRepository implements UsageRepository {
  _CatalogPilotUsageRepository({
    required this.packageName,
    required this.displayName,
  });

  final String packageName;
  final String displayName;

  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    return switch (dayStart) {
      DateTime(year: 2026, month: 6, day: 21) => DailyUsageAnalysis(
        dayStart: dayStart,
        episodes: [
          SmartphoneUsageEpisode(
            packageName: packageName,
            appName: displayName,
            startedAt: DateTime(2026, 6, 21, 23, 50),
            endedAt: DateTime(2026, 6, 22, 0, 20),
            duration: const Duration(minutes: 30),
          ),
        ],
        unlockCount: 0,
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
