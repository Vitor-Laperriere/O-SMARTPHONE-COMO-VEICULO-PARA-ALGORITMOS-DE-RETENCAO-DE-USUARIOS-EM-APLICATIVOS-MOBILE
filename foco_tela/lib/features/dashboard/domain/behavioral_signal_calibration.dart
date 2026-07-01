enum ThresholdKind { behavioral, technical }

enum BehavioralSignalKind {
  longSessionDuration,
  highScreenTime,
  frequentUnlocking,
}

enum BehavioralScoreRange { low, medium, high }

class ThresholdDefinition {
  const ThresholdDefinition({
    required this.id,
    required this.kind,
    required this.value,
    required this.unit,
    required this.justification,
    required this.version,
  });

  final String id;
  final ThresholdKind kind;
  final num value;
  final String unit;
  final String justification;
  final String version;
}

class BehavioralSignalCalibration {
  BehavioralSignalCalibration({
    required this.version,
    required this.deviceProfile,
    required this.calibrationNotes,
    required List<ThresholdDefinition> behavioralThresholds,
    required List<ThresholdDefinition> technicalParameters,
    required Map<BehavioralSignalKind, double> signalWeights,
    required this.contextualStrengthCap,
  }) : behavioralThresholds = List.unmodifiable(behavioralThresholds),
       technicalParameters = List.unmodifiable(technicalParameters),
       signalWeights = Map.unmodifiable(signalWeights);

  final String version;
  final String deviceProfile;
  final String calibrationNotes;
  final List<ThresholdDefinition> behavioralThresholds;
  final List<ThresholdDefinition> technicalParameters;
  final Map<BehavioralSignalKind, double> signalWeights;
  final double contextualStrengthCap;

  List<ThresholdDefinition> get allThresholds => [
    ...behavioralThresholds,
    ...technicalParameters,
  ];

  static BehavioralSignalCalibration v1() {
    const version = '2026-06-21-v1';
    return BehavioralSignalCalibration(
      version: version,
      deviceProfile: 'Samsung SM-A526B (Android 14/API 34)',
      calibrationNotes:
          'Configuração exploratória aprovada a partir de observação técnica local, '
          'fixtures sintéticas e análise de sensibilidade. Não incorpora dados '
          'pessoais e não tem valor diagnóstico.',
      behavioralThresholds: const [
        ThresholdDefinition(
          id: 'long_session_duration_minutes',
          kind: ThresholdKind.behavioral,
          value: 15,
          unit: 'minutes',
          justification:
              'Corte inicial para duração longa de sessão, suficiente para '
              'evitar interações curtas e ainda sensível para o protótipo.',
          version: version,
        ),
        ThresholdDefinition(
          id: 'high_screen_time_hours_per_day',
          kind: ThresholdKind.behavioral,
          value: 4,
          unit: 'hours/day',
          justification:
              'Corte inicial no limite inferior do intervalo de 4–8 horas/dia '
              'descrito na revisão, tratado aqui como configuração exploratória.',
          version: version,
        ),
        ThresholdDefinition(
          id: 'frequent_unlocks_per_day',
          kind: ThresholdKind.behavioral,
          value: 40,
          unit: 'unlocks/day',
          justification:
              'Corte operacional conservador para checagem frequente, definido '
              'como ponto de partida calibrável e não como valor universal.',
          version: version,
        ),
      ],
      technicalParameters: const [
        ThresholdDefinition(
          id: 'session_merge_gap_seconds',
          kind: ThresholdKind.technical,
          value: 5,
          unit: 'seconds',
          justification:
              'Janela técnica de continuidade entre transições do mesmo app; '
              'não é limiar comportamental.',
          version: version,
        ),
      ],
      signalWeights: const {
        BehavioralSignalKind.longSessionDuration: 0.5,
        BehavioralSignalKind.highScreenTime: 0.3,
        BehavioralSignalKind.frequentUnlocking: 0.2,
      },
      contextualStrengthCap: 2.0,
    );
  }

  void validate() {
    final thresholdIds = <String>{};
    for (final threshold in allThresholds) {
      _validateThreshold(threshold);
      if (!thresholdIds.add(threshold.id)) {
        throw FormatException('Threshold duplicado: ${threshold.id}.');
      }
    }

    final behavioralIds = behavioralThresholds
        .map((threshold) => threshold.id)
        .toSet();
    if (!behavioralIds.contains('long_session_duration_minutes') ||
        !behavioralIds.contains('high_screen_time_hours_per_day') ||
        !behavioralIds.contains('frequent_unlocks_per_day')) {
      throw FormatException('Configuração comportamental V1 incompleta.');
    }

    if (!technicalParameters.any(
      (threshold) => threshold.id == 'session_merge_gap_seconds',
    )) {
      throw FormatException(
        'Parâmetro técnico session_merge_gap_seconds ausente.',
      );
    }
    if (!BehavioralSignalKind.values.every(signalWeights.containsKey)) {
      throw const FormatException('Pesos dos sinais da V1 incompletos.');
    }
    if (signalWeights.values.any((weight) => weight < 0 || weight > 1)) {
      throw const FormatException('Peso de sinal fora do intervalo de 0 a 1.');
    }
    if (contextualStrengthCap <= 0) {
      throw const FormatException('Teto contextual deve ser positivo.');
    }
  }

  void _validateThreshold(ThresholdDefinition threshold) {
    if (threshold.id.isEmpty) {
      throw const FormatException('Threshold sem identificador.');
    }
    if (threshold.unit.isEmpty) {
      throw FormatException('Threshold ${threshold.id} sem unidade.');
    }
    if (threshold.justification.isEmpty) {
      throw FormatException('Threshold ${threshold.id} sem justificativa.');
    }
    if (threshold.version.isEmpty) {
      throw FormatException('Threshold ${threshold.id} sem versão.');
    }
    if (threshold.value < 0) {
      throw FormatException('Threshold ${threshold.id} com valor negativo.');
    }
    if (threshold.version != version) {
      throw FormatException(
        'Threshold ${threshold.id} fora da versão $version.',
      );
    }
    if (threshold.kind == ThresholdKind.behavioral &&
        threshold.id == 'session_merge_gap_seconds') {
      throw FormatException(
        'session_merge_gap_seconds deve permanecer como parâmetro técnico.',
      );
    }
  }

  bool isLongSessionDurationActive(Duration duration) {
    final threshold = _thresholdById('long_session_duration_minutes');
    return duration.inSeconds >= threshold.value * 60;
  }

  bool isHighScreenTimeActive(Duration totalUsage) {
    final threshold = _thresholdById('high_screen_time_hours_per_day');
    return totalUsage.inSeconds >= threshold.value * 3600;
  }

  bool isFrequentUnlockingActive(int unlockCount) {
    final threshold = _thresholdById('frequent_unlocks_per_day');
    return unlockCount >= threshold.value;
  }

  double weightFor(BehavioralSignalKind kind) => signalWeights[kind]!;

  BehavioralScore scoreFor({
    required bool longSessionDurationActive,
    required bool highScreenTimeActive,
    required bool frequentUnlockingActive,
  }) {
    final score =
        (longSessionDurationActive
            ? weightFor(BehavioralSignalKind.longSessionDuration)
            : 0.0) +
        (highScreenTimeActive
            ? weightFor(BehavioralSignalKind.highScreenTime)
            : 0.0) +
        (frequentUnlockingActive
            ? weightFor(BehavioralSignalKind.frequentUnlocking)
            : 0.0);

    return BehavioralScore(score: score);
  }

  CalibrationSensitivityReport analyzeSensitivity() {
    final boundaryCases = [
      _durationBoundaryCases(
        threshold: _thresholdById('long_session_duration_minutes'),
        below: const Duration(minutes: 14),
        at: const Duration(minutes: 15),
        above: const Duration(minutes: 16),
        evaluator: isLongSessionDurationActive,
        label: 'LongSessionDuration',
      ),
      _durationBoundaryCases(
        threshold: _thresholdById('high_screen_time_hours_per_day'),
        below: const Duration(hours: 3, minutes: 59),
        at: const Duration(hours: 4),
        above: const Duration(hours: 4, minutes: 1),
        evaluator: isHighScreenTimeActive,
        label: 'HighScreenTime',
      ),
      _countBoundaryCases(
        threshold: _thresholdById('frequent_unlocks_per_day'),
        below: 39,
        at: 40,
        above: 41,
        evaluator: isFrequentUnlockingActive,
        label: 'FrequentUnlocking',
      ),
    ].expand((cases) => cases).toList(growable: false);

    final combinationCases = <CalibrationSensitivityCase>[];
    for (final combination in const [
      (
        longSessionDurationActive: false,
        highScreenTimeActive: false,
        frequentUnlockingActive: false,
      ),
      (
        longSessionDurationActive: false,
        highScreenTimeActive: false,
        frequentUnlockingActive: true,
      ),
      (
        longSessionDurationActive: false,
        highScreenTimeActive: true,
        frequentUnlockingActive: false,
      ),
      (
        longSessionDurationActive: false,
        highScreenTimeActive: true,
        frequentUnlockingActive: true,
      ),
      (
        longSessionDurationActive: true,
        highScreenTimeActive: false,
        frequentUnlockingActive: false,
      ),
      (
        longSessionDurationActive: true,
        highScreenTimeActive: false,
        frequentUnlockingActive: true,
      ),
      (
        longSessionDurationActive: true,
        highScreenTimeActive: true,
        frequentUnlockingActive: false,
      ),
      (
        longSessionDurationActive: true,
        highScreenTimeActive: true,
        frequentUnlockingActive: true,
      ),
    ]) {
      final score = scoreFor(
        longSessionDurationActive: combination.longSessionDurationActive,
        highScreenTimeActive: combination.highScreenTimeActive,
        frequentUnlockingActive: combination.frequentUnlockingActive,
      );
      combinationCases.add(
        CalibrationSensitivityCase(
          label:
              '${combination.longSessionDurationActive ? 'L' : '-'}'
              '${combination.highScreenTimeActive ? 'S' : '-'}'
              '${combination.frequentUnlockingActive ? 'U' : '-'}',
          longSessionDurationActive: combination.longSessionDurationActive,
          highScreenTimeActive: combination.highScreenTimeActive,
          frequentUnlockingActive: combination.frequentUnlockingActive,
          score: score.score,
          range: score.range,
        ),
      );
    }

    return CalibrationSensitivityReport(
      boundaryCases: boundaryCases,
      combinationCases: combinationCases,
    );
  }

  ThresholdDefinition _thresholdById(String id) =>
      allThresholds.firstWhere((threshold) => threshold.id == id);

  List<CalibrationSensitivityCase> _durationBoundaryCases({
    required ThresholdDefinition threshold,
    required Duration below,
    required Duration at,
    required Duration above,
    required bool Function(Duration value) evaluator,
    required String label,
  }) {
    final values = <({String variant, Duration value})>[
      (variant: 'below', value: below),
      (variant: 'at', value: at),
      (variant: 'above', value: above),
    ];

    return values
        .map(
          (candidate) => CalibrationSensitivityCase(
            label: '${threshold.id}:${candidate.variant}',
            longSessionDurationActive: label == 'LongSessionDuration'
                ? evaluator(candidate.value)
                : false,
            highScreenTimeActive: label == 'HighScreenTime'
                ? evaluator(candidate.value)
                : false,
            frequentUnlockingActive: false,
            score: scoreFor(
              longSessionDurationActive: label == 'LongSessionDuration'
                  ? evaluator(candidate.value)
                  : false,
              highScreenTimeActive: label == 'HighScreenTime'
                  ? evaluator(candidate.value)
                  : false,
              frequentUnlockingActive: false,
            ).score,
            range: scoreFor(
              longSessionDurationActive: label == 'LongSessionDuration'
                  ? evaluator(candidate.value)
                  : false,
              highScreenTimeActive: label == 'HighScreenTime'
                  ? evaluator(candidate.value)
                  : false,
              frequentUnlockingActive: false,
            ).range,
          ),
        )
        .toList(growable: false);
  }

  List<CalibrationSensitivityCase> _countBoundaryCases({
    required ThresholdDefinition threshold,
    required int below,
    required int at,
    required int above,
    required bool Function(int value) evaluator,
    required String label,
  }) {
    final values = <({String variant, int value})>[
      (variant: 'below', value: below),
      (variant: 'at', value: at),
      (variant: 'above', value: above),
    ];

    return values
        .map(
          (candidate) => CalibrationSensitivityCase(
            label: '${threshold.id}:${candidate.variant}',
            longSessionDurationActive: false,
            highScreenTimeActive: false,
            frequentUnlockingActive: label == 'FrequentUnlocking'
                ? evaluator(candidate.value)
                : false,
            score: scoreFor(
              longSessionDurationActive: false,
              highScreenTimeActive: false,
              frequentUnlockingActive: label == 'FrequentUnlocking'
                  ? evaluator(candidate.value)
                  : false,
            ).score,
            range: scoreFor(
              longSessionDurationActive: false,
              highScreenTimeActive: false,
              frequentUnlockingActive: label == 'FrequentUnlocking'
                  ? evaluator(candidate.value)
                  : false,
            ).range,
          ),
        )
        .toList(growable: false);
  }
}

class BehavioralScore {
  const BehavioralScore({required this.score});

  final double score;

  BehavioralScoreRange get range => switch (score) {
    >= 0.7 && <= 1.0 => BehavioralScoreRange.high,
    >= 0.5 && < 0.7 => BehavioralScoreRange.medium,
    _ => BehavioralScoreRange.low,
  };
}

class CalibrationSensitivityCase {
  const CalibrationSensitivityCase({
    required this.label,
    required this.longSessionDurationActive,
    required this.highScreenTimeActive,
    required this.frequentUnlockingActive,
    required this.score,
    required this.range,
  });

  final String label;
  final bool longSessionDurationActive;
  final bool highScreenTimeActive;
  final bool frequentUnlockingActive;
  final double score;
  final BehavioralScoreRange range;
}

class CalibrationSensitivityReport {
  const CalibrationSensitivityReport({
    required this.boundaryCases,
    required this.combinationCases,
  });

  final List<CalibrationSensitivityCase> boundaryCases;
  final List<CalibrationSensitivityCase> combinationCases;
}
