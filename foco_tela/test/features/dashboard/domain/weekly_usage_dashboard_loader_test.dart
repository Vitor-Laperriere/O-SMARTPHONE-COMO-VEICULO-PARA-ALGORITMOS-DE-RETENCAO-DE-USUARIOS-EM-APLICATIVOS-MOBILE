import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/domain/daily_usage_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';
import 'package:foco_tela/features/dashboard/domain/usage_repository.dart';
import 'package:foco_tela/features/dashboard/domain/daily_usage_summary.dart';

import 'package:foco_tela/features/dashboard/domain/weekly_usage_dashboard_loader.dart';

void main() {
  test(
    'processa sete dias separadamente e reparte episódio transposto',
    () async {
      final repository = _ScriptedUsageRepository(
        analysesByDay: {
          DateTime(2026, 6, 21): _analysis(DateTime(2026, 6, 21), [
            _episode(
              packageName: 'com.example.video',
              appName: 'Video',
              startedAt: DateTime(2026, 6, 21, 10, 0),
              endedAt: DateTime(2026, 6, 21, 10, 30),
            ),
          ]),
          DateTime(2026, 6, 20): _analysis(DateTime(2026, 6, 20), [
            _episode(
              packageName: 'com.example.social',
              appName: 'Social',
              startedAt: DateTime(2026, 6, 20, 23, 50),
              endedAt: DateTime(2026, 6, 21, 0, 20),
            ),
          ]),
          DateTime(2026, 6, 19): null,
          DateTime(2026, 6, 18): _analysis(DateTime(2026, 6, 18), []),
          DateTime(2026, 6, 17): _analysis(DateTime(2026, 6, 17), []),
          DateTime(2026, 6, 16): _analysis(DateTime(2026, 6, 16), []),
          DateTime(2026, 6, 15): _analysis(DateTime(2026, 6, 15), []),
        },
      );

      final loader = SevenDayUsageDashboardLoader(
        usageRepository: repository,
        now: () => DateTime(2026, 6, 21, 14, 30),
      );

      final dashboard = await loader.load();

      expect(repository.requestedDays, [
        DateTime(2026, 6, 15),
        DateTime(2026, 6, 16),
        DateTime(2026, 6, 17),
        DateTime(2026, 6, 18),
        DateTime(2026, 6, 19),
        DateTime(2026, 6, 20),
        DateTime(2026, 6, 21),
      ]);

      expect(dashboard.days.map((day) => day.dayStart), [
        DateTime(2026, 6, 21),
        DateTime(2026, 6, 20),
        DateTime(2026, 6, 19),
        DateTime(2026, 6, 18),
        DateTime(2026, 6, 17),
        DateTime(2026, 6, 16),
        DateTime(2026, 6, 15),
      ]);

      final today = dashboard.days.first;
      expect(today.coverageStatus, CoverageStatus.partial);
      expect(today.isProvisional, isTrue);
      expect(today.analyzedThrough, DateTime(2026, 6, 21, 14, 30));
      expect(today.totalUsage, const Duration(minutes: 50));
      expect(today.episodeCount, 1);

      final yesterday = dashboard.days.firstWhere(
        (day) => day.dayStart == DateTime(2026, 6, 20),
      );
      expect(yesterday.coverageStatus, CoverageStatus.sufficient);
      expect(yesterday.totalUsage, const Duration(minutes: 10));
      expect(yesterday.episodeCount, 1);

      final unavailable = dashboard.days.firstWhere(
        (day) => day.dayStart == DateTime(2026, 6, 19),
      );
      expect(unavailable.coverageStatus, CoverageStatus.unavailable);
      expect(unavailable.totalUsage, isNull);
      expect(unavailable.episodeCount, isNull);
      expect(unavailable.analysis, isNull);
    },
  );
}

class _ScriptedUsageRepository implements UsageRepository {
  _ScriptedUsageRepository({required this.analysesByDay});

  final Map<DateTime, DailyUsageAnalysis?> analysesByDay;
  final List<DateTime> requestedDays = [];

  @override
  Future<DailyUsageAnalysis> getAnalysisForDay(DateTime day) async {
    final dayStart = DateTime(day.year, day.month, day.day);
    requestedDays.add(dayStart);
    final analysis = analysesByDay[dayStart];
    if (analysis == null) {
      throw StateError('Sem cobertura para $dayStart');
    }
    return analysis;
  }
}

DailyUsageAnalysis _analysis(
  DateTime dayStart,
  List<SmartphoneUsageEpisode> episodes,
) {
  return DailyUsageAnalysis(
    dayStart: dayStart,
    episodes: episodes,
    unlockCount: 0,
  );
}

SmartphoneUsageEpisode _episode({
  required String packageName,
  required String appName,
  required DateTime startedAt,
  required DateTime endedAt,
}) {
  return SmartphoneUsageEpisode(
    packageName: packageName,
    appName: appName,
    startedAt: startedAt,
    endedAt: endedAt,
    duration: endedAt.difference(startedAt),
  );
}
