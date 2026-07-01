import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/usage_access/domain/usage_access.dart';
import 'package:foco_tela/main.dart';

void main() {
  testWidgets('permissão negada não consulta nem exibe métricas', (
    tester,
  ) async {
    final usageRepository = _RecordingUsageRepository();

    await tester.pumpWidget(
      FocoTelaApp(
        usageRepository: usageRepository,
        usageAccessRepository: _MutableUsageAccessRepository(
          UsageAccessStatus.denied,
        ),
      ),
    );
    await tester.pump();

    expect(usageRepository.readCount, 0);
    expect(find.textContaining('nenhuma métrica é exibida'), findsOneWidget);
    expect(find.text('Últimos 7 dias'), findsNothing);
  });

  testWidgets('falha ao abrir configurações possui mensagem própria', (
    tester,
  ) async {
    await tester.pumpWidget(
      FocoTelaApp(
        usageRepository: _RecordingUsageRepository(),
        usageAccessRepository: _FailingSettingsUsageAccessRepository(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('usage-access-open-settings')));
    await tester.pump();

    expect(
      find.text('A tela nativa de acesso ao uso não está disponível.'),
      findsOneWidget,
    );
    expect(find.text('Últimos 7 dias'), findsNothing);
  });

  testWidgets('verifica novamente e continua sem reiniciar após concessão', (
    tester,
  ) async {
    final accessRepository = _MutableUsageAccessRepository(
      UsageAccessStatus.denied,
    );
    final usageRepository = _RecordingUsageRepository();

    await tester.pumpWidget(
      FocoTelaApp(
        usageRepository: usageRepository,
        usageAccessRepository: accessRepository,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('usage-access-open-settings')));
    await tester.pump();
    expect(find.textContaining('Configurações abertas'), findsOneWidget);

    accessRepository.status = UsageAccessStatus.granted;
    final recheck = find.byKey(const ValueKey('usage-access-recheck'));
    await tester.ensureVisible(recheck);
    await tester.tap(recheck);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-analises')));
    await tester.pumpAndSettle();

    expect(usageRepository.readCount, 7);
    expect(find.text('Últimos 7 dias'), findsOneWidget);
    expect(find.text('1 h 05 min'), findsOneWidget);
  });
}

class _RecordingUsageRepository implements UsageRepository {
  int readCount = 0;

  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    readCount += 1;
    final dayStart = DateTime(day.year, day.month, day.day);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return DailyUsageAnalysis(
      dayStart: dayStart,
      episodes: dayStart == todayStart
          ? [
              SmartphoneUsageEpisode(
                packageName: 'com.example.video',
                appName: 'Video',
                startedAt: dayStart.add(const Duration(hours: 9)),
                endedAt: dayStart.add(
                  const Duration(hours: 10, minutes: 5),
                ),
                duration: Duration(hours: 1, minutes: 5),
              ),
            ]
          : const [],
      unlockCount: 0,
    );
  }
}

class _MutableUsageAccessRepository implements UsageAccessRepository {
  _MutableUsageAccessRepository(this.status);

  UsageAccessStatus status;

  @override
  Future<UsageAccessSnapshot> checkAccess() async => UsageAccessSnapshot(
    contractVersion: usageAccessContractVersion,
    status: status,
  );

  @override
  Future<void> openSettings() async {}
}

class _FailingSettingsUsageAccessRepository implements UsageAccessRepository {
  @override
  Future<UsageAccessSnapshot> checkAccess() async => const UsageAccessSnapshot(
    contractVersion: usageAccessContractVersion,
    status: UsageAccessStatus.denied,
  );

  @override
  Future<void> openSettings() async {
    throw const UsageSettingsOpenException(
      'A tela nativa de acesso ao uso não está disponível.',
    );
  }
}
