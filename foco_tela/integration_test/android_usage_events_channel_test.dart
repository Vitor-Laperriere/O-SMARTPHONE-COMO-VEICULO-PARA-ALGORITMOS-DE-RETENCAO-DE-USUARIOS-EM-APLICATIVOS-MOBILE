import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:foco_tela/features/dashboard/data/android_usage_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'canal Android consulta o dia real e devolve uma análise válida',
    (_) async {
      expect(Platform.isAndroid, isTrue);

      final now = DateTime.now();
      final analysis = await AndroidUsageRepository().getAnalysisForDay(now);

      expect(analysis.dayStart, DateTime(now.year, now.month, now.day));
      expect(analysis.unlockCount, greaterThanOrEqualTo(0));
      expect(
        analysis.episodes.every(
          (episode) =>
              episode.packageName.isNotEmpty && !episode.duration.isNegative,
        ),
        isTrue,
      );
    },
  );
}
