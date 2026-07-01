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

  testWidgets('usuário concede acesso e continua sem reiniciar o app', (
    tester,
  ) async {
    final accessRepository = _ControllableUsageAccessRepository();

    await tester.pumpWidget(
      FocoTelaApp(
        usageRepository: _ObservedUsageRepository(),
        usageAccessRepository: accessRepository,
      ),
    );
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      if (find
          .text('Precisamos de acesso ao uso do dispositivo')
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(
      find.text('Precisamos de acesso ao uso do dispositivo'),
      findsOneWidget,
    );
    expect(find.text('Últimos 7 dias'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('usage-access-open-settings')));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      if (find.textContaining('Configurações abertas').evaluate().isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.textContaining('Configurações abertas'), findsOneWidget);

    accessRepository.grant();
    final recheck = find.byKey(const ValueKey('usage-access-recheck'));
    await tester.ensureVisible(recheck);
    await tester.tap(recheck);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-analises')));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      if (find.text('Últimos 7 dias').evaluate().isNotEmpty) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Últimos 7 dias'), findsOneWidget);
    expect(find.text('42 min'), findsWidgets);
  });
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
                packageName: 'com.example.app',
                appName: 'App',
                startedAt: DateTime(2026, 6, 21, 8, 0),
                endedAt: DateTime(2026, 6, 21, 8, 42),
                duration: Duration(minutes: 42),
              ),
            ]
          : const [],
      unlockCount: 0,
    );
  }
}
