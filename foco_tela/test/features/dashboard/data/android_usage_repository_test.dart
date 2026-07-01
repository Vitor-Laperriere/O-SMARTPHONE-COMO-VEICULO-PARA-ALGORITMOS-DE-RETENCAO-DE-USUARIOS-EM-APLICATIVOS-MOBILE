import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/data/android_usage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.foco_tela/usage_stats_test');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'reconstrói episódios a partir do contrato de eventos do Android',
    () async {
      final dayStart = DateTime(2026, 6, 21);
      final queryEnd = DateTime(2026, 6, 23);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getUsageEventsForInterval');
            final arguments = call.arguments as Map<dynamic, dynamic>;
            expect(
              arguments['startTimeMillis'],
              dayStart.millisecondsSinceEpoch,
            );
            expect(arguments['endTimeMillis'], queryEnd.millisecondsSinceEpoch);

            return <String, Object>{
              'contractVersion': 2,
              'intervalStartMillis': dayStart.millisecondsSinceEpoch,
              'intervalEndMillis': queryEnd.millisecondsSinceEpoch,
              'events': [
                {
                  'timestampMillis': DateTime(
                    2026,
                    6,
                    21,
                    9,
                  ).millisecondsSinceEpoch,
                  'kind': 'unlock',
                },
                {
                  'timestampMillis': DateTime(
                    2026,
                    6,
                    21,
                    10,
                    0,
                  ).millisecondsSinceEpoch,
                  'kind': 'foreground',
                  'packageName': 'app.one',
                  'appName': 'App One',
                },
                {
                  'timestampMillis': DateTime(
                    2026,
                    6,
                    21,
                    10,
                    10,
                  ).millisecondsSinceEpoch,
                  'kind': 'background',
                  'packageName': 'app.one',
                  'appName': 'App One',
                },
                {
                  'timestampMillis': DateTime(
                    2026,
                    6,
                    22,
                    9,
                  ).millisecondsSinceEpoch,
                  'kind': 'unlock',
                },
              ],
            };
          });

      final analysis = await AndroidUsageRepository(
        channel: channel,
        isAndroid: () => true,
      ).getAnalysisForDay(dayStart);

      expect(analysis.episodes, hasLength(1));
      expect(analysis.totalUsage, const Duration(minutes: 10));
      expect(analysis.unlockCount, 1);
      expect(analysis.episodes.single.displayName, 'App One');
    },
  );

  test('rejeita resposta nativa de outro intervalo', () async {
    final dayStart = DateTime(2026, 6, 21);
    final queryEnd = DateTime(2026, 6, 23);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          return <String, Object>{
            'contractVersion': 2,
            'intervalStartMillis': dayStart.millisecondsSinceEpoch,
            'intervalEndMillis': queryEnd
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch,
            'events': <Object>[],
          };
        });

    final repository = AndroidUsageRepository(
      channel: channel,
      isAndroid: () => true,
    );

    expect(
      () => repository.getAnalysisForDay(dayStart),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('intervalo diferente'),
        ),
      ),
    );
  });
}
