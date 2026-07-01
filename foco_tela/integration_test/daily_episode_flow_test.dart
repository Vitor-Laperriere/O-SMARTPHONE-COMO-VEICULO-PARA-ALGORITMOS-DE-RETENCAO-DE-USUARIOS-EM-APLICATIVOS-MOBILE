import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('usuário abre o detalhe de um episódio observado', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        now: () => DateTime(2026, 6, 21, 14, 30),
        usageRepository: _DailyEpisodeRepository(),
        usageAccessRepository: _GrantedUsageAccessRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-analises')));
    await tester.pumpAndSettle();

    expect(find.text('Últimos 7 dias'), findsOneWidget);
    expect(find.text('Hoje · 21/06'), findsWidgets);
    expect(find.text('10 min'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('day-summary-2026-06-21')));
    await tester.pumpAndSettle();

    expect(find.text('Tempo ativo total'), findsOneWidget);
    expect(find.text('Episódios observados'), findsWidgets);
    expect(find.text('App Social'), findsOneWidget);
    expect(find.text('30 min'), findsWidgets);
    expect(find.text('Analisado até 21/06 14:30 · provisório'), findsOneWidget);

    final episodeTile = find.byKey(const ValueKey('episode-0'));
    await tester.ensureVisible(episodeTile);
    await tester.tap(episodeTile);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Pacote'), findsOneWidget);
    expect(find.text('com.example.social'), findsOneWidget);
    expect(find.text('Duração ativa'), findsOneWidget);
    expect(find.text('Análise do episódio'), findsOneWidget);
    expect(find.text('score_sinais'), findsOneWidget);
    expect(find.text('Contexto indisponível'), findsWidgets);
    expect(find.textContaining('score_total'), findsNothing);
    expect(find.textContaining('detectado'), findsNothing);
  });
}

class _DailyEpisodeRepository implements UsageRepository {
  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    return switch (dayStart) {
      DateTime(year: 2026, month: 6, day: 21) => DailyUsageAnalysis(
        dayStart: dayStart,
        episodes: [
          SmartphoneUsageEpisode(
            packageName: 'com.example.social',
            appName: 'App Social',
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
