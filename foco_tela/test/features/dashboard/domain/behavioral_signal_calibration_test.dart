import 'package:flutter_test/flutter_test.dart';

import 'package:foco_tela/features/dashboard/domain/behavioral_signal_calibration.dart';

void main() {
  test(
    'V1 expõe limiares comportamentais versionados e parâmetros técnicos separados',
    () {
      final calibration = BehavioralSignalCalibration.v1();

      expect(calibration.version, '2026-06-21-v1');
      expect(calibration.deviceProfile, contains('SM-A526B'));
      expect(calibration.behavioralThresholds, hasLength(3));
      expect(calibration.technicalParameters, hasLength(1));
      expect(
        calibration.behavioralThresholds.map((threshold) => threshold.id),
        containsAllInOrder([
          'long_session_duration_minutes',
          'high_screen_time_hours_per_day',
          'frequent_unlocks_per_day',
        ]),
      );
      expect(
        calibration.technicalParameters.single.id,
        'session_merge_gap_seconds',
      );
      expect(
        calibration.behavioralThresholds.any(
          (threshold) => threshold.id == 'session_merge_gap_seconds',
        ),
        isFalse,
      );

      for (final threshold in calibration.allThresholds) {
        expect(threshold.version, calibration.version);
        expect(threshold.justification, isNotEmpty);
      }

      expect(() => calibration.validate(), returnsNormally);
    },
  );

  test(
    'cada limiar comportamental ativa somente no ponto de corte e acima',
    () {
      final calibration = BehavioralSignalCalibration.v1();

      expect(
        calibration.isLongSessionDurationActive(const Duration(minutes: 14)),
        isFalse,
      );
      expect(
        calibration.isLongSessionDurationActive(const Duration(minutes: 15)),
        isTrue,
      );
      expect(
        calibration.isLongSessionDurationActive(const Duration(minutes: 16)),
        isTrue,
      );

      expect(
        calibration.isHighScreenTimeActive(
          const Duration(hours: 3, minutes: 59),
        ),
        isFalse,
      );
      expect(
        calibration.isHighScreenTimeActive(const Duration(hours: 4)),
        isTrue,
      );
      expect(
        calibration.isHighScreenTimeActive(
          const Duration(hours: 4, minutes: 1),
        ),
        isTrue,
      );

      expect(calibration.isFrequentUnlockingActive(39), isFalse);
      expect(calibration.isFrequentUnlockingActive(40), isTrue);
      expect(calibration.isFrequentUnlockingActive(41), isTrue);
    },
  );

  test('pesos dos sinais e teto contextual pertencem à configuração V1', () {
    final calibration = BehavioralSignalCalibration.v1();

    expect(
      calibration.weightFor(BehavioralSignalKind.longSessionDuration),
      0.5,
    );
    expect(calibration.weightFor(BehavioralSignalKind.highScreenTime), 0.3);
    expect(calibration.weightFor(BehavioralSignalKind.frequentUnlocking), 0.2);
    expect(calibration.contextualStrengthCap, 2.0);
  });

  test('as oito combinações dos sinais geram os scores e faixas aprovados', () {
    final calibration = BehavioralSignalCalibration.v1();

    final cases =
        <
          (
            bool longSessionDurationActive,
            bool highScreenTimeActive,
            bool frequentUnlockingActive,
            double expectedScore,
            BehavioralScoreRange expectedRange,
          )
        >[
          (false, false, false, 0.0, BehavioralScoreRange.low),
          (false, false, true, 0.2, BehavioralScoreRange.low),
          (false, true, false, 0.3, BehavioralScoreRange.low),
          (false, true, true, 0.5, BehavioralScoreRange.medium),
          (true, false, false, 0.5, BehavioralScoreRange.medium),
          (true, false, true, 0.7, BehavioralScoreRange.high),
          (true, true, false, 0.8, BehavioralScoreRange.high),
          (true, true, true, 1.0, BehavioralScoreRange.high),
        ];

    for (final caseItem in cases) {
      final score = calibration.scoreFor(
        longSessionDurationActive: caseItem.$1,
        highScreenTimeActive: caseItem.$2,
        frequentUnlockingActive: caseItem.$3,
      );

      expect(score.score, caseItem.$4);
      expect(score.range, caseItem.$5);
    }
  });

  test('a análise de sensibilidade expõe fronteiras e matriz completa', () {
    final calibration = BehavioralSignalCalibration.v1();
    final report = calibration.analyzeSensitivity();

    expect(report.boundaryCases, hasLength(9));
    expect(report.combinationCases, hasLength(8));

    expect(
      report.boundaryCases
          .where((row) => row.label.startsWith('long_session_duration_minutes'))
          .map((row) => row.range),
      containsAllInOrder([
        BehavioralScoreRange.low,
        BehavioralScoreRange.medium,
        BehavioralScoreRange.medium,
      ]),
    );

    expect(
      report.boundaryCases
          .where(
            (row) => row.label.startsWith('high_screen_time_hours_per_day'),
          )
          .map((row) => row.range),
      containsAllInOrder([
        BehavioralScoreRange.low,
        BehavioralScoreRange.low,
        BehavioralScoreRange.low,
      ]),
    );

    expect(
      report.combinationCases.any(
        (row) => row.range == BehavioralScoreRange.high,
      ),
      isTrue,
    );
  });

  test('configuração inválida é rejeitada de forma explícita', () {
    final invalidCalibration = BehavioralSignalCalibration(
      version: '2026-06-21-v1',
      deviceProfile: 'Test device',
      calibrationNotes: 'Invalid configuration for regression coverage.',
      behavioralThresholds: const [
        ThresholdDefinition(
          id: 'session_merge_gap_seconds',
          kind: ThresholdKind.behavioral,
          value: 5,
          unit: 'seconds',
          justification: 'Should not appear as a behavioral threshold.',
          version: '2026-06-21-v1',
        ),
      ],
      technicalParameters: const [
        ThresholdDefinition(
          id: 'session_merge_gap_seconds',
          kind: ThresholdKind.technical,
          value: 5,
          unit: 'seconds',
          justification: 'Technical parameter for session continuity.',
          version: '2026-06-21-v1',
        ),
      ],
      signalWeights: const {
        BehavioralSignalKind.longSessionDuration: 0.5,
        BehavioralSignalKind.highScreenTime: 0.3,
        BehavioralSignalKind.frequentUnlocking: 0.2,
      },
      contextualStrengthCap: 2.0,
    );

    expect(invalidCalibration.validate, throwsFormatException);
  });
}
