import '../../catalog/domain/app_catalog.dart';
import 'behavioral_signal_calibration.dart';
import 'coverage_status.dart';
import 'score_total.dart';
import 'smartphone_usage_episode.dart';

enum SignalScope { episode, sharedDay }

enum ContextualStrengthRange { absent, low, medium, high }

enum AnalysisState {
  contextUnavailable,
  insufficientSignals,
  signalsForReview,
  convergentIntensifiedRetentionSignals,
}

enum EpisodeAnalysisUnavailableReason { incompleteDailyCoverage }

class BehavioralSignalObservation {
  const BehavioralSignalObservation({
    required this.kind,
    required this.scope,
    required this.isActive,
    required this.weight,
    required this.observedValue,
    required this.threshold,
  });

  final BehavioralSignalKind kind;
  final SignalScope scope;
  final bool? isActive;
  final double weight;
  final String observedValue;
  final ThresholdDefinition threshold;

  double get contribution => isActive == true ? weight : 0.0;
}

class BehavioralSignalScore {
  BehavioralSignalScore({
    required this.value,
    required this.range,
    required List<BehavioralSignalObservation> contributions,
  }) : contributions = List.unmodifiable(contributions);

  final double value;
  final BehavioralScoreRange range;
  final List<BehavioralSignalObservation> contributions;
}

class ContextualRetentionContribution {
  ContextualRetentionContribution({
    required this.iri,
    required this.label,
    required this.confidence,
    required this.weight,
    required List<CatalogEvidence> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final String iri;
  final String label;
  final CatalogConfidence confidence;
  final double weight;
  final List<CatalogEvidence> evidence;
}

class ContextualRetentionStrength {
  ContextualRetentionStrength({
    required this.isAvailable,
    required this.rawValue,
    required this.matrixValue,
    required this.cap,
    required this.range,
    required List<ContextualRetentionContribution> contributions,
  }) : contributions = List.unmodifiable(contributions);

  final bool isAvailable;
  final double rawValue;
  final double matrixValue;
  final double cap;
  final ContextualStrengthRange range;
  final List<ContextualRetentionContribution> contributions;
}

class AnalysisArtifactVersions {
  const AnalysisArtifactVersions({
    required this.calibrationVersion,
    required this.catalogVersion,
    required this.owxIri,
    required this.owxVersion,
    required this.owxCommit,
    required this.owxHash,
  });

  final String calibrationVersion;
  final String catalogVersion;
  final String owxIri;
  final String owxVersion;
  final String owxCommit;
  final String owxHash;
}

class PatternExplanation {
  const PatternExplanation({required this.summary, required this.caveat});

  final String summary;
  final String caveat;
}

sealed class EpisodeAnalysisResult {
  EpisodeAnalysisResult({
    required this.episode,
    required this.coverageStatus,
    required this.isProvisional,
    required List<BehavioralSignalObservation> signalObservations,
    required this.versions,
  }) : signalObservations = List.unmodifiable(signalObservations);

  final SmartphoneUsageEpisode episode;
  final CoverageStatus coverageStatus;
  final bool isProvisional;
  final List<BehavioralSignalObservation> signalObservations;
  final AnalysisArtifactVersions versions;
}

final class UnclassifiedEpisodeAnalysis extends EpisodeAnalysisResult {
  UnclassifiedEpisodeAnalysis({
    required super.episode,
    required super.coverageStatus,
    required super.isProvisional,
    required super.signalObservations,
    required super.versions,
    required this.reason,
  });

  final EpisodeAnalysisUnavailableReason reason;
}

final class ClassifiedEpisodeAnalysis extends EpisodeAnalysisResult {
  ClassifiedEpisodeAnalysis({
    required super.episode,
    required super.coverageStatus,
    required super.isProvisional,
    required super.signalObservations,
    required super.versions,
    required this.behavioralScore,
    required this.context,
    ScoreTotalAssessment? scoreTotal,
    required this.state,
    required this.patternExplanation,
  }) : scoreTotal =
           scoreTotal ??
           ScoreTotalAssessment(
             value: behavioralScore.value,
             band: switch (behavioralScore.range) {
               BehavioralScoreRange.low => ScoreTotalBand.low,
               BehavioralScoreRange.medium => ScoreTotalBand.moderate,
               BehavioralScoreRange.high => ScoreTotalBand.high,
             },
             algorithmVersion: 'legacy-score-sinais-fallback',
             dimensions: const [],
             curatedAssociations: const [],
           );

  final BehavioralSignalScore behavioralScore;
  final ContextualRetentionStrength context;
  final ScoreTotalAssessment scoreTotal;
  final AnalysisState state;
  final PatternExplanation? patternExplanation;
}
