import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../catalog/domain/app_catalog.dart';
import '../domain/app_daily_aggregate.dart';
import '../domain/behavioral_signal_calibration.dart';
import '../domain/derived_analysis_batch.dart';
import '../domain/derived_analysis_repository.dart';
import '../domain/episode_analysis.dart';
import '../domain/smartphone_usage_episode.dart';

typedef SqfliteTransactionProbe =
    FutureOr<void> Function(DerivedAnalysisBatch batch);

class SqfliteDerivedAnalysisRepository implements DerivedAnalysisRepository {
  SqfliteDerivedAnalysisRepository({
    DatabaseFactory? databaseFactory,
    String? databasePath,
    SqfliteTransactionProbe? transactionProbe,
  }) : _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin,
       _databasePath = databasePath,
       _transactionProbe = transactionProbe;

  static const schemaVersion = 3;

  final DatabaseFactory _databaseFactory;
  final String? _databasePath;
  final SqfliteTransactionProbe? _transactionProbe;
  Database? _database;

  @override
  Future<void> initialize({required DateTime now}) async {
    await _db;
    await prune(now: now);
  }

  Future<Database> get _db async {
    final current = _database;
    if (current != null && current.isOpen) return current;
    final path =
        _databasePath ??
        '${await _databaseFactory.getDatabasesPath()}/foco_tela_derived.db';
    final opened = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _createVersionOne(db);
          if (version >= 2) await _migrateVersionOneToTwo(db);
          if (version >= 3) await _migrateVersionTwoToThree(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2 && newVersion >= 2) {
            await _migrateVersionOneToTwo(db);
          }
          if (oldVersion < 3 && newVersion >= 3) {
            await _migrateVersionTwoToThree(db);
          }
        },
      ),
    );
    _database = opened;
    return opened;
  }

  @override
  Future<void> save(DerivedAnalysisBatch batch) async {
    final db = await _db;
    try {
      await db.transaction((transaction) async {
        final dayKey = _dayKey(batch.dayStart);
        await transaction.delete(
          'derived_days',
          where: 'day_start = ?',
          whereArgs: [dayKey],
        );
        await transaction.insert('derived_days', {
          'day_start': dayKey,
          'generated_at': batch.generatedAt.toIso8601String(),
          'analyzed_through': batch.analyzedThrough?.toIso8601String(),
          'coverage_status': batch.coverageStatus.name,
          'total_usage_ms': batch.totalUsage?.inMilliseconds,
          'unlock_count': batch.unlockCount,
          'calibration_version': batch.versions.calibrationVersion,
          'catalog_version': batch.versions.catalogVersion,
          'owx_iri': batch.versions.owxIri,
          'owx_version': batch.versions.owxVersion,
          'owx_commit': batch.versions.owxCommit,
          'owx_hash': batch.versions.owxHash,
          'issue_message': batch.issueMessage,
        });

        for (var index = 0; index < batch.episodeAnalyses.length; index++) {
          await _insertEpisodeAnalysis(
            transaction,
            dayKey: dayKey,
            ordinal: index,
            result: batch.episodeAnalyses[index],
          );
        }
        await _replaceAppDailyAggregates(transaction, batch);
        await _transactionProbe?.call(batch);
      });
      await prune(now: batch.generatedAt);
    } catch (error) {
      throw DerivedAnalysisPersistenceException(
        'Não foi possível gravar o lote derivado de ${_dayKey(batch.dayStart)}.',
        error,
      );
    }
  }

  @override
  Future<DerivedAnalysisBatch?> loadDay(
    DateTime day, {
    AnalysisArtifactVersions? compatibleWith,
  }) async {
    final db = await _db;
    final dayRows = await db.query(
      'derived_days',
      where: 'day_start = ?',
      whereArgs: [_dayKey(day)],
      limit: 1,
    );
    if (dayRows.isEmpty) return null;

    final row = dayRows.single;
    final versions = _versionsFromRow(row);
    if (compatibleWith != null && !_versionsMatch(versions, compatibleWith)) {
      return null;
    }

    final episodeRows = await db.query(
      'derived_episodes',
      where: 'day_start = ?',
      whereArgs: [_dayKey(day)],
      orderBy: 'ordinal ASC',
    );
    final episodes = <SmartphoneUsageEpisode>[];
    final analyses = <EpisodeAnalysisResult>[];
    for (final episodeRow in episodeRows) {
      final episode = _episodeFromRow(episodeRow);
      episodes.add(episode);
      analyses.add(
        await _analysisFromRow(
          db,
          episodeRow: episodeRow,
          episode: episode,
          versions: versions,
        ),
      );
    }

    return DerivedAnalysisBatch(
      dayStart: DateTime.parse(row['day_start']! as String),
      generatedAt: DateTime.parse(row['generated_at']! as String),
      analyzedThrough: switch (row['analyzed_through']) {
        String value => DateTime.parse(value),
        _ => null,
      },
      coverageStatus: CoverageStatus.values.byName(
        row['coverage_status']! as String,
      ),
      totalUsage: switch (row['total_usage_ms']) {
        int value => Duration(milliseconds: value),
        _ => null,
      },
      unlockCount: row['unlock_count'] as int?,
      episodes: episodes,
      episodeAnalyses: analyses,
      versions: versions,
      issueMessage: row['issue_message'] as String?,
    );
  }

  @override
  Future<List<AppDailyAggregate>> loadAppDailyAggregates({
    required DateTime start,
    required DateTime end,
    AnalysisArtifactVersions? compatibleWith,
  }) async {
    final db = await _db;
    final where = StringBuffer('day_start >= ? AND day_start < ?');
    final whereArgs = <Object?>[_dayKey(start), _dayKey(end)];
    if (compatibleWith != null) {
      where.write(
        ' AND calibration_version = ? AND catalog_version = ? AND owx_iri = ?'
        ' AND owx_version = ? AND owx_commit = ? AND owx_hash = ?',
      );
      whereArgs.addAll([
        compatibleWith.calibrationVersion,
        compatibleWith.catalogVersion,
        compatibleWith.owxIri,
        compatibleWith.owxVersion,
        compatibleWith.owxCommit,
        compatibleWith.owxHash,
      ]);
    }
    final rows = await db.query(
      'app_daily_aggregates',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'day_start ASC, package_name ASC',
    );

    return rows.map(_aggregateFromRow).toList(growable: false);
  }

  @override
  Future<void> prune({required DateTime now}) async {
    final today = DateTime(now.year, now.month, now.day);
    final oldestDetailedDay = DateTime(today.year, today.month, today.day - 29);
    final oldestAggregateDay = DateTime(today.year, today.month - 6, today.day);
    final db = await _db;
    await db.delete(
      'derived_days',
      where: 'day_start < ?',
      whereArgs: [_dayKey(oldestDetailedDay)],
    );
    await db.delete(
      'app_daily_aggregates',
      where: 'day_start < ?',
      whereArgs: [_dayKey(oldestAggregateDay)],
    );
  }

  @override
  Future<void> clearAllDerived() async {
    final db = await _db;
    await db.delete('derived_days');
    await db.delete('app_daily_aggregates');
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) await db.close();
  }

  Future<void> _insertEpisodeAnalysis(
    Transaction transaction, {
    required String dayKey,
    required int ordinal,
    required EpisodeAnalysisResult result,
  }) async {
    final episodeId = _episodeId(dayKey, ordinal);
    final classified = switch (result) {
      ClassifiedEpisodeAnalysis value => value,
      UnclassifiedEpisodeAnalysis() => null,
    };
    final unclassified = switch (result) {
      UnclassifiedEpisodeAnalysis value => value,
      ClassifiedEpisodeAnalysis() => null,
    };
    await transaction.insert('derived_episodes', {
      'episode_id': episodeId,
      'day_start': dayKey,
      'ordinal': ordinal,
      'package_name': result.episode.packageName,
      'app_name': result.episode.appName,
      'started_at': result.episode.startedAt.toIso8601String(),
      'ended_at': result.episode.endedAt.toIso8601String(),
      'duration_ms': result.episode.duration.inMilliseconds,
      'analysis_kind': classified == null ? 'unclassified' : 'classified',
      'unavailable_reason': unclassified?.reason.name,
      'score_value': classified?.behavioralScore.value,
      'score_range': classified?.behavioralScore.range.name,
      'context_available': classified?.context.isAvailable == true ? 1 : 0,
      'context_raw_value': classified?.context.rawValue,
      'context_matrix_value': classified?.context.matrixValue,
      'context_cap': classified?.context.cap,
      'context_range': classified?.context.range.name,
      'analysis_state': classified?.state.name,
      'explanation_summary': classified?.patternExplanation?.summary,
      'explanation_caveat': classified?.patternExplanation?.caveat,
    });

    for (var index = 0; index < result.signalObservations.length; index++) {
      final signal = result.signalObservations[index];
      await transaction.insert('signal_contributions', {
        'episode_id': episodeId,
        'ordinal': index,
        'signal_kind': signal.kind.name,
        'scope': signal.scope.name,
        'is_active': switch (signal.isActive) {
          true => 1,
          false => 0,
          null => null,
        },
        'weight': signal.weight,
        'observed_value': signal.observedValue,
        'threshold_id': signal.threshold.id,
        'threshold_kind': signal.threshold.kind.name,
        'threshold_value': signal.threshold.value,
        'threshold_unit': signal.threshold.unit,
        'threshold_justification': signal.threshold.justification,
        'threshold_version': signal.threshold.version,
      });
    }

    final contextContributions = classified?.context.contributions ?? const [];
    for (var index = 0; index < contextContributions.length; index++) {
      final contribution = contextContributions[index];
      await transaction.insert('context_contributions', {
        'episode_id': episodeId,
        'ordinal': index,
        'iri': contribution.iri,
        'label': contribution.label,
        'confidence': contribution.confidence.name,
        'weight': contribution.weight,
      });
      for (
        var evidenceIndex = 0;
        evidenceIndex < contribution.evidence.length;
        evidenceIndex++
      ) {
        final evidence = contribution.evidence[evidenceIndex];
        await transaction.insert('context_evidence', {
          'episode_id': episodeId,
          'contribution_ordinal': index,
          'ordinal': evidenceIndex,
          'evidence_id': evidence.id,
          'evidence_type': evidence.type.name,
          'reference': evidence.reference,
          'evidence_date': evidence.date.toIso8601String(),
          'observed_version': evidence.observedVersion,
          'supported_statement': evidence.supportedStatement,
          'scope': evidence.scope,
        });
      }
    }
  }

  Future<void> _replaceAppDailyAggregates(
    Transaction transaction,
    DerivedAnalysisBatch batch,
  ) async {
    final dayKey = _dayKey(batch.dayStart);
    await transaction.delete(
      'app_daily_aggregates',
      where: 'day_start = ?',
      whereArgs: [dayKey],
    );
    if (!batch.coverageStatus.isAvailable) return;

    final byPackage = <String, List<EpisodeAnalysisResult>>{};
    for (final analysis in batch.episodeAnalyses) {
      byPackage
          .putIfAbsent(analysis.episode.packageName, () => [])
          .add(analysis);
    }

    for (final entry in byPackage.entries) {
      final analyses = entry.value;
      final firstEpisode = analyses.first.episode;
      final counts = {for (final state in AnalysisState.values) state: 0};
      var duration = Duration.zero;
      for (final analysis in analyses) {
        duration += analysis.episode.duration;
        if (analysis case ClassifiedEpisodeAnalysis(:final state)) {
          counts[state] = counts[state]! + 1;
        }
      }
      await transaction.insert('app_daily_aggregates', {
        'day_start': dayKey,
        'package_name': firstEpisode.packageName,
        'app_name': firstEpisode.appName,
        'duration_ms': duration.inMilliseconds,
        'episode_count': analyses.length,
        'context_unavailable_count': counts[AnalysisState.contextUnavailable],
        'insufficient_signals_count': counts[AnalysisState.insufficientSignals],
        'signals_for_review_count': counts[AnalysisState.signalsForReview],
        'convergent_count':
            counts[AnalysisState.convergentIntensifiedRetentionSignals],
        'coverage_status': batch.coverageStatus.name,
        'generated_at': batch.generatedAt.toIso8601String(),
        'calibration_version': batch.versions.calibrationVersion,
        'catalog_version': batch.versions.catalogVersion,
        'owx_iri': batch.versions.owxIri,
        'owx_version': batch.versions.owxVersion,
        'owx_commit': batch.versions.owxCommit,
        'owx_hash': batch.versions.owxHash,
      });
    }
  }

  Future<EpisodeAnalysisResult> _analysisFromRow(
    Database db, {
    required Map<String, Object?> episodeRow,
    required SmartphoneUsageEpisode episode,
    required AnalysisArtifactVersions versions,
  }) async {
    final episodeId = episodeRow['episode_id']! as String;
    final signals = await _loadSignals(db, episodeId);
    final coverage = CoverageStatus.values.byName(
      (await db.query(
            'derived_days',
            columns: ['coverage_status', 'analyzed_through'],
            where: 'day_start = ?',
            whereArgs: [episodeRow['day_start']],
            limit: 1,
          )).single['coverage_status']!
          as String,
    );
    final dayRow = (await db.query(
      'derived_days',
      columns: ['analyzed_through'],
      where: 'day_start = ?',
      whereArgs: [episodeRow['day_start']],
      limit: 1,
    )).single;
    final provisional = dayRow['analyzed_through'] != null;

    return switch (episodeRow['analysis_kind']) {
      'unclassified' => UnclassifiedEpisodeAnalysis(
        episode: episode,
        coverageStatus: coverage,
        isProvisional: provisional,
        signalObservations: signals,
        versions: versions,
        reason: EpisodeAnalysisUnavailableReason.values.byName(
          episodeRow['unavailable_reason']! as String,
        ),
      ),
      'classified' => _classifiedFromRow(
        db,
        episodeRow: episodeRow,
        episode: episode,
        coverage: coverage,
        provisional: provisional,
        signals: signals,
        versions: versions,
      ),
      _ => throw const FormatException('Tipo de análise persistida inválido.'),
    };
  }

  Future<ClassifiedEpisodeAnalysis> _classifiedFromRow(
    Database db, {
    required Map<String, Object?> episodeRow,
    required SmartphoneUsageEpisode episode,
    required CoverageStatus coverage,
    required bool provisional,
    required List<BehavioralSignalObservation> signals,
    required AnalysisArtifactVersions versions,
  }) async {
    final context = await _loadContext(db, episodeRow);
    return ClassifiedEpisodeAnalysis(
      episode: episode,
      coverageStatus: coverage,
      isProvisional: provisional,
      signalObservations: signals,
      versions: versions,
      behavioralScore: BehavioralSignalScore(
        value: (episodeRow['score_value']! as num).toDouble(),
        range: BehavioralScoreRange.values.byName(
          episodeRow['score_range']! as String,
        ),
        contributions: signals,
      ),
      context: context,
      state: AnalysisState.values.byName(
        episodeRow['analysis_state']! as String,
      ),
      patternExplanation: switch ((
        episodeRow['explanation_summary'],
        episodeRow['explanation_caveat'],
      )) {
        (String summary, String caveat) => PatternExplanation(
          summary: summary,
          caveat: caveat,
        ),
        _ => null,
      },
    );
  }

  Future<List<BehavioralSignalObservation>> _loadSignals(
    Database db,
    String episodeId,
  ) async {
    final rows = await db.query(
      'signal_contributions',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      orderBy: 'ordinal ASC',
    );
    return rows
        .map(
          (row) => BehavioralSignalObservation(
            kind: BehavioralSignalKind.values.byName(
              row['signal_kind']! as String,
            ),
            scope: SignalScope.values.byName(row['scope']! as String),
            isActive: switch (row['is_active']) {
              1 => true,
              0 => false,
              _ => null,
            },
            weight: (row['weight']! as num).toDouble(),
            observedValue: row['observed_value']! as String,
            threshold: ThresholdDefinition(
              id: row['threshold_id']! as String,
              kind: ThresholdKind.values.byName(
                row['threshold_kind']! as String,
              ),
              value: row['threshold_value']! as num,
              unit: row['threshold_unit']! as String,
              justification: row['threshold_justification']! as String,
              version: row['threshold_version']! as String,
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<ContextualRetentionStrength> _loadContext(
    Database db,
    Map<String, Object?> episodeRow,
  ) async {
    final episodeId = episodeRow['episode_id']! as String;
    final contributionRows = await db.query(
      'context_contributions',
      where: 'episode_id = ?',
      whereArgs: [episodeId],
      orderBy: 'ordinal ASC',
    );
    final contributions = <ContextualRetentionContribution>[];
    for (final row in contributionRows) {
      final evidenceRows = await db.query(
        'context_evidence',
        where: 'episode_id = ? AND contribution_ordinal = ?',
        whereArgs: [episodeId, row['ordinal']],
        orderBy: 'ordinal ASC',
      );
      contributions.add(
        ContextualRetentionContribution(
          iri: row['iri']! as String,
          label: row['label']! as String,
          confidence: CatalogConfidence.values.byName(
            row['confidence']! as String,
          ),
          weight: (row['weight']! as num).toDouble(),
          evidence: evidenceRows
              .map(
                (evidence) => CatalogEvidence(
                  id: evidence['evidence_id']! as String,
                  type: CatalogEvidenceType.values.byName(
                    evidence['evidence_type']! as String,
                  ),
                  reference: evidence['reference']! as String,
                  date: DateTime.parse(evidence['evidence_date']! as String),
                  observedVersion: evidence['observed_version']! as String,
                  supportedStatement:
                      evidence['supported_statement']! as String,
                  scope: evidence['scope']! as String,
                ),
              )
              .toList(growable: false),
        ),
      );
    }
    return ContextualRetentionStrength(
      isAvailable: episodeRow['context_available'] == 1,
      rawValue: (episodeRow['context_raw_value']! as num).toDouble(),
      matrixValue: (episodeRow['context_matrix_value']! as num).toDouble(),
      cap: (episodeRow['context_cap']! as num).toDouble(),
      range: ContextualStrengthRange.values.byName(
        episodeRow['context_range']! as String,
      ),
      contributions: contributions,
    );
  }

  SmartphoneUsageEpisode _episodeFromRow(Map<String, Object?> row) =>
      SmartphoneUsageEpisode(
        packageName: row['package_name']! as String,
        appName: row['app_name']! as String,
        startedAt: DateTime.parse(row['started_at']! as String),
        endedAt: DateTime.parse(row['ended_at']! as String),
        duration: Duration(milliseconds: row['duration_ms']! as int),
      );

  AnalysisArtifactVersions _versionsFromRow(Map<String, Object?> row) =>
      AnalysisArtifactVersions(
        calibrationVersion: row['calibration_version']! as String,
        catalogVersion: row['catalog_version']! as String,
        owxIri: row['owx_iri']! as String,
        owxVersion: row['owx_version']! as String,
        owxCommit: row['owx_commit']! as String,
        owxHash: row['owx_hash']! as String,
      );

  AppDailyAggregate _aggregateFromRow(Map<String, Object?> row) =>
      AppDailyAggregate(
        dayStart: DateTime.parse(row['day_start']! as String),
        packageName: row['package_name']! as String,
        appName: row['app_name']! as String,
        duration: Duration(milliseconds: row['duration_ms']! as int),
        episodeCount: row['episode_count']! as int,
        stateCounts: Map.unmodifiable({
          AnalysisState.contextUnavailable:
              row['context_unavailable_count']! as int,
          AnalysisState.insufficientSignals:
              row['insufficient_signals_count']! as int,
          AnalysisState.signalsForReview:
              row['signals_for_review_count']! as int,
          AnalysisState.convergentIntensifiedRetentionSignals:
              row['convergent_count']! as int,
        }),
        coverageStatus: CoverageStatus.values.byName(
          row['coverage_status']! as String,
        ),
        generatedAt: DateTime.parse(row['generated_at']! as String),
        versions: _versionsFromRow(row),
      );

  bool _versionsMatch(
    AnalysisArtifactVersions left,
    AnalysisArtifactVersions right,
  ) =>
      left.calibrationVersion == right.calibrationVersion &&
      left.catalogVersion == right.catalogVersion &&
      left.owxIri == right.owxIri &&
      left.owxVersion == right.owxVersion &&
      left.owxCommit == right.owxCommit &&
      left.owxHash == right.owxHash;

  static Future<void> _createVersionOne(Database db) async {
    await db.execute('''
CREATE TABLE derived_days (
  day_start TEXT PRIMARY KEY,
  generated_at TEXT NOT NULL,
  analyzed_through TEXT,
  coverage_status TEXT NOT NULL,
  total_usage_ms INTEGER,
  unlock_count INTEGER,
  calibration_version TEXT NOT NULL,
  catalog_version TEXT NOT NULL,
  owx_iri TEXT NOT NULL,
  owx_version TEXT NOT NULL,
  owx_commit TEXT NOT NULL,
  owx_hash TEXT NOT NULL
)
''');
    await db.execute('''
CREATE TABLE derived_episodes (
  episode_id TEXT PRIMARY KEY,
  day_start TEXT NOT NULL REFERENCES derived_days(day_start) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL,
  package_name TEXT NOT NULL,
  app_name TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  analysis_kind TEXT NOT NULL,
  unavailable_reason TEXT,
  score_value REAL,
  score_range TEXT,
  context_available INTEGER NOT NULL,
  context_raw_value REAL,
  context_matrix_value REAL,
  context_cap REAL,
  context_range TEXT,
  analysis_state TEXT,
  explanation_summary TEXT,
  explanation_caveat TEXT,
  UNIQUE(day_start, ordinal)
)
''');
    await db.execute('''
CREATE TABLE signal_contributions (
  episode_id TEXT NOT NULL REFERENCES derived_episodes(episode_id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL,
  signal_kind TEXT NOT NULL,
  scope TEXT NOT NULL,
  is_active INTEGER,
  weight REAL NOT NULL,
  observed_value TEXT NOT NULL,
  threshold_id TEXT NOT NULL,
  threshold_kind TEXT NOT NULL,
  threshold_value REAL NOT NULL,
  threshold_unit TEXT NOT NULL,
  threshold_justification TEXT NOT NULL,
  threshold_version TEXT NOT NULL,
  PRIMARY KEY(episode_id, ordinal)
)
''');
    await db.execute('''
CREATE TABLE context_contributions (
  episode_id TEXT NOT NULL REFERENCES derived_episodes(episode_id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL,
  iri TEXT NOT NULL,
  label TEXT NOT NULL,
  confidence TEXT NOT NULL,
  weight REAL NOT NULL,
  PRIMARY KEY(episode_id, ordinal)
)
''');
    await db.execute('''
CREATE TABLE context_evidence (
  episode_id TEXT NOT NULL,
  contribution_ordinal INTEGER NOT NULL,
  ordinal INTEGER NOT NULL,
  evidence_id TEXT NOT NULL,
  evidence_type TEXT NOT NULL,
  reference TEXT NOT NULL,
  evidence_date TEXT NOT NULL,
  observed_version TEXT NOT NULL,
  supported_statement TEXT NOT NULL,
  scope TEXT NOT NULL,
  PRIMARY KEY(episode_id, contribution_ordinal, ordinal),
  FOREIGN KEY(episode_id, contribution_ordinal)
    REFERENCES context_contributions(episode_id, ordinal) ON DELETE CASCADE
)
''');
  }

  static Future<void> _migrateVersionOneToTwo(Database db) =>
      db.execute('ALTER TABLE derived_days ADD COLUMN issue_message TEXT');

  static Future<void> _migrateVersionTwoToThree(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS app_daily_aggregates (
  day_start TEXT NOT NULL,
  package_name TEXT NOT NULL,
  app_name TEXT NOT NULL,
  duration_ms INTEGER NOT NULL,
  episode_count INTEGER NOT NULL,
  context_unavailable_count INTEGER NOT NULL,
  insufficient_signals_count INTEGER NOT NULL,
  signals_for_review_count INTEGER NOT NULL,
  convergent_count INTEGER NOT NULL,
  coverage_status TEXT NOT NULL,
  generated_at TEXT NOT NULL,
  calibration_version TEXT NOT NULL,
  catalog_version TEXT NOT NULL,
  owx_iri TEXT NOT NULL,
  owx_version TEXT NOT NULL,
  owx_commit TEXT NOT NULL,
  owx_hash TEXT NOT NULL,
  PRIMARY KEY(day_start, package_name)
)
''');
    await db.execute('''
INSERT OR REPLACE INTO app_daily_aggregates (
  day_start,
  package_name,
  app_name,
  duration_ms,
  episode_count,
  context_unavailable_count,
  insufficient_signals_count,
  signals_for_review_count,
  convergent_count,
  coverage_status,
  generated_at,
  calibration_version,
  catalog_version,
  owx_iri,
  owx_version,
  owx_commit,
  owx_hash
)
SELECT
  d.day_start,
  e.package_name,
  e.app_name,
  SUM(e.duration_ms) AS duration_ms,
  COUNT(*) AS episode_count,
  SUM(CASE WHEN e.analysis_state = 'contextUnavailable' THEN 1 ELSE 0 END),
  SUM(CASE WHEN e.analysis_state = 'insufficientSignals' THEN 1 ELSE 0 END),
  SUM(CASE WHEN e.analysis_state = 'signalsForReview' THEN 1 ELSE 0 END),
  SUM(
    CASE
      WHEN e.analysis_state = 'convergentIntensifiedRetentionSignals'
      THEN 1
      ELSE 0
    END
  ),
  d.coverage_status,
  d.generated_at,
  d.calibration_version,
  d.catalog_version,
  d.owx_iri,
  d.owx_version,
  d.owx_commit,
  d.owx_hash
FROM derived_episodes e
JOIN derived_days d ON d.day_start = e.day_start
WHERE d.coverage_status != 'unavailable'
GROUP BY d.day_start, e.package_name
''');
  }

  String _dayKey(DateTime day) =>
      DateTime(day.year, day.month, day.day).toIso8601String();

  String _episodeId(String dayKey, int ordinal) => '$dayKey#$ordinal';
}
