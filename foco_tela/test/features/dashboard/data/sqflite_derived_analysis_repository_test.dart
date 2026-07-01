import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:foco_tela/features/catalog/domain/app_catalog.dart';
import 'package:foco_tela/features/dashboard/data/sqflite_derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/app_daily_aggregate.dart';
import 'package:foco_tela/features/dashboard/domain/behavioral_signal_calibration.dart';
import 'package:foco_tela/features/dashboard/domain/derived_analysis_batch.dart';
import 'package:foco_tela/features/dashboard/domain/derived_analysis_repository.dart';
import 'package:foco_tela/features/dashboard/domain/episode_analysis.dart';
import 'package:foco_tela/features/dashboard/domain/smartphone_usage_episode.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDirectory;
  late String databasePath;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('foco_tela_v1_10_');
    databasePath = '${tempDirectory.path}/derived.db';
  });

  tearDown(() async {
    await databaseFactoryFfi.deleteDatabase(databasePath);
    await tempDirectory.delete(recursive: true);
  });

  test('persiste o lote completo e o recupera depois de reabrir', () async {
    final original = _classifiedBatch(
      day: DateTime(2026, 6, 21),
      generatedAt: DateTime(2026, 6, 21, 14, 30),
      provisional: true,
    );
    final writer = _repository(databasePath);
    await writer.initialize(now: DateTime(2026, 6, 21, 14, 30));
    await writer.save(original);
    await writer.close();

    final reader = _repository(databasePath);
    await reader.initialize(now: DateTime(2026, 6, 21, 14, 31));
    final recovered = await reader.loadDay(
      DateTime(2026, 6, 21),
      compatibleWith: _versions,
    );

    expect(recovered, isNotNull);
    expect(recovered!.dayStart, original.dayStart);
    expect(recovered.generatedAt, original.generatedAt);
    expect(recovered.totalUsage, const Duration(hours: 4));
    expect(recovered.unlockCount, 40);
    expect(recovered.episodes.single.packageName, 'com.example.social');
    final analysis =
        recovered.episodeAnalyses.single as ClassifiedEpisodeAnalysis;
    expect(analysis.state, AnalysisState.convergentIntensifiedRetentionSignals);
    expect(analysis.behavioralScore.value, 1.0);
    expect(analysis.signalObservations, hasLength(3));
    expect(analysis.context.contributions.single.iri, 'InfiniteScrollFeed');
    expect(
      analysis.context.contributions.single.evidence.single.id,
      'evidence-a',
    );
    expect(analysis.patternExplanation?.summary, 'Resumo auditável.');
    await reader.close();
  });

  test('substitui lote provisório compatível sem duplicar episódios', () async {
    final repository = _repository(databasePath);
    await repository.initialize(now: DateTime(2026, 6, 21, 12));
    await repository.save(
      _classifiedBatch(
        day: DateTime(2026, 6, 21),
        generatedAt: DateTime(2026, 6, 21, 12),
        provisional: true,
      ),
    );
    await repository.save(
      _classifiedBatch(
        day: DateTime(2026, 6, 21),
        generatedAt: DateTime(2026, 6, 21, 16),
        provisional: true,
        episodeMinutes: 30,
      ),
    );

    final recovered = await repository.loadDay(DateTime(2026, 6, 21));

    expect(recovered!.generatedAt, DateTime(2026, 6, 21, 16));
    expect(recovered.episodes, hasLength(1));
    expect(recovered.episodes.single.duration, const Duration(minutes: 30));
    await repository.close();
  });

  test('falha transacional mantém o lote anterior observável', () async {
    final initial = _repository(databasePath);
    await initial.initialize(now: DateTime(2026, 6, 21, 12));
    await initial.save(
      _classifiedBatch(
        day: DateTime(2026, 6, 21),
        generatedAt: DateTime(2026, 6, 21, 12),
        provisional: true,
      ),
    );
    await initial.close();

    final failing = _repository(
      databasePath,
      transactionProbe: (_) => throw StateError('falha injetada'),
    );
    await failing.initialize(now: DateTime(2026, 6, 21, 16));

    await expectLater(
      failing.save(
        _classifiedBatch(
          day: DateTime(2026, 6, 21),
          generatedAt: DateTime(2026, 6, 21, 16),
          provisional: true,
          episodeMinutes: 30,
        ),
      ),
      throwsA(isA<DerivedAnalysisPersistenceException>()),
    );
    final recovered = await failing.loadDay(DateTime(2026, 6, 21));

    expect(recovered!.generatedAt, DateTime(2026, 6, 21, 12));
    expect(recovered.episodes.single.duration, const Duration(minutes: 20));
    await failing.close();
  });

  test('dias são gravados e recuperados independentemente', () async {
    final repository = _repository(databasePath);
    await repository.initialize(now: DateTime(2026, 6, 21));
    await repository.save(
      _classifiedBatch(
        day: DateTime(2026, 6, 20),
        generatedAt: DateTime(2026, 6, 21),
        provisional: false,
      ),
    );
    await repository.save(
      _classifiedBatch(
        day: DateTime(2026, 6, 21),
        generatedAt: DateTime(2026, 6, 21, 12),
        provisional: true,
      ),
    );

    expect(await repository.loadDay(DateTime(2026, 6, 20)), isNotNull);
    expect(await repository.loadDay(DateTime(2026, 6, 21)), isNotNull);
    expect(await repository.loadDay(DateTime(2026, 6, 19)), isNull);
    await repository.close();
  });

  test('não recupera derivado com versões incompatíveis', () async {
    final repository = _repository(databasePath);
    await repository.initialize(now: DateTime(2026, 6, 21));
    await repository.save(
      _classifiedBatch(
        day: DateTime(2026, 6, 20),
        generatedAt: DateTime(2026, 6, 21),
        provisional: false,
      ),
    );
    const incompatible = AnalysisArtifactVersions(
      calibrationVersion: 'calibration-v2',
      catalogVersion: 'catalog-v1',
      owxIri: 'urn:test:owl',
      owxVersion: 'owl-v1',
      owxCommit: 'abc123',
      owxHash: 'def456',
    );

    expect(
      await repository.loadDay(
        DateTime(2026, 6, 20),
        compatibleWith: incompatible,
      ),
      isNull,
    );
    await repository.close();
  });

  test(
    'retém detalhes por 30 dias e agregados diários por aplicativo por seis meses',
    () async {
      final repository = _repository(databasePath);
      await repository.initialize(now: DateTime(2026, 1, 1));
      final oldDetailedDay = DateTime(2026, 4, 30);
      final expiredAggregateDay = DateTime(2025, 11, 30);
      await repository.save(
        _classifiedBatch(
          day: oldDetailedDay,
          generatedAt: DateTime(2026, 4, 30),
          provisional: false,
        ),
      );
      await repository.save(
        _classifiedBatch(
          day: expiredAggregateDay,
          generatedAt: DateTime(2025, 12, 20),
          provisional: false,
        ),
      );
      await repository.prune(now: DateTime(2026, 6, 1));

      expect(await repository.loadDay(oldDetailedDay), isNull);
      expect(
        await repository.loadAppDailyAggregates(
          start: DateTime(2026, 4, 1),
          end: DateTime(2026, 6, 1),
        ),
        contains(
          isA<AppDailyAggregate>()
              .having((aggregate) => aggregate.dayStart, 'day', oldDetailedDay)
              .having(
                (aggregate) => aggregate.packageName,
                'packageName',
                'com.example.social',
              )
              .having(
                (aggregate) => aggregate.duration,
                'duration',
                const Duration(minutes: 20),
              )
              .having(
                (aggregate) => aggregate.stateCounts,
                'stateCounts',
                containsPair(
                  AnalysisState.convergentIntensifiedRetentionSignals,
                  1,
                ),
              ),
        ),
      );
      expect(
        await repository.loadAppDailyAggregates(
          start: DateTime(2025, 12, 1),
          end: DateTime(2026, 6, 1),
        ),
        isNot(
          contains(
            isA<AppDailyAggregate>().having(
              (aggregate) => aggregate.dayStart,
              'day',
              expiredAggregateDay,
            ),
          ),
        ),
      );
      await repository.close();
    },
  );

  test('clearAllDerived remove todos os lotes locais', () async {
    final repository = _repository(databasePath);
    await repository.initialize(now: DateTime(2026, 6, 21));
    await repository.save(
      _classifiedBatch(
        day: DateTime(2026, 6, 20),
        generatedAt: DateTime(2026, 6, 21),
        provisional: false,
      ),
    );

    await repository.clearAllDerived();

    expect(await repository.loadDay(DateTime(2026, 6, 20)), isNull);
    await repository.close();
  });

  test('migra banco versão 1 e preserva sua abertura', () async {
    final current = _repository(databasePath);
    await current.initialize(now: DateTime(2026, 6, 21));
    await current.close();
    final legacy = await databaseFactoryFfi.openDatabase(databasePath);
    await legacy.execute('ALTER TABLE derived_days DROP COLUMN issue_message');
    await legacy.execute('PRAGMA user_version = 1');
    await legacy.close();

    final migrated = _repository(databasePath);
    await migrated.initialize(now: DateTime(2026, 6, 21));
    await migrated.close();
    final db = await databaseFactoryFfi.openDatabase(databasePath);
    final columns = await db.rawQuery('PRAGMA table_info(derived_days)');

    expect(columns.map((row) => row['name']), contains('issue_message'));
    expect(
      await db.getVersion(),
      SqfliteDerivedAnalysisRepository.schemaVersion,
    );
    await db.close();
  });

  test(
    'migração para versão 3 cria agregados diários por aplicativo a partir dos detalhes existentes',
    () async {
      final current = _repository(databasePath);
      await current.initialize(now: DateTime(2026, 6, 20));
      await current.save(
        _classifiedBatch(
          day: DateTime(2026, 6, 20),
          generatedAt: DateTime(2026, 6, 20, 12),
          provisional: false,
        ),
      );
      await current.close();
      final legacy = await databaseFactoryFfi.openDatabase(databasePath);
      await legacy.execute('DROP TABLE app_daily_aggregates');
      await legacy.setVersion(2);
      await legacy.close();

      final migrated = _repository(databasePath);
      await migrated.initialize(now: DateTime(2026, 6, 21));
      final aggregates = await migrated.loadAppDailyAggregates(
        start: DateTime(2026, 6, 20),
        end: DateTime(2026, 6, 21),
      );

      expect(aggregates, hasLength(1));
      expect(aggregates.single.packageName, 'com.example.social');
      expect(aggregates.single.duration, const Duration(minutes: 20));
      expect(aggregates.single.episodeCount, 1);
      expect(
        aggregates.single.stateCounts,
        containsPair(AnalysisState.convergentIntensifiedRetentionSignals, 1),
      );
      await migrated.close();
    },
  );

  test(
    'esquema contém apenas derivados e nenhum evento ou identidade',
    () async {
      final repository = _repository(databasePath);
      await repository.initialize(now: DateTime(2026, 6, 21));
      await repository.close();
      final db = await databaseFactoryFfi.openDatabase(databasePath);
      final schemaRows = await db.rawQuery(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table'",
      );
      final schema = schemaRows
          .map((row) => '${row['name']} ${row['sql']}')
          .join(' ')
          .toLowerCase();

      expect(schema, isNot(contains('raw_event')));
      expect(schema, isNot(contains('normalized_event')));
      expect(schema, isNot(contains('notification_content')));
      expect(schema, isNot(contains('user_id')));
      expect(schema, isNot(contains('email')));
      await db.close();
    },
  );
}

SqfliteDerivedAnalysisRepository _repository(
  String databasePath, {
  SqfliteTransactionProbe? transactionProbe,
}) => SqfliteDerivedAnalysisRepository(
  databaseFactory: databaseFactoryFfi,
  databasePath: databasePath,
  transactionProbe: transactionProbe,
);

const _versions = AnalysisArtifactVersions(
  calibrationVersion: 'calibration-v1',
  catalogVersion: 'catalog-v1',
  owxIri: 'urn:test:owl',
  owxVersion: 'owl-v1',
  owxCommit: 'abc123',
  owxHash: 'def456',
);

DerivedAnalysisBatch _classifiedBatch({
  required DateTime day,
  required DateTime generatedAt,
  required bool provisional,
  int episodeMinutes = 20,
}) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final episode = SmartphoneUsageEpisode(
    packageName: 'com.example.social',
    appName: 'Social',
    startedAt: dayStart.add(const Duration(hours: 10)),
    endedAt: dayStart.add(Duration(hours: 10, minutes: episodeMinutes)),
    duration: Duration(minutes: episodeMinutes),
  );
  final threshold = ThresholdDefinition(
    id: 'long_session_duration_minutes',
    kind: ThresholdKind.behavioral,
    value: 15,
    unit: 'minutes',
    justification: 'Fixture.',
    version: _versions.calibrationVersion,
  );
  final signals = [
    BehavioralSignalObservation(
      kind: BehavioralSignalKind.longSessionDuration,
      scope: SignalScope.episode,
      isActive: true,
      weight: 0.5,
      observedValue: '1200 seconds',
      threshold: threshold,
    ),
    BehavioralSignalObservation(
      kind: BehavioralSignalKind.highScreenTime,
      scope: SignalScope.sharedDay,
      isActive: true,
      weight: 0.3,
      observedValue: '14400 seconds/day',
      threshold: ThresholdDefinition(
        id: 'high_screen_time_hours_per_day',
        kind: ThresholdKind.behavioral,
        value: 4,
        unit: 'hours/day',
        justification: 'Fixture.',
        version: _versions.calibrationVersion,
      ),
    ),
    BehavioralSignalObservation(
      kind: BehavioralSignalKind.frequentUnlocking,
      scope: SignalScope.sharedDay,
      isActive: true,
      weight: 0.2,
      observedValue: '40 unlocks/day',
      threshold: ThresholdDefinition(
        id: 'frequent_unlocks_per_day',
        kind: ThresholdKind.behavioral,
        value: 40,
        unit: 'unlocks/day',
        justification: 'Fixture.',
        version: _versions.calibrationVersion,
      ),
    ),
  ];
  final result = ClassifiedEpisodeAnalysis(
    episode: episode,
    coverageStatus: provisional
        ? CoverageStatus.partial
        : CoverageStatus.sufficient,
    isProvisional: provisional,
    signalObservations: signals,
    versions: _versions,
    behavioralScore: BehavioralSignalScore(
      value: 1,
      range: BehavioralScoreRange.high,
      contributions: signals,
    ),
    context: ContextualRetentionStrength(
      isAvailable: true,
      rawValue: 0.5,
      matrixValue: 0.5,
      cap: 2,
      range: ContextualStrengthRange.medium,
      contributions: [
        ContextualRetentionContribution(
          iri: 'InfiniteScrollFeed',
          label: 'Rolagem infinita',
          confidence: CatalogConfidence.medium,
          weight: 0.5,
          evidence: [
            CatalogEvidence(
              id: 'evidence-a',
              type: CatalogEvidenceType.appStoreListing,
              reference: 'https://example.test/evidence-a',
              date: DateTime(2026, 6, 20),
              observedVersion: '2026-06-20',
              supportedStatement: 'Evidência específica.',
              scope: 'app_specific',
            ),
          ],
        ),
      ],
    ),
    state: AnalysisState.convergentIntensifiedRetentionSignals,
    patternExplanation: const PatternExplanation(
      summary: 'Resumo auditável.',
      caveat: 'Leitura exploratória.',
    ),
  );
  return DerivedAnalysisBatch(
    dayStart: dayStart,
    generatedAt: generatedAt,
    analyzedThrough: provisional ? generatedAt : null,
    coverageStatus: provisional
        ? CoverageStatus.partial
        : CoverageStatus.sufficient,
    totalUsage: const Duration(hours: 4),
    unlockCount: 40,
    episodes: [episode],
    episodeAnalyses: [result],
    versions: _versions,
  );
}
