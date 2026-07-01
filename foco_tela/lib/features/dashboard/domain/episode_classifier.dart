import '../../catalog/domain/app_catalog.dart';
import 'behavioral_signal_calibration.dart';
import 'daily_usage_summary.dart';
import 'episode_analysis.dart';
import 'score_total.dart';
import 'smartphone_usage_episode.dart';

class EpisodeClassifier {
  EpisodeClassifier({BehavioralSignalCalibration? calibration})
    : _calibration = calibration ?? BehavioralSignalCalibration.v1();

  final BehavioralSignalCalibration _calibration;

  AnalysisArtifactVersions artifactVersionsFor(CatalogSnapshot catalog) =>
      AnalysisArtifactVersions(
        calibrationVersion: _calibration.version,
        catalogVersion: catalog.header.version,
        owxIri: catalog.header.owxIri,
        owxVersion: catalog.header.owxVersion,
        owxCommit: catalog.header.owxCommit,
        owxHash: catalog.header.owxHash,
      );

  EpisodeAnalysisResult analyze({
    required SmartphoneUsageEpisode episode,
    required DailyUsageSummary day,
    required CatalogSnapshot catalog,
  }) {
    _calibration.validate();
    final versions = artifactVersionsFor(catalog);
    final longSession = _signalObservation(
      kind: BehavioralSignalKind.longSessionDuration,
      scope: SignalScope.episode,
      active: _calibration.isLongSessionDurationActive(episode.duration),
      observedValue: '${episode.duration.inSeconds} seconds',
    );

    final dailyMetricsAreEligible =
        day.coverageStatus == CoverageStatus.sufficient || day.isProvisional;
    final totalUsage = day.totalUsage;
    final dailyAnalysis = day.analysis;
    if (!dailyMetricsAreEligible ||
        totalUsage == null ||
        dailyAnalysis == null) {
      return UnclassifiedEpisodeAnalysis(
        episode: episode,
        coverageStatus: day.coverageStatus,
        isProvisional: day.isProvisional,
        signalObservations: [longSession],
        versions: versions,
        reason: EpisodeAnalysisUnavailableReason.incompleteDailyCoverage,
      );
    }

    final highScreenTime = _signalObservation(
      kind: BehavioralSignalKind.highScreenTime,
      scope: SignalScope.sharedDay,
      active: _calibration.isHighScreenTimeActive(totalUsage),
      observedValue: '${totalUsage.inSeconds} seconds/day',
    );
    final frequentUnlocking = _signalObservation(
      kind: BehavioralSignalKind.frequentUnlocking,
      scope: SignalScope.sharedDay,
      active: _calibration.isFrequentUnlockingActive(dailyAnalysis.unlockCount),
      observedValue: '${dailyAnalysis.unlockCount} unlocks/day',
    );
    final observations = [longSession, highScreenTime, frequentUnlocking];
    final score = _calibration.scoreFor(
      longSessionDurationActive: longSession.isActive!,
      highScreenTimeActive: highScreenTime.isActive!,
      frequentUnlockingActive: frequentUnlocking.isActive!,
    );
    final behavioralScore = BehavioralSignalScore(
      value: score.score,
      range: score.range,
      contributions: observations,
    );
    final app = catalog.appForPackageName(episode.packageName);
    final context = _contextFor(app);
    final scoreTotal = const ScoreTotalCalculator().calculate(
      behavioralScore: behavioralScore,
      technicalContext: context,
      catalogApp: app,
      versions: versions,
    );
    final state = _stateFor(
      behavioralScore: behavioralScore,
      scoreTotal: scoreTotal,
      context: context,
    );

    return ClassifiedEpisodeAnalysis(
      episode: episode,
      coverageStatus: day.coverageStatus,
      isProvisional: day.isProvisional,
      signalObservations: observations,
      versions: versions,
      behavioralScore: behavioralScore,
      context: context,
      scoreTotal: scoreTotal,
      state: state,
      patternExplanation: switch (state) {
        AnalysisState.signalsForReview ||
        AnalysisState.convergentIntensifiedRetentionSignals =>
          const PatternExplanation(
            summary:
                'Os sinais observados e o contexto catalogado foram avaliados '
                'em dimensões separadas por uma matriz versionada.',
            caveat:
                'Esta leitura é exploratória, não diagnóstica e não demonstra '
                'que o aplicativo causou os sinais compartilhados do dia.',
          ),
        AnalysisState.contextUnavailable ||
        AnalysisState.insufficientSignals => null,
      },
    );
  }

  BehavioralSignalObservation _signalObservation({
    required BehavioralSignalKind kind,
    required SignalScope scope,
    required bool active,
    required String observedValue,
  }) {
    final thresholdId = switch (kind) {
      BehavioralSignalKind.longSessionDuration =>
        'long_session_duration_minutes',
      BehavioralSignalKind.highScreenTime => 'high_screen_time_hours_per_day',
      BehavioralSignalKind.frequentUnlocking => 'frequent_unlocks_per_day',
    };
    final threshold = _calibration.behavioralThresholds.firstWhere(
      (candidate) => candidate.id == thresholdId,
    );
    return BehavioralSignalObservation(
      kind: kind,
      scope: scope,
      isActive: active,
      weight: _calibration.weightFor(kind),
      observedValue: observedValue,
      threshold: threshold,
    );
  }

  ContextualRetentionStrength _contextFor(CatalogApp? app) {
    if (app == null || !app.hasApprovedContext) {
      return ContextualRetentionStrength(
        isAvailable: false,
        rawValue: 0,
        matrixValue: 0,
        cap: _calibration.contextualStrengthCap,
        range: ContextualStrengthRange.absent,
        contributions: const [],
      );
    }

    final byIri = <String, List<CatalogAssociation>>{};
    for (final association in app.associations) {
      if (association.contextualRole != CatalogContextualRole.retention ||
          !association.hasTraceableEvidence) {
        continue;
      }
      byIri.putIfAbsent(association.iri, () => []).add(association);
    }
    final contributions = byIri.entries
        .map((entry) {
          final strongest = entry.value.reduce(
            (current, candidate) =>
                candidate.confidence.weight > current.confidence.weight
                ? candidate
                : current,
          );
          final evidenceById = <String, CatalogEvidence>{
            for (final association in entry.value)
              for (final evidence in association.evidence)
                evidence.id: evidence,
          };
          return ContextualRetentionContribution(
            iri: entry.key,
            label: strongest.label,
            confidence: strongest.confidence,
            weight: strongest.confidence.weight,
            evidence: evidenceById.values.toList(growable: false),
          );
        })
        .toList(growable: false);
    final rawValue = contributions.fold<double>(
      0,
      (total, contribution) => total + contribution.weight,
    );
    final matrixValue = rawValue > _calibration.contextualStrengthCap
        ? _calibration.contextualStrengthCap
        : rawValue;
    return ContextualRetentionStrength(
      isAvailable: true,
      rawValue: rawValue,
      matrixValue: matrixValue,
      cap: _calibration.contextualStrengthCap,
      range: switch (matrixValue) {
        0 => ContextualStrengthRange.absent,
        >= 0.1 && < 0.5 => ContextualStrengthRange.low,
        >= 0.5 && < 1.0 => ContextualStrengthRange.medium,
        _ => ContextualStrengthRange.high,
      },
      contributions: contributions,
    );
  }

  AnalysisState _stateFor({
    required BehavioralSignalScore behavioralScore,
    required ScoreTotalAssessment scoreTotal,
    required ContextualRetentionStrength context,
  }) {
    if (!context.isAvailable) {
      return AnalysisState.contextUnavailable;
    }
    final strongLegacyConvergence =
        behavioralScore.range == BehavioralScoreRange.high &&
        (context.range == ContextualStrengthRange.medium ||
            context.range == ContextualStrengthRange.high);
    if (strongLegacyConvergence) {
      return AnalysisState.convergentIntensifiedRetentionSignals;
    }
    return switch (scoreTotal.band) {
      ScoreTotalBand.low =>
        behavioralScore.range == BehavioralScoreRange.low
            ? AnalysisState.insufficientSignals
            : AnalysisState.signalsForReview,
      ScoreTotalBand.moderate => AnalysisState.signalsForReview,
      ScoreTotalBand.high =>
        scoreTotal.hasCuratedTechniqueOrIntention
            ? AnalysisState.convergentIntensifiedRetentionSignals
            : AnalysisState.signalsForReview,
    };
  }
}
